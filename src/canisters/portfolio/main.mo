import Array "mo:base/Array";
import Char "mo:base/Char";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Types "../shared/Types";
import RateLimiter "../shared/RateLimiter";
import InputValidation "../shared/InputValidation";

persistent actor PortfolioCanister {
  type PortfolioAsset = Types.PortfolioAsset;
  type Portfolio = Types.Portfolio;
  type Result<Ok, Err> = Result.Result<Ok, Err>;
  type DepositInfo = Types.DepositInfo;

  // Actor references to other canisters (set via init or setter methods)
  private var rewardsCanisterId : ?Principal = null;
  private var lendingCanisterId : ?Principal = null;

  // Rate limiting (transient - resets on upgrade)
  private transient var rateLimiter = RateLimiter.RateLimiter(RateLimiter.DEFAULT_CONFIG);

  // Helper functions for actor creation
  private func getRewardsCanister() : ?(actor {
    getUserRewards : (Principal) -> async Nat64;
  }) {
    switch rewardsCanisterId {
      case null null;
      case (?id) {
        let actorRef = actor (Principal.toText(id)) : actor {
          getUserRewards : (Principal) -> async Nat64;
        };
        ?actorRef
      }
    }
  };

  private func getLendingCanister() : ?(actor {
    getUserDeposits : (Principal) -> async [DepositInfo];
    getUserBorrows : (Principal) -> async [Types.BorrowInfo];
  }) {
    switch lendingCanisterId {
      case null null;
      case (?id) {
        let actorRef = actor (Principal.toText(id)) : actor {
          getUserDeposits : (Principal) -> async [DepositInfo];
          getUserBorrows : (Principal) -> async [Types.BorrowInfo];
        };
        ?actorRef
      }
    }
  };

  // Price data (in production, fetch from price oracle)
  private let prices : [(Text, Float)] = [
    ("BTC", 60000.0),
    ("ETH", 3000.0),
    ("SOL", 45.0),
  ];

  /// Set rewards canister ID (for configuration)
  public shared (msg) func setRewardsCanister(canisterId : Principal) : async Result<(), Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validatePrincipal(canisterId)) {
      return #err("Invalid canister principal")
    };
    if (Principal.isAnonymous(canisterId)) {
      return #err("Cannot set anonymous principal as canister ID")
    };

    rewardsCanisterId := ?canisterId;
    #ok(())
  };

  /// Set lending canister ID (for configuration)
  public shared (msg) func setLendingCanister(canisterId : Principal) : async Result<(), Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validatePrincipal(canisterId)) {
      return #err("Invalid canister principal")
    };
    if (Principal.isAnonymous(canisterId)) {
      return #err("Cannot set anonymous principal as canister ID")
    };

    lendingCanisterId := ?canisterId;
    #ok(())
  };

  /// Get user's complete portfolio
  public shared (msg) func getPortfolio(userId : Principal) : async Portfolio {
    let caller = msg.caller;
    
    // Security: Only allow users to query their own portfolio
    if (not Principal.equal(caller, userId)) {
      return {
        totalValue = 0.0;
        totalRewards = 0;
        totalLended = 0.0;
        totalBorrowed = 0.0;
        assets = [];
      }
    };
    
    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      // Return empty portfolio for invalid principal
      return {
        totalValue = 0.0;
        totalRewards = 0;
        totalLended = 0.0;
        totalBorrowed = 0.0;
        assets = [];
      }
    };
    
    var totalRewards : Nat64 = 0;
    var totalLended : Float = 0.0;
    var totalBorrowed : Float = 0.0;
    var assetBalances : HashMap.HashMap<Text, Nat64> = HashMap.HashMap(0, Text.equal, Text.hash);

    // Fetch rewards from rewards canister (if configured)
    let rewardsOpt = getRewardsCanister();
    switch (rewardsOpt) {
      case null {};
      case (?rewardsCanister) {
        // If canister call fails, continue with 0 rewards (graceful degradation)
        try {
          totalRewards := await rewardsCanister.getUserRewards(userId)
        } catch (_) {
          // Cross-canister call failed - continue with 0 rewards
          totalRewards := 0
        }
      }
    };

    // Fetch deposits from lending canister (if configured)
    let lendingOpt = getLendingCanister();
    switch (lendingOpt) {
      case null {};
      case (?lendingCanister) {
        // If canister call fails, continue with empty deposits (graceful degradation)
        try {
          let deposits = await lendingCanister.getUserDeposits(userId);
          for (deposit in deposits.vals()) {
            // Calculate total lended in USD
            let price = getPrice(deposit.asset);
            let amountFloat = Float.fromInt(Nat64.toNat(deposit.amount)) / 100_000_000.0; // Convert from 8 decimals
            totalLended := totalLended + amountFloat * price;

            // Aggregate asset balances
            let currentBalance = assetBalances.get(deposit.asset);
            let newBalance = Option.get<Nat64>(currentBalance, 0) + deposit.amount;
            assetBalances.put(deposit.asset, newBalance)
          }
        } catch (_) {
          // Cross-canister call failed - continue with empty deposits
        };

        // Fetch borrows from lending canister (if configured)
        try {
          let borrows = await lendingCanister.getUserBorrows(userId);
          for (borrow in borrows.vals()) {
            // Calculate total borrowed in USD
            // Normalize asset symbol to uppercase for price lookup (prices array uses uppercase)
            // Convert to uppercase using Text.map (handles all cases, not just hardcoded ones)
            let assetSymbol = Text.map(borrow.asset, func(c : Char) : Char {
              if (c >= 'a' and c <= 'z') {
                Char.fromNat32(Char.toNat32(c) - 32) // Convert to uppercase
              } else {
                c
              }
            });
            let price = getPrice(assetSymbol);
            
            // Log warning if asset price is unknown (validates that we're not silently ignoring borrows)
            if (not hasKnownPrice(assetSymbol) and assetSymbol != "") {
              let borrowedAmountFloat = Float.fromInt(Nat64.toNat(borrow.borrowedAmount)) / 100_000_000.0;
              Debug.print("[Portfolio] WARNING: Unknown asset price for borrow - asset: " # assetSymbol # ", original: " # borrow.asset # ", borrowedAmount: " # Nat64.toText(borrow.borrowedAmount) # " (" # Float.toText(borrowedAmountFloat) # "), will be calculated as $0.00");
            };
            
            let amountFloat = Float.fromInt(Nat64.toNat(borrow.borrowedAmount)) / 100_000_000.0; // Convert from 8 decimals
            totalBorrowed := totalBorrowed + amountFloat * price;
          }
        } catch (_) {
          // Cross-canister call failed - continue with 0 borrowed
        }
      }
    };

    // Build assets array
    let assets : [PortfolioAsset] = Array.map<(Text, Nat64), PortfolioAsset>(
      Iter.toArray(assetBalances.entries()),
      func((asset, amount)) : PortfolioAsset {
        let amountFloat = Float.fromInt(Nat64.toNat(amount)) / 100_000_000.0;
        let price = getPrice(asset);
        let value = amountFloat * price;
        {
          name = getAssetName(asset);
          symbol = asset;
          amount = amount;
          value = value;
        }
      }
    );

    // Calculate total value
    let assetsValue = Array.foldLeft<PortfolioAsset, Float>(assets, 0.0, func(acc, asset) { acc + asset.value });
    let rewardsValue = Float.fromInt(Nat64.toNat(totalRewards)) / 100_000_000.0 * getPrice("BTC");
    let totalValue = assetsValue + rewardsValue + totalLended - totalBorrowed;

    {
      totalValue = totalValue;
      totalRewards = totalRewards;
      totalLended = totalLended;
      totalBorrowed = totalBorrowed;
      assets = assets;
    }
  };

  /// Get balance for specific asset
  public shared (msg) func getBalance(userId : Principal, asset : Text) : async Nat64 {
    let caller = msg.caller;
    
    // Security: Only allow users to query their own balance
    if (not Principal.equal(caller, userId)) {
      return 0
    };
    
    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return 0
    };
    if (not InputValidation.validateText(asset, 1, ?10)) {
      return 0
    };
    
    let lendingOpt = getLendingCanister();
    switch (lendingOpt) {
      case null 0;
      case (?lendingCanister) {
        // If canister call fails, return 0 (graceful degradation)
        try {
          let deposits = await lendingCanister.getUserDeposits(userId);
          var balance : Nat64 = 0;
          for (deposit in deposits.vals()) {
            if (deposit.asset == asset) {
              balance := balance + deposit.amount
            }
          };
          balance
        } catch (_) {
          // Cross-canister call failed - return 0
          0
        }
      }
    }
  };

  /// Get total USD value of portfolio
  public shared (_msg) func getTotalValue(userId : Principal) : async Float {
    let portfolio = await getPortfolio(userId);
    portfolio.totalValue
  };

  // Helper functions
  private func getPrice(asset : Text) : Float {
    switch (Array.find<(Text, Float)>(prices, func((symbol, _)) { symbol == asset })) {
      case null 0.0;
      case (?(_, price)) price
    }
  };

  /// Check if asset has a known price
  private func hasKnownPrice(asset : Text) : Bool {
    switch (Array.find<(Text, Float)>(prices, func((symbol, _)) { symbol == asset })) {
      case null false;
      case (_) true
    }
  };

  private func getAssetName(symbol : Text) : Text {
    switch symbol {
      case "BTC" "Bitcoin";
      case "ETH" "Ethereum";
      case "SOL" "Solana";
      case _ symbol
    }
  };
};

