import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import HashMap "mo:base/HashMap";
import Base58 "mo:bitcoin/Base58";
import Sha256 "mo:sha2/Sha256";
import JSON "mo:json";

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
  
  /// Solana Memo Program ID
  /// Used for adding text memos to transactions (e.g., user Principal ID)
  private let MEMO_PROGRAM_ID : Text = "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr";

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

  /// Create a Memo Program instruction
  /// Memo program allows adding text data to transactions
  /// Used to identify which user made a deposit
  public func createMemoInstruction(
    memoText : Text
  ) : SolanaInstruction {
    // Memo program instruction: just the memo text as UTF-8 bytes
    let memoBytes = Text.encodeUtf8(memoText);
    let memoArray = Blob.toArray(memoBytes);

    {
      programId = MEMO_PROGRAM_ID;
      accounts = []; // Memo program doesn't require accounts
      data = memoArray;
    }
  };

  /// Create a transfer instruction with memo
  /// This is a convenience function that creates both transfer and memo instructions
  public func createTransferWithMemo(
    from : Text,
    to : Text,
    amountLamports : Nat64,
    memoText : Text
  ) : [SolanaInstruction] {
    [
      createTransferInstruction(from, to, amountLamports),
      createMemoInstruction(memoText)
    ]
  };

  /// Compact-u16 encoding for Solana wire format
  /// Encodes a u16 value using compact encoding (1-3 bytes)
  private func encodeCompactU16(value : Nat) : [Nat8] {
    if (value < 128) {
      // Single byte: 0xxxxxxx
      [Nat8.fromIntWrap(value)]
    } else if (value < 16384) {
      // Two bytes: 1xxxxxxx xxxxxxxx
      let byte1 = Nat8.fromIntWrap(128 + (value % 128));
      let byte2 = Nat8.fromIntWrap(value / 128);
      [byte1, byte2]
    } else {
      // Three bytes: 11xxxxxx xxxxxxxx xxxxxxxx
      let byte1 = Nat8.fromIntWrap(192 + (value % 64));
      let byte2 = Nat8.fromIntWrap((value / 64) % 256);
      let byte3 = Nat8.fromIntWrap(value / 16384);
      [byte1, byte2, byte3]
    }
  };

  /// Account metadata for proper ordering
  private type AccountMeta = {
    pubkey : [Nat8];
    isSigner : Bool;
    isWritable : Bool;
  };

  /// Order accounts according to Solana wire format:
  /// 1. Writable + Signed
  /// 2. Writable + Unsigned
  /// 3. Readonly + Signed
  /// 4. Readonly + Unsigned
  private func orderAccounts(accounts : [AccountMeta]) : [AccountMeta] {
    var writableSigned = Buffer.Buffer<AccountMeta>(10);
    var writableUnsigned = Buffer.Buffer<AccountMeta>(10);
    var readonlySigned = Buffer.Buffer<AccountMeta>(10);
    var readonlyUnsigned = Buffer.Buffer<AccountMeta>(10);
    
    for (acc in accounts.vals()) {
      if (acc.isWritable and acc.isSigner) {
        writableSigned.add(acc);
      } else if (acc.isWritable) {
        writableUnsigned.add(acc);
      } else if (acc.isSigner) {
        readonlySigned.add(acc);
      } else {
        readonlyUnsigned.add(acc);
      };
    };
    
    let result = Buffer.Buffer<AccountMeta>(accounts.size());
    for (acc in writableSigned.vals()) { result.add(acc) };
    for (acc in writableUnsigned.vals()) { result.add(acc) };
    for (acc in readonlySigned.vals()) { result.add(acc) };
    for (acc in readonlyUnsigned.vals()) { result.add(acc) };
    
    Buffer.toArray(result)
  };

  /// Serialize a Solana transaction message to wire format
  /// Returns the serialized message that needs to be signed
  /// Wire format: [header] [account addresses] [recent blockhash] [instructions]
  public func serializeTransactionMessage(
    tx : SolanaTransaction
  ) : Result.Result<[Nat8], Text> {
    // Decode blockhash
    let blockhashBytes = switch (addressToPublicKey(tx.recentBlockhash)) {
      case (#ok(bytes)) Blob.toArray(bytes);
      case (#err(e)) return #err("Invalid blockhash: " # e);
    };
    
    if (blockhashBytes.size() != 32) {
      return #err("Blockhash must be 32 bytes")
    };

    // Decode fee payer
    let feePayerBytes = switch (addressToPublicKey(tx.feePayer)) {
      case (#ok(bytes)) Blob.toArray(bytes);
      case (#err(e)) return #err("Invalid fee payer address: " # e);
    };
    
    if (feePayerBytes.size() != 32) {
      return #err("Fee payer address must be 32 bytes")
    };

    // Collect all unique account addresses and build account metadata
    var accountMap = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    var accountsList = Buffer.Buffer<AccountMeta>(10);
    // Map from pubkey bytes to address (Text) for rebuilding accountMap after reordering
    var pubkeyToAddress = HashMap.HashMap<[Nat8], Text>(0, func(a, b) {
      if (a.size() != b.size()) return false;
      var idx = 0;
      while (idx < a.size()) {
        if (a[idx] != b[idx]) return false;
        idx += 1;
      };
      true
    }, func(key) {
      // Simple hash function for byte arrays (returns Nat32 for HashMap)
      var hash : Nat = 0;
      for (byte in key.vals()) {
        hash := hash * 31 + Nat8.toNat(byte);
      };
      // Convert to Nat32 (HashMap requires Nat32 hash)
      // Use modulo to fit in Nat32 range
      Nat32.fromNat(hash % 2147483647)
    });
    var accountIndex : Nat = 0;
    
    // Fee payer is always first, writable and signed
    accountMap.put(tx.feePayer, accountIndex);
    pubkeyToAddress.put(feePayerBytes, tx.feePayer);
    accountsList.add({
      pubkey = feePayerBytes;
      isSigner = true;
      isWritable = true;
    });
    accountIndex += 1;

    // Process instructions to collect all accounts
    for (instruction in tx.instructions.vals()) {
      // Add program ID if not already present
      switch (accountMap.get(instruction.programId)) {
        case null {
          let programIdBytes = switch (addressToPublicKey(instruction.programId)) {
            case (#ok(bytes)) Blob.toArray(bytes);
            case (#err(e)) return #err("Invalid program ID: " # e);
          };
          if (programIdBytes.size() != 32) {
            return #err("Program ID must be 32 bytes")
          };
          accountMap.put(instruction.programId, accountIndex);
          pubkeyToAddress.put(programIdBytes, instruction.programId);
          accountsList.add({
            pubkey = programIdBytes;
            isSigner = false;
            isWritable = false;
          });
          accountIndex += 1;
        };
        case (?_) {}; // Already exists
      };
      
      // Add instruction accounts
      for (accAddr in instruction.accounts.vals()) {
        switch (accountMap.get(accAddr)) {
          case null {
            let accBytes = switch (addressToPublicKey(accAddr)) {
              case (#ok(bytes)) Blob.toArray(bytes);
              case (#err(e)) return #err("Invalid account address: " # e);
            };
            if (accBytes.size() != 32) {
              return #err("Account address must be 32 bytes")
            };
            accountMap.put(accAddr, accountIndex);
            pubkeyToAddress.put(accBytes, accAddr);
            // For System Program transfers: from is writable/signed, to is writable/unsigned
            // This is a simplified assumption - full implementation would check instruction type
            // Check if this account is the fee payer (signer)
            var isSigner = false;
            if (accBytes.size() == feePayerBytes.size()) {
              var matches = true;
              var idx = 0;
              while (idx < accBytes.size() and matches) {
                if (accBytes[idx] != feePayerBytes[idx]) {
                  matches := false;
                };
                idx += 1;
              };
              isSigner := matches;
            };
            accountsList.add({
              pubkey = accBytes;
              isSigner = isSigner;
              isWritable = true; // Assume writable for transfer instructions
            });
            accountIndex += 1;
          };
          case (?_) {}; // Already exists
        };
      };
    };

    // Order accounts according to Solana wire format
    let orderedAccounts = orderAccounts(Buffer.toArray(accountsList));
    
    // Rebuild accountMap with new indices after reordering
    // The old indices are invalid because accounts were reordered
    accountMap := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    var newIndex : Nat = 0;
    for (acc in orderedAccounts.vals()) {
      switch (pubkeyToAddress.get(acc.pubkey)) {
        case (?address) {
          accountMap.put(address, newIndex);
        };
        case null {
          // This shouldn't happen, but handle gracefully
          return #err("Account pubkey not found in address map")
        };
      };
      newIndex += 1;
    };
    
    // Count account categories for header
    var numRequiredSignatures : Nat8 = 0;
    var numReadonlySignedAccounts : Nat8 = 0;
    var numReadonlyUnsignedAccounts : Nat8 = 0;
    
    for (acc in orderedAccounts.vals()) {
      if (acc.isSigner) {
        numRequiredSignatures += 1;
        if (not acc.isWritable) {
          numReadonlySignedAccounts += 1;
        };
      } else if (not acc.isWritable) {
        numReadonlyUnsignedAccounts += 1;
      };
    };

    // Build message buffer
    var message = Buffer.Buffer<Nat8>(500);
    
    // Message header
    message.add(numRequiredSignatures);
    message.add(numReadonlySignedAccounts);
    message.add(numReadonlyUnsignedAccounts);
    
    // Account addresses (compact-u16 length, then addresses)
    let numAccounts = orderedAccounts.size();
    let numAccountsEncoded = encodeCompactU16(numAccounts);
    for (byte in numAccountsEncoded.vals()) {
      message.add(byte);
    };
    for (acc in orderedAccounts.vals()) {
      for (byte in acc.pubkey.vals()) {
        message.add(byte);
      };
    };
    
    // Recent blockhash (32 bytes)
    for (byte in blockhashBytes.vals()) {
      message.add(byte);
    };
    
    // Instructions (compact-u16 length, then instruction array)
    let numInstructions = tx.instructions.size();
    let numInstructionsEncoded = encodeCompactU16(numInstructions);
    for (byte in numInstructionsEncoded.vals()) {
      message.add(byte);
    };
    
    // Serialize each instruction
    for (instruction in tx.instructions.vals()) {
      // Program ID index (u8)
      let programIdIndex = switch (accountMap.get(instruction.programId)) {
        case (?idx) Nat8.fromIntWrap(idx);
        case null return #err("Program ID not found in account map");
      };
      message.add(programIdIndex);
      
      // Account indices (compact-u16 length, then u8 array)
      let numAccountIndices = instruction.accounts.size();
      let numAccountIndicesEncoded = encodeCompactU16(numAccountIndices);
      for (byte in numAccountIndicesEncoded.vals()) {
        message.add(byte);
      };
      for (accAddr in instruction.accounts.vals()) {
        let accIndex = switch (accountMap.get(accAddr)) {
          case (?idx) Nat8.fromIntWrap(idx);
          case null return #err("Account not found in account map");
        };
        message.add(accIndex);
      };
      
      // Instruction data (compact-u16 length, then bytes)
      let dataLength = instruction.data.size();
      let dataLengthEncoded = encodeCompactU16(dataLength);
      for (byte in dataLengthEncoded.vals()) {
        message.add(byte);
      };
      for (byte in instruction.data.vals()) {
        message.add(byte);
      };
    };
    
    #ok(Buffer.toArray(message))
  };

  /// Compute SHA-256 hash of message for signing
  /// Solana uses SHA-256 to hash the message before signing
  public func hashMessage(message : [Nat8]) : [Nat8] {
    let hashBlob = Sha256.fromArray(#sha256, message);
    Blob.toArray(hashBlob)
  };

  /// Serialize a signed Solana transaction to wire format
  /// Wire format: [signatures] [message]
  public func serializeSignedTransaction(
    message : [Nat8],
    signatures : [[Nat8]]
  ) : Result.Result<[Nat8], Text> {
    // Verify signature length (Ed25519 signatures are 64 bytes)
    for (sig in signatures.vals()) {
      if (sig.size() != 64) {
        return #err("Invalid signature length: expected 64 bytes, got " # Nat.toText(sig.size()))
      };
    };
    
    var transaction = Buffer.Buffer<Nat8>(1000);
    
    // Signatures (compact-u16 length, then signatures)
    let numSignatures = signatures.size();
    let numSignaturesEncoded = encodeCompactU16(numSignatures);
    for (byte in numSignaturesEncoded.vals()) {
      transaction.add(byte);
    };
    for (sig in signatures.vals()) {
      for (byte in sig.vals()) {
        transaction.add(byte);
      };
    };
    
    // Message
    for (byte in message.vals()) {
      transaction.add(byte);
    };
    
    #ok(Buffer.toArray(transaction))
  };
};

