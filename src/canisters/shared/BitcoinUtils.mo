import Base58Check "mo:bitcoin/Base58Check";
import Ripemd160 "mo:bitcoin/Ripemd160";
import Sha256 "mo:sha2/Sha256";
import Blob "mo:base/Blob";
import Bech32 "mo:bitcoin/Bech32";
import Segwit "mo:bitcoin/Segwit";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Char "mo:base/Char";

module BitcoinUtils {
  public type AddressType = {
    #P2PKH;
    #P2SH;
    #P2WPKH;
    #P2WSH;
    #P2TR;
  };

  public type Network = {
    #Mainnet;
    #Testnet;
    #Regtest;
  };

  /// Generate Bitcoin address from public key hash with network support
  public func generateAddress(
    publicKeyHash : [Nat8],
    addressType : AddressType,
    network : Network
  ) : Text {
    switch addressType {
      case (#P2PKH) generateP2PKH(publicKeyHash, network);
      case (#P2SH) generateP2SH(publicKeyHash, network);
      case (#P2WPKH) generateP2WPKH(publicKeyHash, network);
      case (#P2WSH) generateP2WSH(publicKeyHash, network);
      case (#P2TR) generateP2TR(publicKeyHash, network);
    }
  };

  /// Get network prefix for Bech32 addresses
  func getNetworkPrefix(network : Network) : Text {
    switch network {
      case (#Mainnet) "bc";
      case (#Testnet) "tb";
      case (#Regtest) "bcrt";
    }
  };

  /// Get version byte for P2PKH addresses
  func getP2PKHVersionByte(network : Network) : Nat8 {
    switch network {
      case (#Mainnet) 0 : Nat8;   // 0x00
      case (#Testnet) 111 : Nat8; // 0x6f
      case (#Regtest) 111 : Nat8; // 0x6f (regtest uses testnet version)
    }
  };

  /// Get version byte for P2SH addresses
  func getP2SHVersionByte(network : Network) : Nat8 {
    switch network {
      case (#Mainnet) 5 : Nat8;   // 0x05
      case (#Testnet) 196 : Nat8; // 0xc4
      case (#Regtest) 196 : Nat8; // 0xc4 (regtest uses testnet version)
    }
  };

  /// Generate P2PKH (Pay-to-PubKey-Hash) address
  func generateP2PKH(publicKeyHash : [Nat8], network : Network) : Text {
    let versionByte = getP2PKHVersionByte(network);
    let versionedHash = Array.append([versionByte], publicKeyHash);
    Base58Check.encode(versionedHash)
  };

  /// Generate P2SH (Pay-to-Script-Hash) address
  func generateP2SH(scriptHash : [Nat8], network : Network) : Text {
    let versionByte = getP2SHVersionByte(network);
    let versionedHash = Array.append([versionByte], scriptHash);
    Base58Check.encode(versionedHash)
  };

  /// Generate P2WPKH (Pay-to-Witness-PubKey-Hash) address
  func generateP2WPKH(publicKeyHash : [Nat8], network : Network) : Text {
    let prefix = getNetworkPrefix(network);
    let witnessProgram = {
      version = 0 : Nat8;
      program = publicKeyHash;
    };
    switch (Segwit.encode(prefix, witnessProgram)) {
      case (#ok(address)) address;
      case (#err(_)) ""; // Fallback - should not happen
    }
  };

  /// Generate P2WSH (Pay-to-Witness-Script-Hash) address
  func generateP2WSH(scriptHash : [Nat8], network : Network) : Text {
    let prefix = getNetworkPrefix(network);
    let witnessProgram = {
      version = 0 : Nat8;
      program = scriptHash;
    };
    switch (Segwit.encode(prefix, witnessProgram)) {
      case (#ok(address)) address;
      case (#err(_)) ""; // Fallback - should not happen
    }
  };

  /// Generate P2TR (Pay-to-Taproot) address
  func generateP2TR(xOnlyPublicKey : [Nat8], network : Network) : Text {
    let prefix = getNetworkPrefix(network);
    let witnessProgram = {
      version = 1 : Nat8;
      program = xOnlyPublicKey;
    };
    switch (Segwit.encode(prefix, witnessProgram)) {
      case (#ok(address)) address;
      case (#err(_)) ""; // Fallback - should not happen
    }
  };

  /// Hash public key with RIPEMD160(SHA256(key))
  public func hashPublicKey(publicKey : [Nat8]) : [Nat8] {
    let sha256Hash = Blob.toArray(Sha256.fromArray(#sha256, publicKey));
    let ripemd160 = Ripemd160.Digest();
    ripemd160.write(sha256Hash);
    ripemd160.sum()
  };

  /// Derive HD wallet key path (Note: Bitcoin package only supports ExtendedPublicKey)
  // public func deriveKeyPath(
  //   masterKey : Bip32.ExtendedPrivateKey,
  //   path : Text
  // ) : ?Bip32.ExtendedPrivateKey {
  //   masterKey.derivePath(#text path)
  // };

  /// Validate Bitcoin address
  public func validateAddress(address : Text) : Bool {
    // Check if it's a Bech32 address (starts with bc1, tb1, or bcrt1)
    let isBech32 = Text.startsWith(address, #text "bc1") or 
                   Text.startsWith(address, #text "tb1") or 
                   Text.startsWith(address, #text "bcrt1");
    
    if (isBech32) {
      switch (Bech32.decode(address)) {
        case (#ok((_, _, _))) true;
        case (#err(_)) false
      }
    } else {
      // Try Base58Check validation
      switch (Base58Check.decode(address)) {
        case (?decoded) {
          // Version byte is the first byte
          if (decoded.size() > 0) {
            let version = decoded[0];
            version == 0 or version == 111 or version == 5 or version == 196
          } else {
            false
          }
        };
        case null false
      }
    }
  };

  func nibbleToHex(nibble : Nat8) : Text {
    switch (nibble) {
      case 0 "0"; case 1 "1"; case 2 "2"; case 3 "3";
      case 4 "4"; case 5 "5"; case 6 "6"; case 7 "7";
      case 8 "8"; case 9 "9"; case 10 "a"; case 11 "b";
      case 12 "c"; case 13 "d"; case 14 "e"; case 15 "f";
      case _ "0"
    }
  };

  /// Convert bytes to hex string
  public func bytesToHex(bytes : [Nat8]) : Text {
    var hex = "";
    for (byte in bytes.vals()) {
      let highNibble = byte >> 4;
      let lowNibble = byte & 15;
      hex #= nibbleToHex(highNibble) # nibbleToHex(lowNibble)
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
    switch (Char.toText(char)) {
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

