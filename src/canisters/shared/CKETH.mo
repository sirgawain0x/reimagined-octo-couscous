// ckETH Integration Module
// Provides interfaces and utilities for interacting with ckETH ledger and minter
// ckETH is Chain-Key Ethereum, an ICRC-2 token on ICP

import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

module CKETH {
  public type Result<Ok, Err> = Result.Result<Ok, Err>;
  // ICRC-2 Standard Types (same as ckBTC)
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
  public type BlockIndex = Nat;

  // ckETH Ledger Actor Interface (ICRC-2)
  public type CKETH_LEDGER = actor {
    icrc1_transfer : (TransferArgs) -> async Result.Result<TxIndex, TransferError>;
    icrc1_balance_of : (Account) -> async Nat;
    icrc1_decimals : () -> async Nat8;
    icrc1_symbol : () -> async Text;
    icrc1_name : () -> async Text;
    icrc1_fee : () -> async Nat;
    icrc1_metadata : () -> async [(Text, { #Nat : Nat; #Int : Int; #Text : Text; #Blob : Blob })];
  };

  // ckETH Minter Types
  public type MintTx = {
    amount : Nat;
    block_index : BlockIndex;
  };

  public type MinterError = {
    #TemporarilyUnavailable : { error_message : Text; error_code : Nat };
    #MalformedAddress;
    #InsufficientFunds : { balance : Nat };
    #AmountTooLow : { min_withdrawal_amount : Nat };
    #AlreadyProcessing;
  };

  public type RetrieveEthRequest = {
    address : Text;
    amount : Nat;
    created_at : ?Nat64;
  };

  // ckETH Minter Actor Interface
  public type CKETH_MINTER = actor {
    get_eth_address : (?Principal) -> async { address : Text };
    update_balance : (Principal) -> async Result.Result<MintTx, MinterError>;
    retrieve_eth : (RetrieveEthRequest) -> async Result.Result<BlockIndex, MinterError>;
    get_minter_info : () -> async {
      minter_id : ?Principal;
      ledger_id : Principal;
      kyt_principal : ?Principal;
      kyt_fee : ?Nat;
    };
  };

  // Canister IDs
  // Mainnet:
  // Ledger: ss2fx-dyaaa-aaaar-qacoq-cai
  // Minter: s5l3k-xiaaa-aaaar-qacoa-cai
  // Testnet:
  // Ledger: (to be configured)
  // Minter: (to be configured)

  /// Create ckETH ledger actor from principal
  public func createLedgerActor(ledgerId : Principal) : CKETH_LEDGER {
    actor(Principal.toText(ledgerId)) : CKETH_LEDGER
  };

  /// Create ckETH minter actor from principal
  public func createMinterActor(minterId : Principal) : CKETH_MINTER {
    actor(Principal.toText(minterId)) : CKETH_MINTER
  };

  /// Get ckETH balance for an account
  public func getBalance(
    ledger : CKETH_LEDGER,
    account : Account
  ) : async Result<Nat, Text> {
    try {
      let balance = await ledger.icrc1_balance_of(account);
      #ok(balance)
    } catch (_) {
      #err("Failed to get ckETH balance. Network error or canister unavailable.")
    }
  };

  /// Transfer ckETH
  public func transfer(
    ledger : CKETH_LEDGER,
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
      #err("Failed to transfer ckETH")
    }
  };

  /// Get Ethereum address for ckETH deposit
  public func getETHAddress(
    minter : CKETH_MINTER,
    subaccount : ?Principal
  ) : async Result<Text, Text> {
    try {
      let response = await minter.get_eth_address(subaccount);
      #ok(response.address)
    } catch (_) {
      #err("Failed to get ETH address")
    }
  };

  /// Update ckETH balance (check for new deposits)
  public func updateBalance(
    minter : CKETH_MINTER,
    owner : Principal
  ) : async Result<MintTx, Text> {
    try {
      let result = await minter.update_balance(owner);
      switch result {
        case (#ok(mintTx)) #ok(mintTx);
        case (#err(err)) {
          let errorMsg = switch err {
            case (#TemporarilyUnavailable({ error_message; error_code = _ })) {
              "Temporarily unavailable: " # error_message # ". Please retry."
            };
            case (#MalformedAddress) "Malformed Ethereum address";
            case (#InsufficientFunds({ balance })) "Insufficient funds. Balance: " # Nat.toText(balance);
            case (#AmountTooLow({ min_withdrawal_amount })) "Amount too low. Min: " # Nat.toText(min_withdrawal_amount);
            case (#AlreadyProcessing) "Withdrawal already processing";
          };
          #err(errorMsg)
        }
      }
    } catch (_) {
      #err("Failed to update ckETH balance. Network error or canister unavailable.")
    }
  };

  /// Retrieve ckETH as ETH (withdraw)
  public func retrieveETH(
    minter : CKETH_MINTER,
    address : Text,
    amount : Nat,
    created_at : ?Nat64
  ) : async Result<BlockIndex, Text> {
    try {
      let result = await minter.retrieve_eth({
        address;
        amount;
        created_at;
      });
      switch result {
        case (#ok(blockIndex)) #ok(blockIndex);
        case (#err(err)) {
          let errorMsg = switch err {
            case (#TemporarilyUnavailable({ error_message; error_code = _ })) {
              "Temporarily unavailable: " # error_message # ". Please retry."
            };
            case (#MalformedAddress) "Malformed Ethereum address";
            case (#InsufficientFunds({ balance })) "Insufficient funds. Balance: " # Nat.toText(balance);
            case (#AmountTooLow({ min_withdrawal_amount })) "Amount too low. Min: " # Nat.toText(min_withdrawal_amount);
            case (#AlreadyProcessing) "Withdrawal already processing";
          };
          #err(errorMsg)
        }
      }
    } catch (_) {
      #err("Failed to retrieve ETH. Network error or canister unavailable.")
    }
  };
};

