// ckBTC Integration Module
// Provides interfaces and utilities for interacting with ckBTC ledger and minter
// ckBTC is Chain-Key Bitcoin, an ICRC-2 token on ICP

import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

module CKBTC {
  public type Result<Ok, Err> = Result.Result<Ok, Err>;
  // ICRC-2 Standard Types
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

  // ckBTC Ledger Actor Interface (ICRC-2)
  public type CKBTC_LEDGER = actor {
    icrc1_transfer : (TransferArgs) -> async Result.Result<TxIndex, TransferError>;
    icrc1_balance_of : (Account) -> async Nat;
    icrc1_decimals : () -> async Nat8;
    icrc1_symbol : () -> async Text;
    icrc1_name : () -> async Text;
    icrc1_fee : () -> async Nat;
    icrc1_metadata : () -> async [(Text, { #Nat : Nat; #Int : Int; #Text : Text; #Blob : Blob })];
  };

  // ckBTC Minter Types
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

  public type RetrieveBtcRequest = {
    address : Text;
    amount : Nat;
    created_at : ?Nat64;
  };

  // ckBTC Minter Actor Interface
  public type CKBTC_MINTER = actor {
    get_btc_address : (?Principal) -> async { address : Text };
    update_balance : (Principal) -> async Result.Result<MintTx, MinterError>;
    retrieve_btc : (RetrieveBtcRequest) -> async Result.Result<BlockIndex, MinterError>;
    get_minter_info : () -> async {
      minter_id : ?Principal;
      ledger_id : Principal;
      kyt_principal : ?Principal;
      kyt_fee : ?Nat;
    };
  };

  // Canister IDs (will be configured via environment)
  // Mainnet:
  // Ledger: mxzaz-hqaaa-aaaah-aaada-cai
  // Minter: mqygn-kiaaa-aaaah-aaaqaa-cai
  // Testnet:
  // Ledger: (to be configured)
  // Minter: (to be configured)

  /// Create ckBTC ledger actor from principal
  public func createLedgerActor(ledgerId : Principal) : CKBTC_LEDGER {
    actor(Principal.toText(ledgerId)) : CKBTC_LEDGER
  };

  /// Create ckBTC minter actor from principal
  public func createMinterActor(minterId : Principal) : CKBTC_MINTER {
    actor(Principal.toText(minterId)) : CKBTC_MINTER
  };

  /// Get ckBTC balance for an account
  public func getBalance(
    ledger : CKBTC_LEDGER,
    account : Account
  ) : async Result<Nat, Text> {
    try {
      let balance = await ledger.icrc1_balance_of(account);
      #ok(balance)
    } catch (_) {
      #err("Failed to get ckBTC balance")
    }
  };

  /// Transfer ckBTC
  public func transfer(
    ledger : CKBTC_LEDGER,
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
      #err("Failed to transfer ckBTC")
    }
  };

  /// Get Bitcoin address for ckBTC deposit
  public func getBTCAddress(
    minter : CKBTC_MINTER,
    subaccount : ?Principal
  ) : async Result<Text, Text> {
    try {
      let response = await minter.get_btc_address(subaccount);
      #ok(response.address)
    } catch (_) {
      #err("Failed to get BTC address")
    }
  };

  /// Update ckBTC balance (check for new deposits)
  public func updateBalance(
    minter : CKBTC_MINTER,
    owner : Principal
  ) : async Result<MintTx, Text> {
    try {
      let result = await minter.update_balance(owner);
      switch result {
        case (#ok(mintTx)) #ok(mintTx);
        case (#err(err)) {
          let errorMsg = switch err {
            case (#TemporarilyUnavailable({ error_message; error_code = _ })) "Temporarily unavailable: " # error_message;
            case (#MalformedAddress) "Malformed Bitcoin address";
            case (#InsufficientFunds({ balance })) "Insufficient funds. Balance: " # Nat.toText(balance);
            case (#AmountTooLow({ min_withdrawal_amount })) "Amount too low. Min: " # Nat.toText(min_withdrawal_amount);
            case (#AlreadyProcessing) "Withdrawal already processing";
          };
          #err(errorMsg)
        }
      }
    } catch (_) {
      #err("Failed to update ckBTC balance")
    }
  };

  /// Retrieve ckBTC as BTC (withdraw)
  public func retrieveBTC(
    minter : CKBTC_MINTER,
    address : Text,
    amount : Nat,
    created_at : ?Nat64
  ) : async Result<BlockIndex, Text> {
    try {
      let result = await minter.retrieve_btc({
        address;
        amount;
        created_at;
      });
      switch result {
        case (#ok(blockIndex)) #ok(blockIndex);
        case (#err(err)) {
          let errorMsg = switch err {
            case (#TemporarilyUnavailable({ error_message; error_code = _ })) "Temporarily unavailable: " # error_message;
            case (#MalformedAddress) "Malformed Bitcoin address";
            case (#InsufficientFunds({ balance })) "Insufficient funds. Balance: " # Nat.toText(balance);
            case (#AmountTooLow({ min_withdrawal_amount })) "Amount too low. Min: " # Nat.toText(min_withdrawal_amount);
            case (#AlreadyProcessing) "Withdrawal already processing";
          };
          #err(errorMsg)
        }
      }
    } catch (_) {
      #err("Failed to retrieve BTC")
    }
  };
};

