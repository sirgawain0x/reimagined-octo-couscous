// Bitcoin Utilities for ICP
// Uses threshold ECDSA and Schnorr system APIs to generate Bitcoin addresses
// This module integrates with ICP's native Bitcoin support

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";

// Import ICP system APIs for threshold signing
import ECDSA "mo:base/ExperimentalCycles";
import IC "mo:base/ExperimentalCycles"; // For accessing system API

module BitcoinUtilsICP {
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

  // ECDSA key name for threshold signing
  private let ECDSA_KEY_NAME : Text = "key_1";
  
  // Schnorr key name for Taproot
  private let SCHNORR_KEY_NAME : Text = "key_1";

  // Derivation path helper
  public type DerivationPath = [Blob];

  /// Get ECDSA public key from ICP system API
  /// This is used for P2PKH, P2SH, P2WPKH addresses
  public func getEcdsaPublicKey(
    derivationPath : DerivationPath
  ) : async Result.Result<[Nat8], Text> {
    // Note: This is a placeholder for the actual system API call
    // In production, you would use:
    // let response = await IC.canister_sign_with_ecdsa({
    //   message_hash = ...
    //   derivation_path = derivationPath;
    //   key_id = { curve = #secp256k1; name = ECDSA_KEY_NAME };
    // });
    // For now, return error indicating implementation needed
    #err("ECDSA public key retrieval requires ICP system API integration. See INTERNET_IDENTITY_SETUP.md for details.")
  };

  /// Get Schnorr public key from ICP system API
  /// This is used for P2TR (Taproot) addresses
  public func getSchnorrPublicKey(
    derivationPath : DerivationPath
  ) : async Result.Result<[Nat8], Text> {
    // Note: This is a placeholder for the actual system API call
    // In production, you would use:
    // let response = await IC.canister_sign_with_schnorr({
    //   message = ...
    //   derivation_path = derivationPath;
    //   key_id = { curve = #secp256k1; name = SCHNORR_KEY_NAME };
    // });
    #err("Schnorr public key retrieval requires ICP system API integration. See INTERNET_IDENTITY_SETUP.md for details.")
  };

  /// Generate P2PKH address using ECDSA public key
  /// Legacy addresses starting with '1'
  /// Uses RIPEMD160(SHA256(publicKey))
  public func generateP2PKHAddress(
    ecdsaCanisterActor : Principal,
    network : Network,
    derivationPath : DerivationPath
  ) : async Result.Result<Text, Text> {
    // This would call the canister's ECDSA actor to get the public key
    // then hash it and encode as Base58Check
    // For now, return error indicating need for full implementation
    #err("P2PKH address generation requires full ECDSA integration. Use BitcoinUtils.mo utilities once public key is retrieved.")
  };

  /// Generate P2TR key-only address using Schnorr public key
  /// Taproot address that can only be spent with a Schnorr signature
  public func generateP2TRKeyOnlyAddress(
    schnorrCanisterActor : Principal,
    network : Network,
    derivationPath : DerivationPath
  ) : async Result.Result<Text, Text> {
    // This would call the canister's Schnorr actor to get the x-only public key
    // then encode as Bech32m for Taproot
    #err("P2TR key-only address generation requires full Schnorr integration. Use BitcoinUtils.mo utilities once public key is retrieved.")
  };

  /// Generate P2TR address (key or script) using Schnorr public key
  /// Taproot address that can be spent with either Schnorr signature or script
  public func generateP2TRAddress(
    schnorrCanisterActor : Principal,
    network : Network,
    derivationPath : DerivationPath
  ) : async Result.Result<Text, Text> {
    // This would call the canister's Schnorr actor to get the x-only public key
    // then create a Taproot output with optional script commitment
    #err("P2TR address generation requires full Schnorr integration. Use BitcoinUtils.mo utilities once public key is retrieved.")
  };

  /// Create derivation path from index
  /// ICP uses fixed derivation paths based on address indexes
  public func createDerivationPath(index : Nat32) : DerivationPath {
    // Convert index to blob for derivation path
    // Format: [0] for index 0, [1] for index 1, etc.
    let indexBlob = Blob.fromArray(Array.init<Nat8>(1, Nat8.fromIntWrap(index)));
    [indexBlob]
  };

  /// Validate Bitcoin address format
  /// Checks if address follows correct format for its type
  public func validateAddress(address : Text, network : Network) : Bool {
    // Check legacy addresses (P2PKH starts with 1, P2SH with 3)
    if (address.size() > 0 and address.size() < 35) {
      let firstChar = Text.substring(address, 0, 1);
      if (firstChar == "1" or firstChar == "3") {
        // Basic format check - full validation requires Base58Check decoding
        return true
      }
    };
    
    // Check Bech32 addresses (SegWit and Taproot)
    if (Text.startsWith(address, #text getNetworkPrefix(network) # "1")) {
      // Basic format check - full validation requires Bech32 decoding
      return true
    };
    
    false
  };

  /// Get network prefix for Bech32 addresses
  private func getNetworkPrefix(network : Network) : Text {
    switch network {
      case (#Mainnet) "bc";
      case (#Testnet) "tb";
      case (#Regtest) "bcrt";
    }
  };

  /// Hash public key using RIPEMD160(SHA256(publicKey))
  /// This is used for P2PKH and P2WPKH address generation
  public func hashPublicKey(publicKey : [Nat8]) : async Result.Result<[Nat8], Text> {
    // This should use the BitcoinUtils.hashPublicKey function
    // For now, return error
    #err("Public key hashing requires BitcoinUtils.mo integration")
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
};

