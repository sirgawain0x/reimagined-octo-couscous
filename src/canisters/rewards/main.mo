import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Types "./Types";

// Helper functions for equality and hashing (must be defined before use)
func storeIdEqual(a : Types.StoreId, b : Types.StoreId) : Bool { a == b };
func storeIdHash(a : Types.StoreId) : Hash.Hash {
  // Bespoke hash function for Nat32 that considers all bits
  // Uses multiplicative hash: hash = (value * prime) mod 2^32
  let n : Nat = Nat32.toNat(a);
  let prime : Nat = 2654435761; // 32-bit prime multiplier
  let hashValue = (n * prime) % 4294967296; // mod 2^32
  Nat32.fromNat(hashValue) // Hash.Hash is Nat32, so convert using Nat32.fromNat
};

persistent actor RewardsCanister {
  type Store = Types.Store;
  type StoreId = Types.StoreId;
  type AddStoreRequest = Types.AddStoreRequest;
  type PurchaseRecord = Types.PurchaseRecord;
  type PurchaseReceipt = Types.PurchaseReceipt;
  type BitcoinTx = Types.BitcoinTx;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // State
  private transient var stores : HashMap.HashMap<StoreId, Store> = HashMap.HashMap(0, storeIdEqual, storeIdHash);
  private transient var userRewards : HashMap.HashMap<Principal, Nat64> = HashMap.HashMap(0, Principal.equal, Principal.hash);
  private transient var purchases : Buffer.Buffer<PurchaseRecord> = Buffer.Buffer(100);
  private transient var nextStoreId : StoreId = 1;
  private transient var nextPurchaseId : Nat64 = 1;

  // Bitcoin API integration placeholder
  private transient let BTC_API_ENABLED : Bool = false;

  /// Get all available stores
  public query func getStores() : async [Store] {
    Iter.toArray(stores.vals())
  };

  /// Add a new store
  public shared (msg) func addStore(request : AddStoreRequest) : async Result<StoreId, Text> {
    if (not isAdmin(msg.caller)) {
      return #err("Unauthorized: Only admins can add stores")
    };

    let storeId = nextStoreId;
    nextStoreId += 1;

    let store : Store = {
      id = storeId;
      name = request.name;
      reward = request.reward;
      logo = request.logo;
      url = request.url;
    };

    stores.put(storeId, store);
    #ok(storeId)
  };

  /// Track a purchase and calculate rewards
  public shared (msg) func trackPurchase(
    storeId : StoreId,
    amount : Nat64
  ) : async Result<PurchaseReceipt, Text> {
    let userId = msg.caller;

    // Verify store exists
    let storeOpt = stores.get(storeId);
    switch storeOpt {
      case null {
        return #err("Store not found")
      };
      case (?store) {
        // Calculate reward (store.reward is percentage)
        let rewardAmount = (amount * Nat64.fromIntWrap(Float.toInt(store.reward))) / 100;

        // Create purchase record
        let purchase : PurchaseRecord = {
          id = nextPurchaseId;
          userId = userId;
          storeId = storeId;
          amount = amount;
          reward = rewardAmount;
          timestamp = Nat64.fromIntWrap(Time.now());
          claimed = false;
        };

        // Update state
        purchases.add(purchase);
        nextPurchaseId += 1;

        // Update user rewards
        let currentRewards = userRewards.get(userId);
        let newRewards = Option.get<Nat64>(currentRewards, 0) + rewardAmount;
        userRewards.put(userId, newRewards);

        #ok({ purchaseId = purchase.id; rewardEarned = rewardAmount })
      }
    }
  };

  /// Get user's total rewards
  public query func getUserRewards(userId : Principal) : async Nat64 {
    Option.get<Nat64>(userRewards.get(userId), 0)
  };

  /// Get user's reward address (placeholder)
  public query func getUserRewardAddress(_userId : Principal) : async Result<Text, Text> {
    if (BTC_API_ENABLED) {
      // TODO: Implement actual Bitcoin address generation using BIP32 derivation
      #ok("bc1qplaceholderaddress")
    } else {
      #err("Bitcoin integration not enabled")
    }
  };

  /// Claim rewards (placeholder for Bitcoin transaction)
  public shared (msg) func claimRewards() : async Result<BitcoinTx, Text> {
    let userId = msg.caller;
    let rewards = Option.get<Nat64>(userRewards.get(userId), 0);

    if (rewards == 0) {
      return #err("No rewards to claim")
    };

    if (BTC_API_ENABLED) {
      // TODO: Implement actual Bitcoin transaction
      // 1. Get Bitcoin address from getUserRewardAddress
      // 2. Build transaction
      // 3. Sign transaction
      // 4. Broadcast via ICP Bitcoin API
      #err("Bitcoin transaction implementation pending")
    } else {
      // For now, just reset rewards (mock behavior)
      userRewards.put(userId, 0);
      #ok({ txid = "mock_tx_" # Principal.toText(userId); hex = [] })
    }
  };

  /// Get canister Bitcoin address (placeholder)
  public query func getCanisterRewardAddress() : async Text {
    "bc1qcanisteraddressplaceholder"
  };

  /// Get purchase history for a user
  public query func getUserPurchases(userId : Principal) : async [PurchaseRecord] {
    Array.filter<PurchaseRecord>(
      Buffer.toArray(purchases),
      func(p) { Principal.equal(p.userId, userId) }
    )
  };

  /// Get all purchases (admin only)
  public query func getAllPurchases() : async [PurchaseRecord] {
    Buffer.toArray(purchases)
  };

  // Helper functions
  private func isAdmin(_principal : Principal) : Bool {
    // TODO: Implement admin check
    // For now, allow all calls in development
    true
  };
};

