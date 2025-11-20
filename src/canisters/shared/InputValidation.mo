// Input Validation Module
// Provides validation utilities for canister inputs

import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";

module InputValidation {
  /// Validate Bitcoin address format
  /// Checks basic format requirements (not full cryptographic validation)
  public func validateBitcoinAddress(address : Text, network : { #Mainnet; #Testnet; #Regtest }) : Bool {
    if (address.size() == 0) {
      return false
    };
    
    // Check legacy addresses (P2PKH starts with 1, P2SH with 3)
    if (Text.startsWith(address, #text "1") or Text.startsWith(address, #text "3")) {
      // Basic length check for legacy addresses (26-35 characters)
      return address.size() >= 26 and address.size() <= 35
    };
    
    // Check Bech32 addresses (SegWit and Taproot)
    switch network {
      case (#Mainnet) Text.startsWith(address, #text "bc1");
      case (#Testnet) Text.startsWith(address, #text "tb1");
      case (#Regtest) Text.startsWith(address, #text "bcrt1") or Text.startsWith(address, #text "bc1")
    }
  };

  /// Validate amount is within acceptable range
  public func validateAmount(amount : Nat64, minAmount : Nat64, maxAmount : ?Nat64) : Bool {
    if (amount < minAmount) {
      return false
    };
    switch maxAmount {
      case null true;
      case (?max) amount <= max
    }
  };

  /// Validate amount (Nat version)
  public func validateAmountNat(amount : Nat, minAmount : Nat, maxAmount : ?Nat) : Bool {
    if (amount < minAmount) {
      return false
    };
    switch maxAmount {
      case null true;
      case (?max) amount <= max
    }
  };

  /// Validate principal is not anonymous
  public func validatePrincipal(principal : Principal) : Bool {
    not Principal.isAnonymous(principal)
  };

  /// Validate text is not empty and within length limits
  public func validateText(text : Text, minLength : Nat, maxLength : ?Nat) : Bool {
    let length = text.size();
    if (length < minLength) {
      return false
    };
    switch maxLength {
      case null true;
      case (?max) length <= max
    }
  };

  /// Validate asset symbol
  public func validateAssetSymbol(symbol : Text) : Bool {
    // Asset symbols should be 2-10 characters, alphanumeric
    if (symbol.size() < 2 or symbol.size() > 10) {
      return false
    };
    // Check if all characters are alphanumeric (A-Z, a-z, 0-9)
    let chars = symbol.chars();
    loop {
      switch (chars.next()) {
        case null return true; // All characters checked, all valid
        case (?c) {
          let code = Char.toNat32(c);
          let isAlphanumeric = (code >= 48 and code <= 57) or  // 0-9
                               (code >= 65 and code <= 90) or  // A-Z
                               (code >= 97 and code <= 122);  // a-z
          if (not isAlphanumeric) {
            return false // Found invalid character
          };
          // Continue to next iteration
        }
      }
    }
  };
};


