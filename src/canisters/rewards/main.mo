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
import Types "./Types";
import PilotLedger "./PilotLedger";
import RateLimiter "../shared/RateLimiter";
import InputValidation "../shared/InputValidation";

persistent actor RewardsCanister {
  type Store = Types.Store;
  type StoreId = Types.StoreId;
  type AddStoreRequest = Types.AddStoreRequest;
  type PurchaseRecord = Types.PurchaseRecord;
  type PurchaseReceipt = Types.PurchaseReceipt;
  type BitcoinTx = Types.BitcoinTx;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // State
  private transient var stores : HashMap.HashMap<StoreId, Store> = HashMap.HashMap(0, func(a : StoreId, b : StoreId) : Bool { a == b }, func(a : StoreId) : Hash.Hash {
    // Bespoke hash function for Nat32 that considers all bits
    // Uses multiplicative hash: hash = (value * prime) mod 2^32
    let n : Nat = Nat32.toNat(a);
    let prime : Nat = 2654435761; // 32-bit prime multiplier
    let hashValue = (n * prime) % 4294967296; // mod 2^32
    Nat32.fromNat(hashValue) // Hash.Hash is Nat32, so convert using Nat32.fromNat
  });
  private transient var userRewards : HashMap.HashMap<Principal, Nat64> = HashMap.HashMap(0, Principal.equal, Principal.hash);
  private transient var purchases : Buffer.Buffer<PurchaseRecord> = Buffer.Buffer(100);
  private transient var nextStoreId : StoreId = 1;
  
  // Rune token state
  private transient var storeRuneTokens : HashMap.HashMap<StoreId, { runeName : Text; runeId : ?Text; runeReward : Float }> = HashMap.HashMap(0, func(a : StoreId, b : StoreId) : Bool { a == b }, func(a : StoreId) : Hash.Hash {
    let n : Nat = Nat32.toNat(a);
    let prime : Nat = 2654435761;
    let hashValue = (n * prime) % 4294967296;
    Nat32.fromNat(hashValue)
  });
  private transient var userRuneTokenRewards : HashMap.HashMap<Principal, HashMap.HashMap<StoreId, Nat64>> = HashMap.HashMap(0, Principal.equal, Principal.hash);

  private var adminPrincipals : [Principal] = [];

  private var pilotVerifier : ?Principal = null;
  private var pilotLedger : PilotLedger.State = PilotLedger.empty;

  public shared (msg) func setPilotVerifier(verifier : ?Principal) : async Result<(), Text> {
    if (Principal.isAnonymous(msg.caller) or not Principal.isController(msg.caller)) {
      return #err("Controller required")
    };
    switch (verifier) {
      case (?id) { if (Principal.isAnonymous(id)) { return #err("Anonymous verifier rejected") } };
      case null {}
    };
    pilotVerifier := verifier;
    #ok(())
  };

  public shared (msg) func recordPilotOrder(event : PilotLedger.Event) : async Result<PilotLedger.Outcome, Text> {
    if (Principal.isAnonymous(msg.caller) or pilotVerifier != ?msg.caller) { return #err("Verifier required") };
    switch (PilotLedger.record(pilotLedger, event, msg.caller)) {
      case (#err(reason)) #err(reason);
      case (#ok((next, outcome))) { pilotLedger := next; #ok(outcome) }
    }
  };

  public shared query (msg) func getMyPilotUnits() : async Nat {
    PilotLedger.balance(pilotLedger, msg.caller)
  };

  public shared query (msg) func getPilotEntry(id : Text) : async ?PilotLedger.Entry {
    if (isAdmin(msg.caller)) { PilotLedger.entry(pilotLedger, id) } else { null }
  };

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
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(request.name, 1, ?100)) {
      return #err("Invalid store name")
    };
    if (not InputValidation.validateText(request.logo, 0, ?500)) {
      return #err("Invalid logo URL")
    };
    switch (request.url) {
      case (null) {
        return #err("Store URL is required")
      };
      case (?url) {
        if (not InputValidation.validateText(url, 1, ?500)) {
          return #err("Invalid store URL")
        }
      }
    };
    if (request.reward < 0.0 or request.reward > 100.0) {
      return #err("Reward percentage must be between 0 and 100")
    };
    if (request.runeReward < 0.0 or request.runeReward > 100.0) {
      return #err("Rune reward percentage must be between 0 and 100")
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
      runeReward = request.runeReward;
      runeName = null;
      runeId = null;
    };

    stores.put(storeId, store);
    
    // Initialize rune token tracking (rune name will be generated lazily)
    storeRuneTokens.put(storeId, {
      runeName = ""; // Will be generated when first needed
      runeId = null;
      runeReward = request.runeReward;
    });
    
    #ok(storeId)
  };

  public func trackPurchase(_storeId : StoreId, _amount : Nat64) : async Result<PurchaseReceipt, Text> {
    #err("Self-reported purchases cannot earn rewards")
  };

  /// Get user's total rewards
  public shared query (msg) func getUserRewards(userId : Principal) : async Nat64 {
    // Input validation
    if (not InputValidation.validatePrincipal(userId) or (msg.caller != userId and not isAdmin(msg.caller))) {
      return 0
    };
    Option.get<Nat64>(userRewards.get(userId), 0)
  };

  /// Get user's rune token rewards per store
  public shared query (msg) func getUserRuneTokenRewards(userId : Principal) : async [(StoreId, Nat64)] {
    // Input validation
    if (not InputValidation.validatePrincipal(userId) or (msg.caller != userId and not isAdmin(msg.caller))) {
      return []
    };
    let userRuneRewardsOpt = userRuneTokenRewards.get(userId);
    switch userRuneRewardsOpt {
      case null [];
      case (?userRuneRewards) {
        var result = Buffer.Buffer<(StoreId, Nat64)>(userRuneRewards.size());
        for ((storeId, amount) in userRuneRewards.entries()) {
          result.add((storeId, amount))
        };
        Buffer.toArray(result)
      }
    }
  };

  /// Get store rune information
  public query func getStoreRuneInfo(storeId : StoreId) : async ?{ runeName : Text; runeId : ?Text; runeReward : Float } {
    // Input validation
    if (storeId == 0) {
      return null
    };
    storeRuneTokens.get(storeId)
  };

  // Legacy client methods stay callable while verified earning and payouts are offline.
  public func getUserRewardAddress(_userId : Principal) : async Result<Text, Text> {
    #err("Reward addresses are disabled")
  };

  public func claimRewards() : async Result<BitcoinTx, Text> {
    #err("Reward payouts are disabled")
  };

  public func getCanisterRewardAddress() : async Result<Text, Text> {
    #err("Reward addresses are disabled")
  };

  public func getCanisterTaprootAddress() : async Result<Text, Text> {
    #err("Reward addresses are disabled")
  };

  /// Get purchase history for a user
  public shared query (msg) func getUserPurchases(userId : Principal) : async [PurchaseRecord] {
    // Input validation
    if (not InputValidation.validatePrincipal(userId) or (msg.caller != userId and not isAdmin(msg.caller))) {
      return []
    };
    Array.filter<PurchaseRecord>(
      Buffer.toArray(purchases),
      func(p) { Principal.equal(p.userId, userId) }
    )
  };

  /// Get all purchases (admin only)
  public shared query (msg) func getAllPurchases() : async [PurchaseRecord] {
    if (isAdmin(msg.caller)) { Buffer.toArray(purchases) } else { [] }
  };

  private func isAdmin(principal : Principal) : Bool {
    not Principal.isAnonymous(principal) and
      (Principal.isController(principal) or Array.find<Principal>(adminPrincipals, func(p) { p == principal }) != null)
  };

  public shared (msg) func addAdmin(newAdmin : Principal) : async Result<(), Text> {
    if (Principal.isAnonymous(msg.caller) or not Principal.isController(msg.caller)) {
      return #err("Controller required")
    };
    if (Principal.isAnonymous(newAdmin)) { return #err("Invalid admin principal") };
    if (Array.find<Principal>(adminPrincipals, func(p) { p == newAdmin }) == null) {
      adminPrincipals := Array.append(adminPrincipals, [newAdmin])
    };
    #ok(())
  };

  public shared (msg) func removeAdmin(adminToRemove : Principal) : async Result<(), Text> {
    if (Principal.isAnonymous(msg.caller) or not Principal.isController(msg.caller)) {
      return #err("Controller required")
    };
    adminPrincipals := Array.filter<Principal>(adminPrincipals, func(p) { p != adminToRemove });
    #ok(())
  };

  public query func isAdminPrincipal(principal : Principal) : async Bool { isAdmin(principal) };

  public func checkAmazonSales() : async Text { "Error: Affiliate verification is disabled" };

  public func payUserReward(_user : Principal, _amountSats : Nat) : async Text {
    "Error: Reward payouts are disabled"
  };
};
