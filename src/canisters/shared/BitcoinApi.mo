// Bitcoin API Wrapper Module
// Integrates with ICP Bitcoin API via management canister
// Supports regtest, testnet, and mainnet networks

import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";

module BitcoinApi {
  // Type aliases
  public type Satoshi = Nat64;
  public type MillisatoshiPerVByte = Nat64;
  public type BitcoinAddress = Text;
  public type BlockHash = [Nat8];
  public type Page = [Nat8];

  // Network types
  public type Network = {
    #Mainnet;
    #Testnet;
    #Regtest;
  };

  // UTXO types
  public type OutPoint = {
    txid : Blob;
    vout : Nat32;
  };

  public type Utxo = {
    outpoint : OutPoint;
    value : Satoshi;
    height : Nat32;
  };

  public type UtxosFilter = {
    #MinConfirmations : Nat32;
    #Page : Page;
  };

  public type GetUtxosResponse = {
    utxos : [Utxo];
    tip_block_hash : BlockHash;
    tip_height : Nat32;
    next_page : ?Page;
  };

  // Request/Response types
  public type GetBalanceRequest = {
    address : BitcoinAddress;
    network : Network;
    min_confirmations : ?Nat32;
  };

  public type GetUtxosRequest = {
    address : BitcoinAddress;
    network : Network;
    filter : ?UtxosFilter;
  };

  public type GetCurrentFeePercentilesRequest = {
    network : Network;
  };

  public type SendTransactionRequest = {
    transaction : [Nat8];
    network : Network;
  };

  // Cycle costs for Bitcoin API calls
  // These are approximate costs - actual costs may vary
  public let GET_BALANCE_COST_CYCLES : Nat = 100_000_000;
  public let GET_UTXOS_COST_CYCLES : Nat = 10_000_000_000;
  public let GET_CURRENT_FEE_PERCENTILES_COST_CYCLES : Nat = 100_000_000;
  public let SEND_TRANSACTION_BASE_COST_CYCLES : Nat = 5_000_000_000;
  public let SEND_TRANSACTION_COST_CYCLES_PER_BYTE : Nat = 20_000_000;

  // Management canister actor interface
  type ManagementCanisterActor = actor {
    bitcoin_get_balance : GetBalanceRequest -> async Satoshi;
    bitcoin_get_utxos : GetUtxosRequest -> async GetUtxosResponse;
    bitcoin_get_current_fee_percentiles : GetCurrentFeePercentilesRequest -> async [MillisatoshiPerVByte];
    bitcoin_send_transaction : SendTransactionRequest -> async ();
  };

  // Management canister (aaaaa-aa)
  let management_canister_actor : ManagementCanisterActor = actor ("aaaaa-aa");

  /// Returns the balance of the given Bitcoin address in satoshis.
  /// 
  /// Relies on the `bitcoin_get_balance` endpoint.
  /// See https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-bitcoin_get_balance
  public func get_balance(
    network : Network,
    address : BitcoinAddress,
    min_confirmations : ?Nat32
  ) : async Result.Result<Satoshi, Text> {
    try {
      let balance = await (with cycles = GET_BALANCE_COST_CYCLES) management_canister_actor.bitcoin_get_balance({
        address;
        network;
        min_confirmations;
      });
      #ok(balance)
    } catch (_) {
      #err("Failed to get balance")
    }
  };

  /// Returns the UTXOs of the given Bitcoin address.
  /// 
  /// NOTE: Relies on the `bitcoin_get_utxos` endpoint.
  /// See https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-bitcoin_get_utxos
  public func get_utxos(
    network : Network,
    address : BitcoinAddress,
    filter : ?UtxosFilter
  ) : async Result.Result<GetUtxosResponse, Text> {
    try {
      let response = await (with cycles = GET_UTXOS_COST_CYCLES) management_canister_actor.bitcoin_get_utxos({
        address;
        network;
        filter;
      });
      #ok(response)
    } catch (_) {
      #err("Failed to get UTXOs")
    }
  };

  /// Returns the 100 fee percentiles measured in millisatoshi/vbyte.
  /// Percentiles are computed from the last 10,000 transactions (if available).
  /// 
  /// Relies on the `bitcoin_get_current_fee_percentiles` endpoint.
  /// See https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-bitcoin_get_current_fee_percentiles
  public func get_current_fee_percentiles(
    network : Network
  ) : async Result.Result<[MillisatoshiPerVByte], Text> {
    try {
      let percentiles = await (with cycles = GET_CURRENT_FEE_PERCENTILES_COST_CYCLES) management_canister_actor.bitcoin_get_current_fee_percentiles({
        network;
      });
      #ok(percentiles)
    } catch (_) {
      #err("Failed to get fee percentiles")
    }
  };

  /// Sends a (signed) transaction to the Bitcoin network.
  /// 
  /// Relies on the `bitcoin_send_transaction` endpoint.
  /// See https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-bitcoin_send_transaction
  public func send_transaction(
    network : Network,
    transaction : [Nat8]
  ) : async Result.Result<(), Text> {
    let transaction_fee = SEND_TRANSACTION_BASE_COST_CYCLES + transaction.size() * SEND_TRANSACTION_COST_CYCLES_PER_BYTE;
    
    try {
      await (with cycles = transaction_fee) management_canister_actor.bitcoin_send_transaction({
        network;
        transaction;
      });
      #ok(())
    } catch (_) {
      #err("Failed to send transaction")
    }
  };

  /// Get median fee per vbyte (50th percentile) in satoshis per byte
  /// Converts from millisatoshi/vbyte to satoshi/byte
  public func get_median_fee_per_byte(
    network : Network
  ) : async Result.Result<Nat64, Text> {
    switch (await get_current_fee_percentiles(network)) {
      case (#err(msg)) #err(msg);
      case (#ok(percentiles)) {
        if (percentiles.size() > 50) {
          // 50th percentile (median) in millisatoshi/vbyte
          let medianMillisatoshi = percentiles[50];
          // Convert to satoshi/byte (divide by 1000)
          let satoshiPerByte = medianMillisatoshi / 1000;
          #ok(satoshiPerByte)
        } else {
          // Fallback: use a default fee if percentiles not available
          // For regtest, use a low default fee
          let defaultFee = switch network {
            case (#Regtest) 1 : Nat64; // 1 satoshi per byte for regtest
            case (#Testnet) 10 : Nat64; // 10 satoshis per byte for testnet
            case (#Mainnet) 50 : Nat64; // 50 satoshis per byte for mainnet
          };
          #ok(defaultFee)
        }
      }
    }
  };
};

