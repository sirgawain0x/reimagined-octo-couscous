import Array "mo:base/Array";
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
  }) {
    switch lendingCanisterId {
      case null null;
      case (?id) {
        let actorRef = actor (Principal.toText(id)) : actor {
          getUserDeposits : (Principal) -> async [DepositInfo];
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
      return #err("Rate limit exceeded. Please try again later.")
    };

    rewardsCanisterId := ?canisterId;
    #ok(())
  };

  /// Set lending canister ID (for configuration)
  public shared (msg) func setLendingCanister(canisterId : Principal) : async Result<(), Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

    lendingCanisterId := ?canisterId;
    #ok(())
  };

  /// Get user's complete portfolio
  public func getPortfolio(userId : Principal) : async Portfolio {
    var totalRewards : Nat64 = 0;
    var totalLended : Float = 0.0;
    var assetBalances : HashMap.HashMap<Text, Nat64> = HashMap.HashMap(0, Text.equal, Text.hash);

    // Fetch rewards from rewards canister (if configured)
    let rewardsOpt = getRewardsCanister();
    switch (rewardsOpt) {
      case null {};
      case (?rewardsCanister) {
        // If canister call fails, it will propagate - caller should handle
        totalRewards := await rewardsCanister.getUserRewards(userId)
      }
    };

    // Fetch deposits from lending canister (if configured)
    let lendingOpt = getLendingCanister();
    switch (lendingOpt) {
      case null {};
      case (?lendingCanister) {
        // If canister call fails, it will propagate - caller should handle
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
    let totalValue = assetsValue + rewardsValue + totalLended;

    {
      totalValue = totalValue;
      totalRewards = totalRewards;
      totalLended = totalLended;
      assets = assets;
    }
  };

  /// Get balance for specific asset
  public func getBalance(userId : Principal, asset : Text) : async Nat64 {
    let lendingOpt = getLendingCanister();
    switch (lendingOpt) {
      case null 0;
      case (?lendingCanister) {
        // If canister call fails, it will propagate - caller should handle
        let deposits = await lendingCanister.getUserDeposits(userId);
        var balance : Nat64 = 0;
        for (deposit in deposits.vals()) {
          if (deposit.asset == asset) {
            balance := balance + deposit.amount
          }
        };
        balance
      }
    }
  };

  /// Get total USD value of portfolio
  public func getTotalValue(userId : Principal) : async Float {
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

  private func getAssetName(symbol : Text) : Text {
    switch symbol {
      case "BTC" "Bitcoin";
      case "ETH" "Ethereum";
      case "SOL" "Solana";
      case _ symbol
    }
  };
};

