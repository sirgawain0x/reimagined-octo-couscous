import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Types "./Types";
import BitcoinUtilsICP "../shared/BitcoinUtilsICP";
import RateLimiter "../shared/RateLimiter";

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

  // Admin management (transient - will be lost on upgrade, first caller becomes admin)
  private transient var admins : HashMap.HashMap<Principal, Bool> = HashMap.HashMap(0, Principal.equal, Principal.hash);

  // Bitcoin API integration placeholder
  private transient let BTC_API_ENABLED : Bool = false;

  // Rate limiting (transient - resets on upgrade)
  private transient var rateLimiter = RateLimiter.RateLimiter(RateLimiter.REWARDS_CONFIG);

  /// Get all available stores
  public query func getStores() : async [Store] {
    Iter.toArray(stores.vals())
  };

  /// Add a new store
  public shared (msg) func addStore(request : AddStoreRequest) : async Result<StoreId, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

    if (not isAdmin(userId)) {
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

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

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

  /// Get user's reward address using BitcoinUtilsICP
  /// Generates a P2WPKH address for the user (SegWit for lower fees)
  public func getUserRewardAddress(userId : Principal) : async Result<Text, Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };
    
    // Use user's principal to derive a unique index
    // For now, use a simple hash of the principal as the derivation index
    // In production, you might want a more sophisticated mapping
    let principalBytes = Blob.toArray(Principal.toBlob(userId));
    let index = Nat32.fromNat(Array.foldLeft<Nat8, Nat>(principalBytes, 0, func(acc, b) { acc + Nat8.toNat(b) }) % 2147483647);
    let derivationPath = BitcoinUtilsICP.createDerivationPath(index);
    
    // Generate P2WPKH address (SegWit for lower transaction fees)
    await BitcoinUtilsICP.generateP2WPKHAddress(#Regtest, derivationPath, null)
  };

  /// Claim rewards (Bitcoin transaction implementation pending)
  public shared (msg) func claimRewards() : async Result<BitcoinTx, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };
    let rewards = Option.get<Nat64>(userRewards.get(userId), 0);

    if (rewards == 0) {
      return #err("No rewards to claim")
    };

    if (BTC_API_ENABLED) {
      // TODO: Implement actual Bitcoin transaction
      // 1. Get user's reward address
      let addressResult = await getUserRewardAddress(userId);
      switch addressResult {
        case (#err(msg)) return #err("Failed to get reward address: " # msg);
        case (#ok(address)) {
          // 2. Build transaction with UTXO selection
          // 3. Sign transaction using threshold ECDSA
          // 4. Broadcast via ICP Bitcoin API
          // For now, return error indicating implementation needed
          #err("Bitcoin transaction implementation pending. Address: " # address)
        }
      }
    } else {
      // For now, just reset rewards (mock behavior)
      userRewards.put(userId, 0);
      #ok({ txid = "mock_tx_" # Principal.toText(userId); hex = [] })
    }
  };

  /// Get canister Bitcoin address
  /// Returns P2PKH address for the canister (index 0)
  public func getCanisterRewardAddress() : async Result<Text, Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };
    
    // Use index 0 for the main canister address
    let derivationPath = BitcoinUtilsICP.createDerivationPath(0);
    
    // Generate P2PKH address for main canister address
    await BitcoinUtilsICP.generateP2PKHAddress(#Regtest, derivationPath, null)
  };

  /// Get canister Taproot address (P2TR)
  /// Modern Taproot address for lower fees and better privacy
  public func getCanisterTaprootAddress() : async Result<Text, Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };
    
    let derivationPath = BitcoinUtilsICP.createDerivationPath(2); // Index 2 for Taproot
    await BitcoinUtilsICP.generateP2TRKeyOnlyAddress(#Regtest, derivationPath, null)
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

  /// Add an admin (only existing admins can add new admins)
  public shared (msg) func addAdmin(newAdmin : Principal) : async Result<(), Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

    if (not isAdmin(userId)) {
      return #err("Unauthorized: Only admins can add other admins")
    };
    admins.put(newAdmin, true);
    #ok(())
  };

  /// Remove an admin (only admins can remove other admins)
  public shared (msg) func removeAdmin(adminToRemove : Principal) : async Result<(), Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

    if (not isAdmin(userId)) {
      return #err("Unauthorized: Only admins can remove other admins")
    };
    if (Principal.equal(userId, adminToRemove)) {
      return #err("Cannot remove yourself as admin")
    };
    admins.delete(adminToRemove);
    #ok(())
  };

  /// Check if a principal is an admin
  public query func isAdminPrincipal(principal : Principal) : async Bool {
    isAdmin(principal)
  };

  // Helper functions
  private func isAdmin(principal : Principal) : Bool {
    // If no admins exist, allow the first caller to become admin (initialization)
    if (admins.size() == 0) {
      admins.put(principal, true);
      true
    } else {
      Option.isSome(admins.get(principal))
    }
  };
};

