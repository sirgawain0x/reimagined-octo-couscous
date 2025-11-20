// Bitcoin Utilities for ICP
// Uses threshold ECDSA and Schnorr system APIs to generate Bitcoin addresses
// This module integrates with ICP's native Bitcoin support

import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Array "mo:base/Array";
import BitcoinUtils "BitcoinUtils";
import Sha256 "mo:sha2/Sha256";

module BitcoinUtilsICP {
  // ECDSA Canister Actor interface for accessing ICP system APIs
  public type EcdsaCanisterActor = actor {
    ecdsa_public_key : ({
      canister_id : ?Principal;
      derivation_path : [Blob];
      key_id : {
        curve : { #secp256k1 };
        name : Text;
      };
    }) -> async {
      public_key : Blob;
      chain_code : Blob;
    };
    sign_with_ecdsa : ({
      message_hash : Blob;
      derivation_path : [Blob];
      key_id : {
        curve : { #secp256k1 };
        name : Text;
      };
    }) -> async {
      signature : Blob;
    };
  };

  // Schnorr Canister Actor interface (for future Taproot support)
  // Note: Schnorr API may be available through IC system API or separate canister
  public type SchnorrCanisterActor = actor {
    schnorr_public_key : ({
      canister_id : ?Principal;
      derivation_path : [Blob];
      key_id : {
        name : Text;
      };
    }) -> async {
      public_key : Blob;
    };
    sign_with_schnorr : ({
      message : Blob;
      derivation_path : [Blob];
      key_id : {
        name : Text;
      };
    }) -> async {
      signature : Blob;
    };
  };
  // Network types for Bitcoin address generation
  public type Network = {
    #Mainnet;
    #Testnet;
    #Regtest;
  };

  // Address types supported by ICP
  public type AddressType = {
    #P2PKH; // Pay-to-PubKey-Hash (legacy, starts with 1)
    #P2SH; // Pay-to-Script-Hash (legacy, starts with 3)
    #P2WPKH; // Pay-to-Witness-PubKey-Hash (SegWit, bc1...)
    #P2WSH; // Pay-to-Witness-Script-Hash (SegWit, bc1...)
    #P2TR; // Pay-to-Taproot (Taproot, bc1p...)
  };

  // Default ECDSA key name for threshold signing
  // Use "dfx_test_key" for local development, "key_1" for production
  private let DEFAULT_ECDSA_KEY_NAME : Text = "dfx_test_key";
  
  // Default Schnorr key name for Taproot (reserved for future use)
  private let _DEFAULT_SCHNORR_KEY_NAME : Text = "dfx_test_key";

  // Derivation path helper
  public type DerivationPath = [Blob];

  // Get ECDSA management canister actor (aaaaa-aa)
  // This is the system canister that provides ECDSA APIs
  private func getEcdsaCanister() : EcdsaCanisterActor {
    // Management canister ID: aaaaa-aa (null Principal)
    // In Motoko, we can reference it directly
    actor "aaaaa-aa" : EcdsaCanisterActor
  };

  // Get Schnorr management canister actor (aaaaa-aa)
  // Note: Schnorr API may be available through the same management canister
  // or through IC system API. This implementation attempts the management canister first.
  private func getSchnorrCanister() : SchnorrCanisterActor {
    // Try using the same management canister
    // If Schnorr API is not available, the call will fail and can be handled by the caller
    actor "aaaaa-aa" : SchnorrCanisterActor
  };

  /// Get ECDSA public key from ICP system API
  /// This is used for P2PKH, P2SH, P2WPKH addresses
  /// Uses the ECDSA management canister (aaaaa-aa)
  public func getEcdsaPublicKey(
    derivationPath : DerivationPath,
    keyName : ?Text
  ) : async Result.Result<[Nat8], Text> {
    let ecdsaCanister = getEcdsaCanister();
    let key = Option.get<Text>(keyName, DEFAULT_ECDSA_KEY_NAME);
    
    let response = await ecdsaCanister.ecdsa_public_key({
      canister_id = null; // null means current canister
      derivation_path = derivationPath;
      key_id = {
        curve = #secp256k1;
        name = key;
      };
    });
    
    let publicKeyBytes = Blob.toArray(response.public_key);
    #ok(publicKeyBytes)
  };

  /// Get Schnorr public key from ICP system API
  /// This is used for P2TR (Taproot) addresses
  /// Uses the threshold Schnorr system API through the management canister
  /// Note: This API may not be available in all IC environments yet
  /// When available, it will return a 32-byte x-only public key for Taproot
  /// 
  /// IMPORTANT: If the Schnorr API is not yet available in your IC environment,
  /// this function will return an error. The API becomes available when IC
  /// releases threshold Schnorr signature support.
  public func getSchnorrPublicKey(
    derivationPath : DerivationPath,
    keyName : ?Text
  ) : async Result.Result<[Nat8], Text> {
    let schnorrCanister = getSchnorrCanister();
    // Default key name for Schnorr (may differ from ECDSA in some environments)
    let key = Option.get<Text>(keyName, DEFAULT_ECDSA_KEY_NAME);
    
    // Call Schnorr public key API
    // This returns an x-only public key (32 bytes) for Taproot
    // If the API is not available, the await will fail and propagate to the caller
    let response = await schnorrCanister.schnorr_public_key({
      canister_id = null; // null means current canister
      derivation_path = derivationPath;
      key_id = {
        name = key;
      };
    });
    
    let publicKeyBytes = Blob.toArray(response.public_key);
    
    // Verify we got a 32-byte x-only public key (required for Taproot)
    if (publicKeyBytes.size() != 32) {
      #err("Invalid Schnorr public key size. Expected 32 bytes for x-only public key, got " # Nat32.toText(Nat32.fromNat(publicKeyBytes.size())))
    } else {
      #ok(publicKeyBytes)
    }
  };

  /// Generate P2PKH address using ECDSA public key
  /// Legacy addresses starting with '1'
  /// Uses RIPEMD160(SHA256(publicKey))
  public func generateP2PKHAddress(
    network : Network,
    derivationPath : DerivationPath,
    keyName : ?Text
  ) : async Result.Result<Text, Text> {
    switch (await getEcdsaPublicKey(derivationPath, keyName)) {
      case (#err(msg)) #err(msg);
      case (#ok(publicKey)) {
        // Hash the public key
        let publicKeyHash = BitcoinUtils.hashPublicKey(publicKey);
        
        // Use BitcoinUtils to generate the address with network support
        let address = BitcoinUtils.generateAddress(publicKeyHash, #P2PKH, network);
        #ok(address)
      }
    }
  };

  /// Generate P2WPKH address using ECDSA public key
  /// SegWit addresses starting with 'bc1q' (mainnet), 'tb1q' (testnet), or 'bcrt1q' (regtest)
  public func generateP2WPKHAddress(
    network : Network,
    derivationPath : DerivationPath,
    keyName : ?Text
  ) : async Result.Result<Text, Text> {
    switch (await getEcdsaPublicKey(derivationPath, keyName)) {
      case (#err(msg)) #err(msg);
      case (#ok(publicKey)) {
        let publicKeyHash = BitcoinUtils.hashPublicKey(publicKey);
        let address = BitcoinUtils.generateAddress(publicKeyHash, #P2WPKH, network);
        #ok(address)
      }
    }
  };

  /// Generate P2TR key-only address using Schnorr public key
  /// Taproot address that can only be spent with a Schnorr signature
  /// Addresses start with 'bc1p' (mainnet), 'tb1p' (testnet), or 'bcrt1p' (regtest)
  public func generateP2TRKeyOnlyAddress(
    network : Network,
    derivationPath : DerivationPath,
    keyName : ?Text
  ) : async Result.Result<Text, Text> {
    switch (await getSchnorrPublicKey(derivationPath, keyName)) {
      case (#err(msg)) #err(msg);
      case (#ok(xOnlyPublicKey)) {
        // Schnorr public key is already x-only (32 bytes)
        // For key-only Taproot, we use it directly
        let address = BitcoinUtils.generateAddress(xOnlyPublicKey, #P2TR, network);
        #ok(address)
      }
    }
  };

  /// Generate P2TR address (key or script) using Schnorr public key
  /// Taproot address that can be spent with either Schnorr signature or script
  /// For now, this is the same as key-only. Script commitment requires additional Merkle tree logic
  /// Addresses start with 'bc1p' (mainnet), 'tb1p' (testnet), or 'bcrt1p' (regtest)
  public func generateP2TRAddress(
    network : Network,
    derivationPath : DerivationPath,
    keyName : ?Text
  ) : async Result.Result<Text, Text> {
    // For key-or-script, we use a different derivation path index
    // The actual script commitment would require building a Merkle tree
    // For now, we'll use the same approach as key-only
    await generateP2TRKeyOnlyAddress(network, derivationPath, keyName)
  };

  /// Create derivation path from index
  /// ICP uses fixed derivation paths based on address indexes
  public func createDerivationPath(index : Nat32) : DerivationPath {
    // Convert index to blob for derivation path
    // Format: [0] for index 0, [1] for index 1, etc.
    let indexByte = Nat8.fromIntWrap(Nat32.toNat(index));
    let indexBlob = Blob.fromArray([indexByte]);
    [indexBlob]
  };

  /// Validate Bitcoin address format
  /// Checks if address follows correct format for its type and network
  public func validateAddress(address : Text, network : Network) : Bool {
    if (address.size() == 0) {
      return false
    };
    
    // Check legacy addresses (P2PKH starts with 1, P2SH with 3)
    // These are network-agnostic in format but we validate the version byte
    if (address.size() >= 26 and address.size() <= 35) {
      if (Text.startsWith(address, #text "1") or Text.startsWith(address, #text "3")) {
        // Validate using BitcoinUtils which checks version bytes
        return BitcoinUtils.validateAddress(address)
      }
    };
    
    // Check Bech32 addresses (SegWit and Taproot)
    // Network-specific prefixes:
    // Mainnet: "bc1" (P2WPKH/P2WSH) or "bc1p" (P2TR)
    // Testnet: "tb1" (P2WPKH/P2WSH) or "tb1p" (P2TR)
    // Regtest: "bcrt1" (P2WPKH/P2WSH) or "bcrt1p" (P2TR), also accepts "bc1" for compatibility
    switch network {
      case (#Mainnet) {
        Text.startsWith(address, #text "bc1")
      };
      case (#Testnet) {
        Text.startsWith(address, #text "tb1")
      };
      case (#Regtest) {
        // Regtest accepts both bcrt1 and bc1 for compatibility
        Text.startsWith(address, #text "bcrt1") or Text.startsWith(address, #text "bc1")
      }
    }
  };

  /// Get network prefix for Bech32 addresses
  /// Note: Reserved for future use when network-specific prefix handling is needed
  private func _getNetworkPrefix(network : Network) : Text {
    switch network {
      case (#Mainnet) "bc";
      case (#Testnet) "tb";
      case (#Regtest) "bcrt";
    }
  };

  /// Hash public key using RIPEMD160(SHA256(publicKey))
  /// This is used for P2PKH and P2WPKH address generation
  public func hashPublicKey(publicKey : [Nat8]) : [Nat8] {
    BitcoinUtils.hashPublicKey(publicKey)
  };

  /// Convert UTXO information to address
  /// ICP Bitcoin API returns UTXOs with script public keys
  /// This helps identify which address type was used
  public func utxoToAddressType(scriptPubKey : [Nat8]) : ?AddressType {
    // Analyze scriptPubKey to determine address type
    // P2PKH: OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG
    // P2SH: OP_HASH160 <20 bytes> OP_EQUAL
    // P2WPKH: OP_0 <20 bytes>
    // P2WSH: OP_0 <32 bytes>
    // P2TR: OP_1 <32 bytes>
    if (scriptPubKey.size() == 25 and scriptPubKey[0] == 0x76) {
      ?#P2PKH
    } else if (scriptPubKey.size() == 23 and scriptPubKey[0] == 0xa9) {
      ?#P2SH
    } else if (scriptPubKey.size() == 22 and scriptPubKey[0] == 0x00) {
      ?#P2WPKH
    } else if (scriptPubKey.size() == 34 and scriptPubKey[0] == 0x00) {
      ?#P2WSH
    } else if (scriptPubKey.size() == 34 and scriptPubKey[0] == 0x51) {
      ?#P2TR
    } else {
      null
    }
  };

  /// Compute double SHA256 hash of transaction data
  /// This is used for transaction signing (Bitcoin uses double SHA256)
  public func computeTransactionHash(txBytes : [Nat8]) : [Nat8] {
    // First SHA256
    let firstHash = Blob.toArray(Sha256.fromArray(#sha256, txBytes));
    // Second SHA256 (double hash)
    Blob.toArray(Sha256.fromArray(#sha256, firstHash))
  };

  /// Sign a transaction hash using threshold ECDSA
  /// The messageHash must be a 32-byte double SHA256 hash of the transaction
  /// Returns the DER-encoded signature
  public func signTransactionHash(
    messageHash : [Nat8],
    derivationPath : DerivationPath,
    keyName : ?Text
  ) : async Result.Result<[Nat8], Text> {
    // Verify message hash is 32 bytes
    if (messageHash.size() != 32) {
      return #err("Message hash must be 32 bytes, got " # Nat32.toText(Nat32.fromNat(messageHash.size())))
    };

    let ecdsaCanister = getEcdsaCanister();
    let key = Option.get<Text>(keyName, DEFAULT_ECDSA_KEY_NAME);
    
    try {
      let response = await ecdsaCanister.sign_with_ecdsa({
        message_hash = Blob.fromArray(messageHash);
        derivation_path = derivationPath;
        key_id = {
          curve = #secp256k1;
          name = key;
        };
      });
      
      let signatureBytes = Blob.toArray(response.signature);
      #ok(signatureBytes)
    } catch (_) {
      #err("Failed to sign transaction hash")
    }
  };

  /// Sign a transaction by computing its hash and signing it
  /// This is a convenience function that combines hash computation and signing
  public func signTransaction(
    txBytes : [Nat8],
    derivationPath : DerivationPath,
    keyName : ?Text
  ) : async Result.Result<[Nat8], Text> {
    let messageHash = computeTransactionHash(txBytes);
    await signTransactionHash(messageHash, derivationPath, keyName)
  };
};

