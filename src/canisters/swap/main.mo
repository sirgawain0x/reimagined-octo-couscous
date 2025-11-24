import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import _Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Types "./Types";
import RateLimiter "../shared/RateLimiter";
import SolRpcClient "../shared/SolRpcClient";
import SolanaUtils "../shared/SolanaUtils";
import CKBTC "../shared/CKBTC";
import CKETH "../shared/CKETH";
import ICPLedger "../shared/ICPLedger";
import InputValidation "../shared/InputValidation";
import Nat "mo:base/Nat";

persistent actor SwapCanister {
  type ChainKeyToken = Types.ChainKeyToken;
  type SwapPool = Types.SwapPool;
  type SwapRecord = Types.SwapRecord;
  type SwapQuote = Types.SwapQuote;
  type SwapResult = Types.SwapResult;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // Chain-Key Token Canister References
  // Mainnet:
  // ckBTC Ledger: mxzaz-hqaaa-aaaah-aaada-cai
  // ckBTC Minter: mqygn-kiaaa-aaaah-aaaqaa-cai
  // ckETH Ledger: ss2fx-dyaaa-aaaar-qacoq-cai
  // ckETH Minter: s5l3k-xiaaa-aaaar-qacoa-cai
  // ICP Ledger: ryjl3-tyaaa-aaaaa-aaaba-cai
  // Testnet:
  // ckBTC Ledger: n5wcd-faaaa-aaaar-qaaea-cai
  // ckBTC Minter: nfvlz-3qaaa-aaaar-qaanq-cai
  
  // Network configuration (should be set from environment or canister argument)
  // Set to true for testnet deployment, false for mainnet
  private let USE_TESTNET : Bool = false; // Set to true for testnet deployment
  
  // ckBTC canister ID strings
  private let CKBTC_LEDGER_ID_TEXT : Text = if (USE_TESTNET) {
    "n5wcd-faaaa-aaaar-qaaea-cai" // Testnet ledger
  } else {
    "mxzaz-hqaaa-aaaah-aaada-cai" // Mainnet ledger
  };
  private let CKBTC_MINTER_ID_TEXT : Text = if (USE_TESTNET) {
    "nfvlz-3qaaa-aaaar-qaanq-cai" // Testnet minter
  } else {
    "mqygn-kiaaa-aaaah-aaaqaa-cai" // Mainnet minter
  };
  
  // ckETH canister ID strings
  private let CKETH_LEDGER_ID_TEXT : Text = if (USE_TESTNET) {
    "" // Testnet ledger (to be configured)
  } else {
    "ss2fx-dyaaa-aaaar-qacoq-cai" // Mainnet ledger
  };
  private let CKETH_MINTER_ID_TEXT : Text = if (USE_TESTNET) {
    "" // Testnet minter (to be configured)
  } else {
    "s5l3k-xiaaa-aaaar-qacoa-cai" // Mainnet minter
  };
  
  // ICP ledger canister ID
  private let ICP_LEDGER_ID_TEXT : Text = if (USE_TESTNET) {
    "" // Testnet ledger (to be configured)
  } else {
    "ryjl3-tyaaa-aaaaa-aaaba-cai" // Mainnet ledger
  };
  
  // Lazy token actors - created on first use to avoid initialization errors on local network
  private var ckbtcLedgerOpt : ?CKBTC.CKBTC_LEDGER = null;
  private var ckbtcMinterOpt : ?CKBTC.CKBTC_MINTER = null;
  private var ckethLedgerOpt : ?CKETH.CKETH_LEDGER = null;
  private var ckethMinterOpt : ?CKETH.CKETH_MINTER = null;
  private var icpLedgerOpt : ?ICPLedger.ICP_LEDGER = null;
  
  // SOL balance tracking (in-memory, for swap operations)
  // In production, this would be persistent or use actual Solana RPC balances
  private transient var solBalances : HashMap.HashMap<Principal, Nat64> = HashMap.HashMap(0, Principal.equal, Principal.hash);
  
  // Helper to get or create ledger actor
  // Note: Principal.fromText should not fail with valid principal strings
  // Actor creation may fail on local network if canister doesn't exist, but that's handled at call time
  private func getCkbtcLedger() : ?CKBTC.CKBTC_LEDGER {
    switch ckbtcLedgerOpt {
      case null {
        let ledgerId = Principal.fromText(CKBTC_LEDGER_ID_TEXT);
        let ledger = CKBTC.createLedgerActor(ledgerId);
        ckbtcLedgerOpt := ?ledger;
        ?ledger
      };
      case (?ledger) ?ledger;
    }
  };
  
  // Helper to get or create minter actor
  private func getCkbtcMinter() : ?CKBTC.CKBTC_MINTER {
    switch ckbtcMinterOpt {
      case null {
        let minterId = Principal.fromText(CKBTC_MINTER_ID_TEXT);
        let minter = CKBTC.createMinterActor(minterId);
        ckbtcMinterOpt := ?minter;
        ?minter
      };
      case (?minter) ?minter;
    }
  };
  
  // Helper to get or create ckETH ledger actor
  private func getCkethLedger() : ?CKETH.CKETH_LEDGER {
    switch ckethLedgerOpt {
      case null {
        if (CKETH_LEDGER_ID_TEXT == "") return null;
        let ledgerId = Principal.fromText(CKETH_LEDGER_ID_TEXT);
        let ledger = CKETH.createLedgerActor(ledgerId);
        ckethLedgerOpt := ?ledger;
        ?ledger
      };
      case (?ledger) ?ledger;
    }
  };
  
  // Helper to get or create ckETH minter actor
  private func getCkethMinter() : ?CKETH.CKETH_MINTER {
    switch ckethMinterOpt {
      case null {
        if (CKETH_MINTER_ID_TEXT == "") return null;
        let minterId = Principal.fromText(CKETH_MINTER_ID_TEXT);
        let minter = CKETH.createMinterActor(minterId);
        ckethMinterOpt := ?minter;
        ?minter
      };
      case (?minter) ?minter;
    }
  };
  
  // Helper to get or create ICP ledger actor
  private func getIcpLedger() : ?ICPLedger.ICP_LEDGER {
    switch icpLedgerOpt {
      case null {
        if (ICP_LEDGER_ID_TEXT == "") return null;
        let ledgerId = Principal.fromText(ICP_LEDGER_ID_TEXT);
        let ledger = ICPLedger.createLedgerActor(ledgerId);
        icpLedgerOpt := ?ledger;
        ?ledger
      };
      case (?ledger) ?ledger;
    }
  };
  
  // Type aliases for convenience
  private type BlockIndex = CKBTC.BlockIndex;

  // Internal AMM pools
  private transient var pools : HashMap.HashMap<Text, SwapPool> = HashMap.HashMap(0, Text.equal, Text.hash);
  private transient var swaps : Buffer.Buffer<SwapRecord> = Buffer.Buffer(100);
  private transient var nextSwapId : Nat64 = 1;

  // Rate limiting (transient - resets on upgrade)
  private transient var rateLimiter = RateLimiter.RateLimiter(RateLimiter.SWAP_CONFIG);

  // SOL RPC Client
  private let solRpcClient = SolRpcClient.createClient();

  /// Initialize default pools
  public shared func init() : async () {
    // ckBTC/ICP pool
    pools.put("ckBTC_ICP", {
      tokenA = #ckBTC;
      tokenB = #ICP;
      reserveA = 10_000_000; // 0.1 BTC (8 decimals)
      reserveB = 6_000_000_000; // 6 ICP (8 decimals)
      kLast = 60_000_000_000_000_000;
    });

    // ckETH/ICP pool (placeholder)
    pools.put("ckETH_ICP", {
      tokenA = #ckETH;
      tokenB = #ICP;
      reserveA = 300_000_000_000_000_000; // 0.3 ETH (18 decimals)
      reserveB = 9_000_000_000_000; // 9 ICP (8 decimals)
      kLast = 2_700_000_000_000_000_000_000;
    });

    // SOL/ICP pool (real Solana via SOL RPC canister)
    pools.put("SOL_ICP", {
      tokenA = #SOL;
      tokenB = #ICP;
      reserveA = 500_000_000_000; // 500 SOL (9 decimals, lamports)
      reserveB = 12_000_000_000_000; // 12 ICP (8 decimals)
      kLast = 6_000_000_000_000_000_000_000;
    });
  };

  /// Get swap quote using internal AMM
  public query func getQuote(
    poolId : Text,
    amountIn : Nat64
  ) : async Result<SwapQuote, Text> {
    // Input validation
    if (not InputValidation.validateText(poolId, 1, ?50)) {
      return #err("Invalid pool ID")
    };
    if (not InputValidation.validateAmount(amountIn, 1, null)) {
      return #err("Amount must be greater than 0")
    };
    let poolOpt = pools.get(poolId);
    switch poolOpt {
      case null #err("Pool not found");
      case (?pool) {
        // Constant product formula: x * y = k
        let newReserveIn = pool.reserveA + amountIn;
        let newReserveOut = (pool.reserveA * pool.reserveB) / newReserveIn;
        let amountOut = pool.reserveB - newReserveOut;

        // Calculate 0.3% fee
        let fee = amountOut * 3 / 1000;
        let output = amountOut - fee;

        // Calculate price impact
        let amountOutNat = Nat64.toNat(amountOut);
        let reserveBNat = Nat64.toNat(pool.reserveB);
        let priceImpact = (Float.fromInt(amountOutNat : Int) / Float.fromInt(reserveBNat : Int)) * 100.0;

        #ok({
          amountOut = output;
          priceImpact = priceImpact;
          fee = fee;
        })
      }
    }
  };

  /// Execute swap using internal AMM
  public shared (msg) func swap(
    poolId : Text,
    tokenIn : ChainKeyToken,
    amountIn : Nat64,
    minAmountOut : Nat64
  ) : async Result<SwapResult, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(poolId, 1, ?50)) {
      return #err("Invalid pool ID")
    };
    if (not InputValidation.validateAmount(amountIn, 1, null)) {
      return #err("Amount must be greater than 0")
    };
    if (not InputValidation.validateAmount(minAmountOut, 1, null)) {
      return #err("Minimum amount out must be greater than 0")
    };

    let poolOpt = pools.get(poolId);
    
    switch poolOpt {
      case null #err("Pool not found");
      case (?pool) {
        // Verify token matches
        if (not tokensMatch(pool, tokenIn)) {
          return #err("Token mismatch")
        };

        // Calculate swap output
        let quoteResult = await getQuote(poolId, amountIn);
        switch quoteResult {
          case (#err(e)) #err(e);
          case (#ok(quote)) {
            // Verify minimum output
            if (quote.amountOut < minAmountOut) {
              return #err("Insufficient output amount")
            };

            // Determine which token is being swapped in/out
            let tokenOut = getOppositeToken(pool, tokenIn);
            let isTokenAIn = switch (pool.tokenA, tokenIn) {
              case (#ckBTC, #ckBTC) true;
              case (#ckETH, #ckETH) true;
              case (#SOL, #SOL) true;
              case (#ICP, #ICP) true;
              case _ false;
            };

            // Step 1: Transfer tokens IN (from user to canister)
            let transferInResult = await transferTokenIn(tokenIn, userId, amountIn);
            switch transferInResult {
              case (#err(e)) return #err("Failed to transfer tokens in: " # e);
              case (#ok()) {
                // Step 2: Transfer tokens OUT (from canister to user)
                let transferOutResult = await transferTokenOut(tokenOut, userId, quote.amountOut);
                switch transferOutResult {
                  case (#err(e)) {
                    // If transfer out fails, we need to refund the transfer in
                    // For now, we'll return an error - in production, implement refund logic
                    return #err("Failed to transfer tokens out: " # e # ". Your tokens may need to be refunded.")
                  };
                  case (#ok()) {
                    // Step 3: Update pool reserves after successful transfers
                    let (newReserveA, newReserveB) = if (isTokenAIn) {
                      (pool.reserveA + amountIn, pool.reserveB - quote.amountOut)
                    } else {
                      (pool.reserveA - quote.amountOut, pool.reserveB + amountIn)
                    };
                    
                    pools.put(poolId, {
                      tokenA = pool.tokenA;
                      tokenB = pool.tokenB;
                      reserveA = newReserveA;
                      reserveB = newReserveB;
                      kLast = Nat64.toNat(newReserveA) * Nat64.toNat(newReserveB);
                    });

                    // Step 4: Record swap
                    let swapId = nextSwapId;
                    nextSwapId += 1;
                    
                    swaps.add({
                      id = swapId;
                      user = userId;
                      tokenIn = tokenIn;
                      tokenOut = tokenOut;
                      amountIn = amountIn;
                      amountOut = quote.amountOut;
                      timestamp = Nat64.fromIntWrap(Time.now());
                    });

                    #ok({
                      txIndex = Nat64.toNat(swapId);
                      amountOut = quote.amountOut;
                      priceImpact = quote.priceImpact;
                    })
                  }
                }
              }
            }
          }
        }
      }
    }
  };

  /// Get ckBTC balance for user
  public func getCKBTCBalance(userId : Principal) : async Result<Nat, Text> {
    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    switch (getCkbtcLedger()) {
      case null #err("ckBTC ledger not available on this network");
      case (?ledger) {
        let account = getUserAccount(userId);
        await CKBTC.getBalance(ledger, account)
      };
    }
  };

  /// Get canister's ckBTC balance (pool balance)
  public shared func getCanisterCKBTCBalance() : async Result<Nat, Text> {
    switch (getCkbtcLedger()) {
      case null #err("ckBTC ledger not available on this network");
      case (?ledger) {
        let account = getCanisterAccount();
        await CKBTC.getBalance(ledger, account)
      };
    }
  };

  /// Deposit ckBTC into the swap canister (for liquidity or direct deposits)
  /// This allows users to transfer ckBTC to the canister for swaps
  public shared (msg) func depositCKBTC(amount : Nat64) : async Result<CKBTC.TxIndex, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateAmount(amount, 1, null)) {
      return #err("Amount must be greater than 0")
    };

    // Transfer ckBTC from user to canister
    await transferCkbtcIn(userId, amount)
  };

  /// Get Bitcoin address for ckBTC deposit
  public func getBTCAddress(userId : Principal) : async Result<Text, Text> {
    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    switch (getCkbtcMinter()) {
      case null #err("ckBTC minter not available on this network");
      case (?minter) await CKBTC.getBTCAddress(minter, ?userId);
    }
  };

  /// Check ckBTC deposit status and update balance
  /// This checks for new Bitcoin deposits and mints corresponding ckBTC
  public shared (msg) func updateBalance() : async Result<Nat, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };

    // Update balance via ckBTC minter
    // Note: CKBTC.updateBalance already handles error formatting
    // For retry logic, we'd need to check the error message for "Temporarily unavailable"
    switch (getCkbtcMinter()) {
      case null return #err("ckBTC minter not available on this network");
      case (?minter) {
        let result = await CKBTC.updateBalance(minter, userId);
    switch result {
      case (#ok(mintTx)) {
        // Return the minted amount
        #ok(mintTx.amount)
      };
      case (#err(msg)) {
        // Check if error is retryable (contains "Temporarily unavailable")
        if (Text.contains(msg, #text "Temporarily unavailable") or Text.contains(msg, #text "Please retry")) {
          // For now, return error - retry logic would require timer support
          // In production, implement retry with exponential backoff
          #err(msg)
        } else {
          #err(msg)
        }
      }
    }
      };
    }
  };

  /// Get ckETH balance for user
  public func getCKETHBalance(userId : Principal) : async Result<Nat, Text> {
    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    switch (getCkethLedger()) {
      case null #err("ckETH ledger not available on this network");
      case (?ledger) {
        let account = getUserAccount(userId);
        await CKETH.getBalance(ledger, account)
      };
    }
  };

  /// Get canister's ckETH balance (pool balance)
  public shared func getCanisterCKETHBalance() : async Result<Nat, Text> {
    switch (getCkethLedger()) {
      case null #err("ckETH ledger not available on this network");
      case (?ledger) {
        let account = getCanisterAccount();
        await CKETH.getBalance(ledger, account)
      };
    }
  };

  /// Deposit ckETH into the swap canister (for liquidity or direct deposits)
  /// This allows users to transfer ckETH to the canister for swaps
  public shared (msg) func depositCKETH(amount : Nat64) : async Result<CKETH.TxIndex, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateAmount(amount, 1, null)) {
      return #err("Amount must be greater than 0")
    };

    // Transfer ckETH from user to canister
    await transferCkethIn(userId, amount)
  };

  /// Get Ethereum address for ckETH deposit
  public func getETHAddress(userId : Principal) : async Result<Text, Text> {
    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    switch (getCkethMinter()) {
      case null #err("ckETH minter not available on this network");
      case (?minter) await CKETH.getETHAddress(minter, ?userId);
    }
  };

  /// Check ckETH deposit status and update balance
  /// This checks for new Ethereum deposits and mints corresponding ckETH
  public shared (msg) func updateCkETHBalance() : async Result<Nat, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };

    // Update balance via ckETH minter
    switch (getCkethMinter()) {
      case null return #err("ckETH minter not available on this network");
      case (?minter) {
        let result = await CKETH.updateBalance(minter, userId);
        switch result {
          case (#ok(mintTx)) {
            // Return the minted amount
            #ok(mintTx.amount)
          };
          case (#err(msg)) {
            // Check if error is retryable (contains "Temporarily unavailable")
            if (Text.contains(msg, #text "Temporarily unavailable") or Text.contains(msg, #text "Please retry")) {
              // For now, return error - retry logic would require timer support
              // In production, implement retry with exponential backoff
              #err(msg)
            } else {
              #err(msg)
            }
          }
        }
      };
    }
  };

  /// Retrieve ckETH as ETH (withdraw)
  /// Burns ckETH and retrieves native Ethereum to the specified address
  public shared (msg) func withdrawETH(
    amount : Nat64,
    ethAddress : Text
  ) : async Result<CKETH.BlockIndex, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(ethAddress, 40, ?42)) {
      return #err("Invalid Ethereum address format (must be 40-42 characters)")
    };
    if (not InputValidation.validateAmount(amount, 1, null)) {
      return #err("Amount must be greater than 0")
    };

    // Retry logic for ckETH operations (simple retry for TemporarilyUnavailable errors)
    var attempts = 0;
    let maxAttempts = 3;
    var lastError : ?Text = null;
    var shouldRetry = true;
    
    switch (getCkethMinter()) {
      case null return #err("ckETH minter not available on this network");
      case (?minter) {
        while (attempts < maxAttempts and shouldRetry) {
          attempts += 1;
          
          // Retrieve ETH via ckETH minter
          let result = await CKETH.retrieveETH(minter, ethAddress, Nat64.toNat(amount), null);
          switch result {
            case (#err(msg)) {
              // Check if error is retryable (TemporarilyUnavailable)
              if (Text.contains(msg, #text "Temporarily unavailable") and attempts < maxAttempts) {
                lastError := ?msg;
                // Simple retry - in production, consider using a timer for delays
                shouldRetry := true
              } else {
                shouldRetry := false;
                return #err(msg)
              }
            };
            case (#ok(blockIndex)) {
              shouldRetry := false;
              return #ok(blockIndex)
            }
          }
        };
      }
    };
    
    // All retries exhausted
    switch lastError {
      case (?err) #err("Failed after " # Nat.toText(maxAttempts) # " attempts: " # err);
      case null #err("Failed to retrieve ETH after " # Nat.toText(maxAttempts) # " attempts")
    }
  };

  /// Retrieve ckBTC as BTC (withdraw)
  /// Burns ckBTC and retrieves native Bitcoin to the specified address
  public shared (msg) func withdrawBTC(
    amount : Nat64,
    btcAddress : Text
  ) : async Result<BlockIndex, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(btcAddress, 26, ?62)) {
      return #err("Invalid Bitcoin address format")
    };
    if (not InputValidation.validateAmount(amount, 1, null)) {
      return #err("Amount must be greater than 0")
    };

    // Validate Bitcoin address format
    // Note: InputValidation.validateBitcoinAddress requires network parameter
    // For now, we'll do basic validation in the canister
    // TODO: Add network configuration to canister

    // Retry logic for ckBTC operations (simple retry for TemporarilyUnavailable errors)
    var attempts = 0;
    let maxAttempts = 3;
    var lastError : ?Text = null;
    var shouldRetry = true;
    
    switch (getCkbtcMinter()) {
      case null return #err("ckBTC minter not available on this network");
      case (?minter) {
        while (attempts < maxAttempts and shouldRetry) {
          attempts += 1;
          
          // Retrieve BTC via ckBTC minter
          let result = await CKBTC.retrieveBTC(minter, btcAddress, Nat64.toNat(amount), null);
      switch result {
        case (#err(msg)) {
          // Check if error is retryable (TemporarilyUnavailable)
          if (Text.contains(msg, #text "Temporarily unavailable") and attempts < maxAttempts) {
            lastError := ?msg;
            // Simple retry - in production, consider using a timer for delays
            shouldRetry := true
          } else {
            shouldRetry := false;
            return #err(msg)
          }
        };
        case (#ok(blockIndex)) {
          shouldRetry := false;
          return #ok(blockIndex)
        }
      }
        };
      }
    };
    
    // All retries exhausted
    switch lastError {
      case (?err) #err("Failed after " # Nat.toText(maxAttempts) # " attempts: " # err);
      case null #err("Failed to retrieve BTC after " # Nat.toText(maxAttempts) # " attempts")
    }
  };

  /// Get swap history for user
  public query func getSwapHistory(userId : Principal) : async [SwapRecord] {
    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return []
    };
    Array.filter<SwapRecord>(
      Buffer.toArray(swaps),
      func(swap) { Principal.equal(swap.user, userId) }
    )
  };

  /// Get all available pools
  public query func getPools() : async [SwapPool] {
    Iter.toArray(pools.vals())
  };

  /// Get pool details
  public query func getPool(poolId : Text) : async ?SwapPool {
    // Input validation
    if (not InputValidation.validateText(poolId, 1, ?50)) {
      return null
    };
    pools.get(poolId)
  };

  /// Get SOL balance for a Solana address
  public shared (msg) func getSOLBalance(solAddress : Text) : async Result<Nat64, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(solAddress, 32, ?44)) {
      return #err("Invalid Solana address format")
    };

    let rpcSources = #Default(#Mainnet);
    let rpcConfig : ?SolRpcClient.RpcConfig = ?{
      responseConsensus = ?#Equality;
      maxRetries = ?(3 : Nat);
      timeoutSeconds = ?(30 : Nat);
    };
    let params = ?{
      commitment = ?#finalized;
      minContextSlot = null;
    };

    switch (await solRpcClient.getBalance(rpcSources, rpcConfig, solAddress, params)) {
      case (#ok(result)) #ok(result.value);
      case (#err(e)) #err("Failed to get SOL balance: " # e);
    }
  };

  /// Get SOL account info
  public shared (msg) func getSOLAccountInfo(solAddress : Text) : async Result.Result<?SolRpcClient.AccountInfo, Text> {
    let userId = msg.caller;

    // Rate limiting check (expensive RPC call)
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(solAddress, 32, ?44)) {
      return #err("Invalid Solana address format")
    };
    
    let rpcSources = #Default(#Mainnet);
    let rpcConfig : ?SolRpcClient.RpcConfig = ?{
      responseConsensus = ?#Equality;
      maxRetries = ?(3 : Nat);
      timeoutSeconds = ?(30 : Nat);
    };
    let params = ?{
      commitment = ?#finalized;
      encoding = ?"base64";
      dataSlice = null;
      minContextSlot = null;
    };

    switch (await solRpcClient.getAccountInfo(rpcSources, rpcConfig, solAddress, params)) {
      case (#ok(result)) #ok(result.value);
      case (#err(e)) #err("Failed to get SOL account info: " # e);
    }
  };

  /// Get recent blockhash using getSlot and getBlock
  public shared (msg) func getRecentBlockhash() : async Result.Result<Text, Text> {
    let userId = msg.caller;

    // Rate limiting check (expensive RPC call)
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    
    let rpcSources = #Default(#Mainnet);
    let rpcConfig : ?SolRpcClient.RpcConfig = ?{
      responseConsensus = ?#Equality;
      maxRetries = ?(3 : Nat);
      timeoutSeconds = ?(30 : Nat);
    };

    // Get slot first
    let slotParams = ?{
      commitment = ?#finalized;
      minContextSlot = null;
    };

    let slotResult = switch (await solRpcClient.getSlot(rpcSources, rpcConfig, slotParams)) {
      case (#ok(result)) #ok(result.slot);
      case (#err(e)) #err("Failed to get slot: " # e);
    };

    let slot = switch (slotResult) {
      case (#ok(s)) s;
      case (#err(e)) return #err(e);
    };

    // Get block to extract blockhash
    let blockParams = ?{
      slot = ?slot;
      commitment = ?#finalized;
      encoding = ?"base58";
      transactionDetails = ?"none";
      maxSupportedTransactionVersion = null;
      rewards = ?false;
    };

    switch (await solRpcClient.getBlock(rpcSources, rpcConfig, blockParams)) {
      case (#ok(block)) {
        switch (block.blockhash) {
          case (?bh) #ok(bh);
          case (null) #err("Blockhash not found in block response");
        }
      };
      case (#err(e)) #err("Failed to get block: " # e);
    }
  };

  /// Get current Solana slot
  public shared (msg) func getSolanaSlot() : async Result.Result<Nat64, Text> {
    let userId = msg.caller;

    // Rate limiting check (expensive RPC call)
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    
    let rpcSources = #Default(#Mainnet);
    let rpcConfig : ?SolRpcClient.RpcConfig = ?{
      responseConsensus = ?#Equality;
      maxRetries = ?(3 : Nat);
      timeoutSeconds = ?(30 : Nat);
    };
    let params = ?{
      commitment = ?#finalized;
      minContextSlot = null;
    };

    switch (await solRpcClient.getSlot(rpcSources, rpcConfig, params)) {
      case (#ok(result)) #ok(result.slot);
      case (#err(e)) #err("Failed to get Solana slot: " # e);
    }
  };

  /// Get Solana address for a user (derived from Ed25519 public key)
  public shared (msg) func getSolanaAddress(keyName : ?Text) : async Result.Result<Text, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };

    // Derive path from user principal
    let principalBlob = Principal.toBlob(userId);
    let principalBytes = Blob.toArray(principalBlob);
    let derivationPath = [
      Blob.fromArray(principalBytes)
    ];

    switch (await SolanaUtils.getEd25519PublicKey(derivationPath, keyName)) {
      case (#ok(publicKey)) {
        // Derive Solana address from public key
        let address = SolanaUtils.deriveSolanaAddress(publicKey);
        #ok(address)
      };
      case (#err(e)) #err("Failed to get Solana address: " # e);
    }
  };

  /// Send SOL to a Solana address
  /// This builds, signs, and sends a Solana transfer transaction
  public shared (msg) func sendSOL(
    toAddress : Text,
    amountLamports : Nat64,
    keyName : ?Text
  ) : async Result.Result<Text, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(toAddress, 32, ?44)) {
      return #err("Invalid Solana address format")
    };
    if (not InputValidation.validateAmount(amountLamports, 1, null)) {
      return #err("Amount must be greater than 0")
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(toAddress, 32, ?44)) {
      return #err("Invalid Solana address format")
    };
    if (not InputValidation.validateAmount(amountLamports, 1, null)) {
      return #err("Amount must be greater than 0")
    };

    // 1. Get Solana address for sender
    let principalBlob = Principal.toBlob(userId);
    let principalBytes = Blob.toArray(principalBlob);
    let derivationPath = [
      Blob.fromArray(principalBytes)
    ];

    let fromAddressResult = switch (await SolanaUtils.getEd25519PublicKey(derivationPath, keyName)) {
      case (#ok(publicKey)) {
        let address = SolanaUtils.deriveSolanaAddress(publicKey);
        #ok(address)
      };
      case (#err(e)) #err("Failed to get sender address: " # e);
    };

    let fromAddress = switch (fromAddressResult) {
      case (#ok(addr)) addr;
      case (#err(e)) return #err(e);
    };

    // 2. Get recent blockhash (using getSlot then getBlock)
    let rpcSources = #Default(#Mainnet);
    let rpcConfig : ?SolRpcClient.RpcConfig = ?{
      responseConsensus = ?#Equality;
      maxRetries = ?(3 : Nat);
      timeoutSeconds = ?(30 : Nat);
    };

    // Get slot first
    let slotParams = ?{
      commitment = ?#finalized;
      minContextSlot = null;
    };

    let slotResult = switch (await solRpcClient.getSlot(rpcSources, rpcConfig, slotParams)) {
      case (#ok(result)) #ok(result.slot);
      case (#err(e)) #err("Failed to get slot: " # e);
    };

    let slot = switch (slotResult) {
      case (#ok(s)) s;
      case (#err(e)) return #err(e);
    };

    // 3. Get block to get blockhash (using getBlock with slot)
    let blockParams = ?{
      slot = ?slot;
      commitment = ?#finalized;
      encoding = ?"base58";
      transactionDetails = ?"none";
      maxSupportedTransactionVersion = null;
      rewards = ?false;
    };

    let blockResult = switch (await solRpcClient.getBlock(rpcSources, rpcConfig, blockParams)) {
      case (#ok(block)) {
        switch (block.blockhash) {
          case (?bh) #ok(bh);
          case (null) #err("Blockhash not found in block response");
        }
      };
      case (#err(e)) #err("Failed to get block: " # e);
    };

    let _recentBlockhash = switch (blockResult) {
      case (#ok(bh)) bh;
      case (#err(e)) return #err(e);
    };

    // 4. Build transaction using jsonRequest (more flexible than wire format)
    // Create a transfer instruction using System Program
    let _transferInstruction = SolanaUtils.createTransferInstruction(fromAddress, toAddress, amountLamports);
    
    // Build transaction JSON-RPC request
    // Note: For full production, we'd build the transaction properly and sign it
    // For now, we'll use jsonRequest which allows us to send any Solana RPC method
    // This requires the transaction to be built and signed externally or via a more complete library
    
    // 5. For now, return an error indicating that full transaction building is needed
    // In production, you would:
    // - Build the transaction message
    // - Sign it with Ed25519
    // - Serialize to base64
    // - Send via sendTransaction
    
    #err("Full transaction building and signing not yet implemented. Use a Solana library for transaction serialization.")
  };

  // Generic account type (works for all ICRC-1/ICRC-2 tokens)
  private type Account = {
    owner : Principal;
    subaccount : ?Blob;
  };

  // Canister account for holding tokens in pools
  private func getCanisterAccount() : Account {
    {
      owner = Principal.fromActor(SwapCanister);
      subaccount = null;
    }
  };

  // Helper to get user account
  private func getUserAccount(userId : Principal) : Account {
    {
      owner = userId;
      subaccount = null;
    }
  };

  /// Transfer ckBTC from user to canister
  private func transferCkbtcIn(
    userId : Principal,
    amount : Nat64
  ) : async Result<CKBTC.TxIndex, Text> {
    switch (getCkbtcLedger()) {
      case null #err("ckBTC ledger not available on this network");
      case (?ledger) {
        let fromAccount = getUserAccount(userId);
        let toAccount = getCanisterAccount();
        let amountNat = Nat64.toNat(amount);
        
        // Get fee first
        let fee = await ledger.icrc1_fee();
        let totalAmount = amountNat + fee;
        
        // Check user balance
        let balanceResult = await CKBTC.getBalance(ledger, fromAccount);
        switch balanceResult {
          case (#ok(balance)) {
            if (balance < totalAmount) {
              return #err("Insufficient ckBTC balance. Required: " # Nat.toText(totalAmount) # ", Available: " # Nat.toText(balance))
            }
          };
          case (#err(e)) return #err("Failed to check balance: " # e);
        };
        
        // Transfer tokens
        await CKBTC.transfer(ledger, fromAccount, toAccount, amountNat, ?fee, null)
      };
    }
  };

  /// Transfer ckBTC from canister to user
  private func transferCkbtcOut(
    userId : Principal,
    amount : Nat64
  ) : async Result<CKBTC.TxIndex, Text> {
    switch (getCkbtcLedger()) {
      case null #err("ckBTC ledger not available on this network");
      case (?ledger) {
        let fromAccount = getCanisterAccount();
        let toAccount = getUserAccount(userId);
        let amountNat = Nat64.toNat(amount);
        
        // Get fee first
        let fee = await ledger.icrc1_fee();
        let totalAmount = amountNat + fee;
        
        // Check canister balance
        let balanceResult = await CKBTC.getBalance(ledger, fromAccount);
        switch balanceResult {
          case (#ok(balance)) {
            if (balance < totalAmount) {
              return #err("Insufficient ckBTC in pool. Required: " # Nat.toText(totalAmount) # ", Available: " # Nat.toText(balance))
            }
          };
          case (#err(e)) return #err("Failed to check pool balance: " # e);
        };
        
        // Transfer tokens
        await CKBTC.transfer(ledger, fromAccount, toAccount, amountNat, ?fee, null)
      };
    }
  };

  /// Transfer ckETH from user to canister
  private func transferCkethIn(
    userId : Principal,
    amount : Nat64
  ) : async Result<CKETH.TxIndex, Text> {
    switch (getCkethLedger()) {
      case null #err("ckETH ledger not available on this network");
      case (?ledger) {
        let fromAccount = getUserAccount(userId);
        let toAccount = getCanisterAccount();
        let amountNat = Nat64.toNat(amount);
        
        // Get fee first
        let fee = await ledger.icrc1_fee();
        let totalAmount = amountNat + fee;
        
        // Check user balance
        let balanceResult = await CKETH.getBalance(ledger, fromAccount);
        switch balanceResult {
          case (#ok(balance)) {
            if (balance < totalAmount) {
              return #err("Insufficient ckETH balance. Required: " # Nat.toText(totalAmount) # ", Available: " # Nat.toText(balance))
            }
          };
          case (#err(e)) return #err("Failed to check balance: " # e);
        };
        
        // Transfer tokens
        await CKETH.transfer(ledger, fromAccount, toAccount, amountNat, ?fee, null)
      };
    }
  };

  /// Transfer ckETH from canister to user
  private func transferCkethOut(
    userId : Principal,
    amount : Nat64
  ) : async Result<CKETH.TxIndex, Text> {
    switch (getCkethLedger()) {
      case null #err("ckETH ledger not available on this network");
      case (?ledger) {
        let fromAccount = getCanisterAccount();
        let toAccount = getUserAccount(userId);
        let amountNat = Nat64.toNat(amount);
        
        // Get fee first
        let fee = await ledger.icrc1_fee();
        let totalAmount = amountNat + fee;
        
        // Check canister balance
        let balanceResult = await CKETH.getBalance(ledger, fromAccount);
        switch balanceResult {
          case (#ok(balance)) {
            if (balance < totalAmount) {
              return #err("Insufficient ckETH in pool. Required: " # Nat.toText(totalAmount) # ", Available: " # Nat.toText(balance))
            }
          };
          case (#err(e)) return #err("Failed to check pool balance: " # e);
        };
        
        // Transfer tokens
        await CKETH.transfer(ledger, fromAccount, toAccount, amountNat, ?fee, null)
      };
    }
  };

  /// Transfer ICP from user to canister
  private func transferIcpIn(
    userId : Principal,
    amount : Nat64
  ) : async Result<ICPLedger.TxIndex, Text> {
    switch (getIcpLedger()) {
      case null #err("ICP ledger not available on this network");
      case (?ledger) {
        let fromAccount = getUserAccount(userId);
        let toAccount = getCanisterAccount();
        let amountNat = Nat64.toNat(amount);
        
        // Get fee first
        let fee = await ledger.icrc1_fee();
        let totalAmount = amountNat + fee;
        
        // Check user balance
        let balanceResult = await ICPLedger.getBalance(ledger, fromAccount);
        switch balanceResult {
          case (#ok(balance)) {
            if (balance < totalAmount) {
              return #err("Insufficient ICP balance. Required: " # Nat.toText(totalAmount) # ", Available: " # Nat.toText(balance))
            }
          };
          case (#err(e)) return #err("Failed to check balance: " # e);
        };
        
        // Transfer tokens
        await ICPLedger.transfer(ledger, fromAccount, toAccount, amountNat, ?fee, null)
      };
    }
  };

  /// Transfer ICP from canister to user
  private func transferIcpOut(
    userId : Principal,
    amount : Nat64
  ) : async Result<ICPLedger.TxIndex, Text> {
    switch (getIcpLedger()) {
      case null #err("ICP ledger not available on this network");
      case (?ledger) {
        let fromAccount = getCanisterAccount();
        let toAccount = getUserAccount(userId);
        let amountNat = Nat64.toNat(amount);
        
        // Get fee first
        let fee = await ledger.icrc1_fee();
        let totalAmount = amountNat + fee;
        
        // Check canister balance
        let balanceResult = await ICPLedger.getBalance(ledger, fromAccount);
        switch balanceResult {
          case (#ok(balance)) {
            if (balance < totalAmount) {
              return #err("Insufficient ICP in pool. Required: " # Nat.toText(totalAmount) # ", Available: " # Nat.toText(balance))
            }
          };
          case (#err(e)) return #err("Failed to check pool balance: " # e);
        };
        
        // Transfer tokens
        await ICPLedger.transfer(ledger, fromAccount, toAccount, amountNat, ?fee, null)
      };
    }
  };

  /// Transfer SOL (in-memory tracking for swaps)
  /// Note: This is a simplified implementation for swap operations
  /// Full SOL integration requires external Solana wallet or RPC integration
  private func transferSolIn(
    userId : Principal,
    amount : Nat64
  ) : async Result<(), Text> {
    // For swap operations, we track SOL balances in-memory
    // In production, this would verify actual SOL balance via Solana RPC
    let currentBalance : Nat64 = switch (solBalances.get(userId)) {
      case null 0 : Nat64;
      case (?bal) bal;
    };
    
    if (currentBalance < amount) {
      return #err("Insufficient SOL balance. Required: " # Nat64.toText(amount) # ", Available: " # Nat64.toText(currentBalance))
    };
    
    // Deduct from user balance
    let newBalance : Nat64 = currentBalance - amount;
    if (newBalance == (0 : Nat64)) {
      solBalances.delete(userId);
    } else {
      solBalances.put(userId, newBalance);
    };
    
    // Add to canister balance (tracked separately or in pool)
    #ok()
  };

  /// Transfer SOL out (in-memory tracking for swaps)
  private func transferSolOut(
    userId : Principal,
    amount : Nat64
  ) : async Result<(), Text> {
    // For swap operations, we track SOL balances in-memory
    // In production, this would send actual SOL via Solana RPC
    
    // Add to user balance
    let currentBalance : Nat64 = switch (solBalances.get(userId)) {
      case null 0 : Nat64;
      case (?bal) bal;
    };
    let newBalance : Nat64 = currentBalance + amount;
    solBalances.put(userId, newBalance);
    
    #ok()
  };

  /// Transfer token in (from user to canister)
  private func transferTokenIn(
    token : ChainKeyToken,
    userId : Principal,
    amount : Nat64
  ) : async Result<(), Text> {
    switch token {
      case (#ckBTC) {
        let result = await transferCkbtcIn(userId, amount);
        switch result {
          case (#ok(_)) #ok();
          case (#err(e)) #err(e);
        }
      };
      case (#ckETH) {
        let result = await transferCkethIn(userId, amount);
        switch result {
          case (#ok(_)) #ok();
          case (#err(e)) #err(e);
        }
      };
      case (#ICP) {
        let result = await transferIcpIn(userId, amount);
        switch result {
          case (#ok(_)) #ok();
          case (#err(e)) #err(e);
        }
      };
      case (#SOL) {
        await transferSolIn(userId, amount)
      };
    }
  };

  /// Transfer token out (from canister to user)
  private func transferTokenOut(
    token : ChainKeyToken,
    userId : Principal,
    amount : Nat64
  ) : async Result<(), Text> {
    switch token {
      case (#ckBTC) {
        let result = await transferCkbtcOut(userId, amount);
        switch result {
          case (#ok(_)) #ok();
          case (#err(e)) #err(e);
        }
      };
      case (#ckETH) {
        let result = await transferCkethOut(userId, amount);
        switch result {
          case (#ok(_)) #ok();
          case (#err(e)) #err(e);
        }
      };
      case (#ICP) {
        let result = await transferIcpOut(userId, amount);
        switch result {
          case (#ok(_)) #ok();
          case (#err(e)) #err(e);
        }
      };
      case (#SOL) {
        await transferSolOut(userId, amount)
      };
    }
  };

  // Helper functions
  private func tokensMatch(pool : SwapPool, token : ChainKeyToken) : Bool {
    let matchesTokenA = switch (pool.tokenA, token) {
      case (#ckBTC, #ckBTC) true;
      case (#ckETH, #ckETH) true;
      case (#SOL, #SOL) true;
      case (#ICP, #ICP) true;
      case _ false;
    };
    let matchesTokenB = switch (pool.tokenB, token) {
      case (#ckBTC, #ckBTC) true;
      case (#ckETH, #ckETH) true;
      case (#SOL, #SOL) true;
      case (#ICP, #ICP) true;
      case _ false;
    };
    matchesTokenA or matchesTokenB
  };

  private func getOppositeToken(pool : SwapPool, token : ChainKeyToken) : ChainKeyToken {
    switch (pool.tokenA, token) {
      case (#ckBTC, #ckBTC) pool.tokenB;
      case (#ckETH, #ckETH) pool.tokenB;
      case (#SOL, #SOL) pool.tokenB;
      case (#ICP, #ICP) pool.tokenB;
      case _ pool.tokenA;
    }
  };
};

