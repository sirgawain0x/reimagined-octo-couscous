import Base58 "mo:base58/Base58";
import Base58Check "mo:base58check/Base58Check";
import Hmac "mo:hmac/Hmac";
import Ripemd160 "mo:ripemd160/Ripemd160";
import Sha256 "mo:sha256/Sha256";
import Jacobi "mo:ec/Jacobi";
import Affine "mo:ec/Affine";
import Curves "mo:ec/Curves";
import Bip32 "mo:bip32/Bip32";
import Bech32 "mo:bech32/Bech32";
import Segwit "mo:segwit/Segwit";

module BitcoinUtils {
  public type AddressType = {
    #P2PKH;
    #P2SH;
    #P2WPKH;
    #P2WSH;
    #P2TR;
  };

  /// Generate Bitcoin address from public key hash
  public func generateAddress(
    publicKeyHash : [Nat8],
    addressType : AddressType
  ) : Text {
    switch addressType {
      case (#P2PKH) generateP2PKH(publicKeyHash);
      case (#P2SH) generateP2SH(publicKeyHash);
      case (#P2WPKH) generateP2WPKH(publicKeyHash);
      case (#P2WSH) generateP2WSH(publicKeyHash);
      case (#P2TR) generateP2TR(publicKeyHash);
    }
  };

  /// Generate P2PKH (Pay-to-PubKey-Hash) address
  func generateP2PKH(publicKeyHash : [Nat8]) : Text {
    // Add version byte (0x00 for mainnet, 0x6f for testnet)
    let versionedHash = Array.append([0 : Nat8], publicKeyHash);
    // Base58Check encode
    Base58Check.encode(versionedHash)
  };

  /// Generate P2SH (Pay-to-Script-Hash) address
  func generateP2SH(scriptHash : [Nat8]) : Text {
    // Add version byte (0x05 for mainnet, 0xc4 for testnet)
    let versionedHash = Array.append([5 : Nat8], scriptHash);
    // Base58Check encode
    Base58Check.encode(versionedHash)
  };

  /// Generate P2WPKH (Pay-to-Witness-PubKey-Hash) address
  func generateP2WPKH(publicKeyHash : [Nat8]) : Text {
    // Bech32 encode for mainnet
    Bech32.encode("bc", publicKeyHash, #BECH32)
  };

  /// Generate P2WSH (Pay-to-Witness-Script-Hash) address
  func generateP2WSH(scriptHash : [Nat8]) : Text {
    // Bech32 encode for mainnet
    Bech32.encode("bc", scriptHash, #BECH32)
  };

  /// Generate P2TR (Pay-to-Taproot) address
  func generateP2TR(xOnlyPublicKey : [Nat8]) : Text {
    // Generate Taproot address
    Segwit.encode("bc", xOnlyPublicKey)
  };

  /// Hash public key with RIPEMD160(SHA256(key))
  public func hashPublicKey(publicKey : [Nat8]) : [Nat8] {
    let sha256Hash = Sha256.digest(publicKey);
    let ripemd160 = Ripemd160.Digest();
    ripemd160.write(sha256Hash);
    ripemd160.sum()
  };

  /// Derive HD wallet key path
  public func deriveKeyPath(
    masterKey : Bip32.ExtendedPrivateKey,
    path : Text
  ) : ?Bip32.ExtendedPrivateKey {
    masterKey.derivePath(#text path)
  };

  /// Validate Bitcoin address
  public func validateAddress(address : Text) : Bool {
    // Check if it's a Bech32 address (starts with bc1, tb1, or bcrt1)
    if (address.startsWith("bc1") or address.startsWith("tb1") or address.startsWith("bcrt1")) {
      switch (Bech32.decode("bc", address)) {
        case (#ok(_, _)) true;
        case (#err(_)) false
      }
    } else {
      // Try Base58Check validation
      switch (Base58Check.decode(address)) {
        case (#ok(version, _)) version == 0 or version == 111 or version == 5 or version == 196;
        case (#err(_)) false
      }
    }
  };

  /// Convert bytes to hex string
  public func bytesToHex(bytes : [Nat8]) : Text {
    var hex = "";
    for (byte in bytes.vals()) {
      hex #= Nat8.toText(byte / 16, 16) # Nat8.toText(byte % 16, 16)
    };
    hex
  };

  /// Convert hex string to bytes
  public func hexToBytes(hex : Text) : ?[Nat8] {
    let chars = Text.toIter(hex);
    var bytes : [var Nat8] = Array.init<Nat8>(hex.size() / 2 + (hex.size() % 2), 0);
    var i = 0;
    var byte : Nat8 = 0;
    
    for (char in chars) {
      let nibble : ?Nat8 = charToNibble(char);
      switch nibble {
        case (?n) {
          if (i % 2 == 0) {
            byte := n * 16
          } else {
            bytes[i / 2] := byte + n;
            byte := 0
          };
          i += 1
        };
        case null return null
      }
    };
    
    if (i % 2 != 0) return null;
    
    ?Array.freeze(bytes)
  };

  func charToNibble(char : Char) : ?Nat8 {
    switch (char.toText()) {
      case ("0") ?0;
      case ("1") ?1;
      case ("2") ?2;
      case ("3") ?3;
      case ("4") ?4;
      case ("5") ?5;
      case ("6") ?6;
      case ("7") ?7;
      case ("8") ?8;
      case ("9") ?9;
      case ("a") ?10;
      case ("A") ?10;
      case ("b") ?11;
      case ("B") ?11;
      case ("c") ?12;
      case ("C") ?12;
      case ("d") ?13;
      case ("D") ?13;
      case ("e") ?14;
      case ("E") ?14;
      case ("f") ?15;
      case ("F") ?15;
      case _ null
    }
  };
};

