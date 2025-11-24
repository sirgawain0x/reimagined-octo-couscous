// ICP Ledger Integration Module
// Provides interfaces and utilities for interacting with ICP ledger (ICRC-1)
// ICP is the native token of the Internet Computer

import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

module ICPLedger {
  public type Result<Ok, Err> = Result.Result<Ok, Err>;
  
  // ICRC-1 Standard Types
  public type Account = {
    owner : Principal;
    subaccount : ?Blob;
  };

  public type TransferArgs = {
    from : Account;
    to : Account;
    amount : Nat;
    fee : ?Nat;
    memo : ?Blob;
    created_at_time : ?Nat64;
  };

  public type TransferError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #InsufficientFunds : { balance : Nat };
    #BadBurn : { min_burn_amount : Nat };
    #Duplicate : { duplicate_of : Nat };
    #BadFee : { expected_fee : Nat };
  };

  public type TxIndex = Nat;

  // ICP Ledger Actor Interface (ICRC-1)
  // Mainnet: ryjl3-tyaaa-aaaaa-aaaba-cai
  public type ICP_LEDGER = actor {
    icrc1_transfer : (TransferArgs) -> async Result.Result<TxIndex, TransferError>;
    icrc1_balance_of : (Account) -> async Nat;
    icrc1_decimals : () -> async Nat8;
    icrc1_symbol : () -> async Text;
    icrc1_name : () -> async Text;
    icrc1_fee : () -> async Nat;
    icrc1_metadata : () -> async [(Text, { #Nat : Nat; #Int : Int; #Text : Text; #Blob : Blob })];
  };

  // Canister IDs
  // Mainnet Ledger: ryjl3-tyaaa-aaaaa-aaaba-cai
  // Testnet: (to be configured)

  /// Create ICP ledger actor from principal
  public func createLedgerActor(ledgerId : Principal) : ICP_LEDGER {
    actor(Principal.toText(ledgerId)) : ICP_LEDGER
  };

  /// Get ICP balance for an account
  public func getBalance(
    ledger : ICP_LEDGER,
    account : Account
  ) : async Result<Nat, Text> {
    try {
      let balance = await ledger.icrc1_balance_of(account);
      #ok(balance)
    } catch (_) {
      #err("Failed to get ICP balance. Network error or canister unavailable.")
    }
  };

  /// Transfer ICP
  public func transfer(
    ledger : ICP_LEDGER,
    from : Account,
    to : Account,
    amount : Nat,
    fee : ?Nat,
    memo : ?Blob
  ) : async Result<TxIndex, Text> {
    try {
      let result = await ledger.icrc1_transfer({
        from;
        to;
        amount;
        fee;
        memo;
        created_at_time = null;
      });
      switch result {
        case (#ok(txIndex)) #ok(txIndex);
        case (#err(err)) {
          let errorMsg = switch err {
            case (#GenericError({ message; error_code = _ })) "Generic error: " # message;
            case (#TemporarilyUnavailable) "Temporarily unavailable";
            case (#InsufficientFunds({ balance })) "Insufficient funds. Balance: " # Nat.toText(balance);
            case (#BadBurn({ min_burn_amount })) "Bad burn. Min amount: " # Nat.toText(min_burn_amount);
            case (#Duplicate({ duplicate_of })) "Duplicate transaction: " # Nat.toText(duplicate_of);
            case (#BadFee({ expected_fee })) "Bad fee. Expected: " # Nat.toText(expected_fee);
          };
          #err(errorMsg)
        }
      }
    } catch (_) {
      #err("Failed to transfer ICP")
    }
  };
};

