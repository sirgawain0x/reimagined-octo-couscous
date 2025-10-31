import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Types "./Types";

// Helper functions for equality and hashing (must be defined before use)
func depositIdEqual(a : Nat64, b : Nat64) : Bool { a == b };
func depositIdHash(a : Nat64) : Hash.Hash {
  // Bespoke hash function for Nat64 that considers all bits
  // Uses multiplicative hash: hash = (value * prime) mod 2^32
  let n : Nat = Nat64.toNat(a);
  let prime : Nat = 2654435761; // 32-bit prime multiplier
  let hashValue = (n * prime) % 4294967296; // mod 2^32
  Nat32.fromNat(hashValue) // Hash.Hash is just Nat32, so convert using Nat32.fromNat
};

persistent actor LendingCanister {
  type LendingAsset = Types.LendingAsset;
  type Deposit = Types.Deposit;
  type DepositInfo = Types.DepositInfo;
  type WithdrawalTx = Types.WithdrawalTx;
  type UtxoInfo = Types.UtxoInfo;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // State
  private transient var assets : HashMap.HashMap<Text, LendingAsset> = HashMap.HashMap(0, Text.equal, Text.hash);
  private transient var deposits : HashMap.HashMap<Nat64, Deposit> = HashMap.HashMap(0, depositIdEqual, depositIdHash);
  private transient var userDeposits : HashMap.HashMap<Principal, [Nat64]> = HashMap.HashMap(0, Principal.equal, Principal.hash);
  private var nextDepositId : Nat64 = 1;

  // Bitcoin custody state (placeholder)
  private transient var bitcoinUtxos : Buffer.Buffer<UtxoInfo> = Buffer.Buffer(100);
  private var totalBitcoinBalance : Nat64 = 0;

  // Bitcoin API integration placeholder
  private let BTC_API_ENABLED : Bool = false;

  /// Initialize with default lending assets
  public shared func init() : async () {
    let btcAsset : LendingAsset = {
      id = "btc";
      name = "Bitcoin";
      symbol = "BTC";
      apy = 4.2;
    };
    assets.put("btc", btcAsset);

    let ethAsset : LendingAsset = {
      id = "eth";
      name = "Ethereum";
      symbol = "ETH";
      apy = 5.1;
    };
    assets.put("eth", ethAsset);

    let solAsset : LendingAsset = {
      id = "sol";
      name = "Solana";
      symbol = "SOL";
      apy = 6.5;
    };
    assets.put("sol", solAsset);
  };

  /// Get all lending assets
  public query func getLendingAssets() : async [LendingAsset] {
    Iter.toArray(assets.vals())
  };

  /// Get current APY for an asset
  public query func getCurrentAPY(asset : Text) : async Float {
    switch (assets.get(asset)) {
      case (?asset) asset.apy;
      case null 0.0
    }
  };

  /// Get user's deposits
  public query func getUserDeposits(userId : Principal) : async [DepositInfo] {
    let depositIds = userDeposits.get(userId);
    switch depositIds {
      case null [];
      case (?ids) {
        Array.map<Nat64, DepositInfo>(
          ids,
          func(depositId) : DepositInfo {
            switch (deposits.get(depositId)) {
              case null {
                // This should never happen if deposits are valid, but handle gracefully
                { asset = ""; amount = 0; apy = 0.0 }
              };
              case (?deposit) {
                {
                  asset = deposit.asset;
                  amount = deposit.amount;
                  apy = deposit.apy;
                }
              }
            }
          }
        )
      }
    }
  };

  /// Deposit assets (for non-Bitcoin assets, placeholder)
  public shared (msg) func deposit(
    asset : Text,
    amount : Nat64
  ) : async Result<Nat64, Text> {
    let userId = msg.caller;

    // Verify asset exists
    switch (assets.get(asset)) {
      case null {
        #err("Asset not found")
      };
      case (?assetInfo) {
        if (amount == 0) {
          return #err("Amount must be greater than 0")
        };

        if (asset == "BTC" and BTC_API_ENABLED) {
          // TODO: Implement Bitcoin deposit validation
          // For now, just record the deposit
        };

        // Create deposit record
        let depositId = nextDepositId;
        nextDepositId += 1;

        let deposit : Deposit = {
          id = depositId;
          userId = userId;
          asset = asset;
          amount = amount;
          timestamp = Nat64.fromIntWrap(Time.now());
          apy = assetInfo.apy;
        };

        // Update state
        deposits.put(depositId, deposit);

        let existingDeposits = userDeposits.get(userId);
        let updatedDeposits = Array.append(Option.get<[Nat64]>(existingDeposits, []), [depositId]);
        userDeposits.put(userId, updatedDeposits);

        // Update Bitcoin balance if applicable
        if (asset == "BTC") {
          totalBitcoinBalance += amount
        };

        #ok(depositId)
      }
    }
  };

  /// Withdraw assets
  public shared (msg) func withdraw(
    asset : Text,
    amount : Nat64,
    _recipientAddress : Text
  ) : async Result<WithdrawalTx, Text> {
    let userId = msg.caller;

    if (amount == 0) {
      return #err("Amount must be greater than 0")
    };

    if (asset == "BTC" and BTC_API_ENABLED) {
      // TODO: Implement Bitcoin withdrawal
      // 1. Validate recipient address
      // 2. Build Bitcoin transaction
      // 3. Sign transaction
      // 4. Broadcast via ICP Bitcoin API
      return #err("Bitcoin withdrawal implementation pending")
    };

    // For now, simulate withdrawal
    let userDepositIds = userDeposits.get(userId);
    switch userDepositIds {
      case null {
        #err("User has no deposits")
      };
      case (?depositIds) {
        // Find matching deposit (simplified - in production, you'd select the right UTXOs)
        let depositIdOpt = Array.find<Nat64>(depositIds, func(id) {
          switch (deposits.get(id)) {
            case null false;
            case (?deposit) {
              deposit.asset == asset and deposit.amount == amount
            }
          }
        });

        switch depositIdOpt {
          case null {
            #err("Insufficient balance")
          };
          case (?depositId) {
            // Remove deposit
            deposits.delete(depositId);
            let filteredIds = Array.filter<Nat64>(depositIds, func(id) { id != depositId });
            userDeposits.put(userId, filteredIds);

            // Update Bitcoin balance
            if (asset == "BTC") {
              totalBitcoinBalance -= amount
            };

            #ok({ txid = "mock_tx_" # Principal.toText(userId); amount = amount })
          }
        }
      }
    }
  };

  /// Get Bitcoin custody balance
  public query func getBitcoinBalance() : async Nat64 {
    totalBitcoinBalance
  };

  /// Get UTXOs under custody (admin only)
  public query func getUtxos() : async [UtxoInfo] {
    Buffer.toArray(bitcoinUtxos)
  };

};

