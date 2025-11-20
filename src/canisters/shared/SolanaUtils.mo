import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Base58 "mo:bitcoin/Base58";

module {
  /// Ed25519 Canister Actor interface for threshold Ed25519 signing
  public type Ed25519CanisterActor = actor {
    ed25519_public_key : ({
      canister_id : ?Principal;
      derivation_path : [Blob];
      key_id : Ed25519KeyId;
    }) -> async {
      public_key : Blob;
      chain_code : Blob;
    };

    sign_with_ed25519 : ({
      message_hash : Blob;
      derivation_path : [Blob];
      key_id : Ed25519KeyId;
    }) -> async {
      signature : Blob;
    };
  };

  public type Ed25519KeyId = {
    curve : { #Ed25519 };
    name : Text;
  };

  /// Default Ed25519 key name for threshold signing
  private let DEFAULT_ED25519_KEY_NAME : Text = "dfx_test_key";

  /// Get Ed25519 management canister actor (aaaaa-aa)
  private func getEd25519Canister() : Ed25519CanisterActor {
    actor "aaaaa-aa" : Ed25519CanisterActor
  };

  /// Get Ed25519 public key from ICP system API
  /// Uses the Ed25519 management canister (aaaaa-aa)
  public func getEd25519PublicKey(
    derivationPath : [Blob],
    keyName : ?Text
  ) : async Result.Result<Blob, Text> {
    let ed25519Canister = getEd25519Canister();
    let key = Option.get<Text>(keyName, DEFAULT_ED25519_KEY_NAME);

    try {
      let response = await ed25519Canister.ed25519_public_key({
        canister_id = null;
        derivation_path = derivationPath;
        key_id = { curve = #Ed25519; name = key };
      });
      #ok(response.public_key)
    } catch (_e) {
      #err("Failed to get Ed25519 public key")
    }
  };

  /// Sign a message hash using threshold Ed25519
  /// This is used for signing Solana transactions
  public func signWithEd25519(
    messageHash : Blob,
    derivationPath : [Blob],
    keyName : ?Text
  ) : async Result.Result<Blob, Text> {
    let ed25519Canister = getEd25519Canister();
    let key = Option.get<Text>(keyName, DEFAULT_ED25519_KEY_NAME);

    try {
      let response = await ed25519Canister.sign_with_ed25519({
        message_hash = messageHash;
        derivation_path = derivationPath;
        key_id = { curve = #Ed25519; name = key };
      });
      #ok(response.signature)
    } catch (_e) {
      #err("Failed to sign with Ed25519")
    }
  };

  /// Derive a Solana address from an Ed25519 public key
  /// Solana addresses are base58-encoded Ed25519 public keys (32 bytes)
  /// Note: Solana uses plain base58 (no checksum), unlike Bitcoin's Base58Check
  public func deriveSolanaAddress(publicKey : Blob) : Text {
    let keyBytes = Blob.toArray(publicKey);
    // Solana addresses are just base58-encoded public keys (no checksum)
    Base58.encode(keyBytes)
  };

  /// Convert Solana address (base58) to public key bytes
  /// Returns the 32-byte Ed25519 public key
  public func addressToPublicKey(address : Text) : Result.Result<Blob, Text> {
    let decoded = Base58.decode(address);
    // Solana addresses should decode to exactly 32 bytes (Ed25519 public key)
    if (decoded.size() != 32) {
      return #err("Invalid Solana address: expected 32 bytes, got " # Nat.toText(decoded.size()))
    };
    #ok(Blob.fromArray(decoded))
  };

  /// Solana System Program ID
  private let SYSTEM_PROGRAM_ID : Text = "11111111111111111111111111111111";

  /// Build a simple Solana transfer transaction
  /// This creates the transaction structure that needs to be signed
  public type SolanaTransaction = {
    recentBlockhash : Text; // base58 encoded blockhash
    feePayer : Text; // base58 encoded address
    instructions : [SolanaInstruction];
  };

  public type SolanaInstruction = {
    programId : Text; // base58 encoded program ID
    accounts : [Text]; // base58 encoded account addresses
    data : [Nat8];
  };

  /// Create a System Program transfer instruction
  /// Instruction format: [instruction_id: u32, lamports: u64]
  /// instruction_id = 2 for Transfer
  public func createTransferInstruction(
    from : Text,
    to : Text,
    amountLamports : Nat64
  ) : SolanaInstruction {
    // System Program Transfer instruction (instruction_id = 2, then 8-byte lamports)
    var instructionData = Buffer.Buffer<Nat8>(12);
    // Instruction discriminator: 2 (Transfer)
    instructionData.add(2);
    instructionData.add(0);
    instructionData.add(0);
    instructionData.add(0);
    // Amount (little-endian u64)
    var amount = amountLamports;
    var i : Nat = 0;
    while (i < 8) {
      instructionData.add(Nat8.fromIntWrap(Nat64.toNat(amount % 256)));
      amount := amount / 256;
      i := i + 1;
    };

    {
      programId = SYSTEM_PROGRAM_ID;
      accounts = [from, to];
      data = Buffer.toArray(instructionData);
    }
  };

  /// Serialize a Solana transaction message
  /// Returns the serialized message that needs to be signed
  public func serializeTransactionMessage(
    tx : SolanaTransaction
  ) : Result.Result<[Nat8], Text> {
    // Decode addresses to bytes
    let feePayerBytes = switch (addressToPublicKey(tx.feePayer)) {
      case (#ok(bytes)) Blob.toArray(bytes);
      case (#err(e)) return #err("Invalid fee payer address: " # e);
    };

    // Collect all unique account addresses
    var accounts = Buffer.Buffer<[Nat8]>(10);
    accounts.add(feePayerBytes);
    
    var accountIndices = Buffer.Buffer<[Nat8]>(10);
    var instructionData = Buffer.Buffer<[Nat8]>(10);

    // Process each instruction
    for (instruction in tx.instructions.vals()) {
      // Decode program ID
      let programIdBytes = switch (addressToPublicKey(instruction.programId)) {
        case (#ok(bytes)) Blob.toArray(bytes);
        case (#err(e)) return #err("Invalid program ID: " # e);
      };

      // Find or add program ID to accounts
      var programIndex : Nat = 0;
      var found : Bool = false;
      var idx : Nat = 0;
      label searchLoop for (acc in accounts.vals()) {
        if (Array.equal<Nat8>(acc, programIdBytes, func(a, b) { a == b })) {
          programIndex := idx;
          found := true;
          break searchLoop;
        };
        idx := idx + 1;
      };
      if (not found) {
        programIndex := accounts.size();
        accounts.add(programIdBytes);
      };

      // Decode and add instruction accounts
      var instAccountIndices = Buffer.Buffer<Nat8>(10);
      for (accAddr in instruction.accounts.vals()) {
        let accBytes = switch (addressToPublicKey(accAddr)) {
          case (#ok(bytes)) Blob.toArray(bytes);
          case (#err(e)) return #err("Invalid account address: " # e);
        };
        
        var accIndex : Nat = 0;
        var accFound : Bool = false;
        var accIdx : Nat = 0;
        label accSearchLoop for (acc in accounts.vals()) {
          if (Array.equal<Nat8>(acc, accBytes, func(a, b) { a == b })) {
            accIndex := accIdx;
            accFound := true;
            break accSearchLoop;
          };
          accIdx := accIdx + 1;
        };
        if (not accFound) {
          accIndex := accounts.size();
          accounts.add(accBytes);
        };
        instAccountIndices.add(Nat8.fromIntWrap(accIndex));
      };

      accountIndices.add(Buffer.toArray(instAccountIndices));
      instructionData.add(instruction.data);
    };

    // Decode blockhash (for future use in message building)
    switch (addressToPublicKey(tx.recentBlockhash)) {
      case (#ok(_bytes)) {}; // Would use in message building
      case (#err(e)) return #err("Invalid blockhash: " # e);
    };

    // Build message
    // Note: This is a simplified version. Full implementation needs:
    // - Proper account key ordering (writable/signed, writable/unsigned, readonly/signed, readonly/unsigned)
    // - Compact-u16 encoding for arrays
    // - Proper instruction serialization
    
    // For now, return an error indicating that full serialization is needed
    // Full wire format serialization is complex and should use a dedicated Solana library
    #err("Full transaction serialization not yet implemented - use jsonRequest or a Solana library for transaction building")
  };
};

