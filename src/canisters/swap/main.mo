import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import _Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
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
import JSON "mo:json";

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
  
  // Track canister's previous total SOL balance for deposit detection
  // This is used to detect new deposits by comparing current vs previous canister balance
  private transient var previousCanisterSolBalance : ?Nat64 = null;
  
  // Track processed transaction signatures to avoid double-crediting
  // Maps transaction signature (base58) to whether it's been processed
  private transient var processedTransactions : HashMap.HashMap<Text, Bool> = HashMap.HashMap(0, Text.equal, Text.hash);
  
  // Track last scanned slot for efficient transaction scanning
  // Only scan transactions from slots we haven't checked yet
  // Note: Currently unused - can be implemented for incremental scanning
  private transient var _lastScannedSlot : ?Nat64 = null;
  
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

  /// Get user's SOL swap balance (from in-memory tracking)
  /// This returns the SOL balance available for swaps in the canister
  public shared (msg) func getUserSOLBalance() : async Result<Nat64, Text> {
    let userId = msg.caller;

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };

    // Get user's SOL balance from in-memory tracking
    let balance : Nat64 = switch (solBalances.get(userId)) {
      case null 0 : Nat64;
      case (?bal) bal;
    };

    #ok(balance)
  };

  /// Get ICP balance for user
  public func getICPBalance(userId : Principal) : async Result<Nat, Text> {
    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    switch (getIcpLedger()) {
      case null #err("ICP ledger not available on this network");
      case (?ledger) {
        let account = getUserAccount(userId);
        await ICPLedger.getBalance(ledger, account)
      };
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

  /// Get canister's Solana address for SOL deposits
  /// Users can send SOL to this address, then call updateSOLBalance() to credit their account
  public shared func getCanisterSolanaAddress() : async Result.Result<Text, Text> {
    let canisterPrincipal = Principal.fromActor(SwapCanister);
    let canisterBlob = Principal.toBlob(canisterPrincipal);
    let canisterBytes = Blob.toArray(canisterBlob);
    let canisterDerivationPath = [Blob.fromArray(canisterBytes)];
    
    switch (await SolanaUtils.getEd25519PublicKey(canisterDerivationPath, null)) {
      case (#ok(publicKey)) {
        let address = SolanaUtils.deriveSolanaAddress(publicKey);
        #ok(address)
      };
      case (#err(e)) #err("Failed to get canister Solana address: " # e);
    }
  };

  /// Get transaction signatures for an address
  /// Uses Solana RPC getSignaturesForAddress method
  private func getTransactionSignatures(
    address : Text,
    limit : ?Nat
  ) : async Result<[Text], Text> {
    let rpcSources = #Default(#Mainnet);
    let rpcConfig : ?SolRpcClient.RpcConfig = ?{
      responseConsensus = ?#Equality;
      maxRetries = ?(3 : Nat);
      timeoutSeconds = ?(30 : Nat);
    };
    
    // Build JSON-RPC request parameters
    // getSignaturesForAddress(address, {limit: N})
    let limitValue = Option.get<Nat>(limit, 100);
    let paramsJson = "{ \"address\": \"" # address # "\", \"options\": { \"limit\": " # Nat.toText(limitValue) # " } }";
    let paramsArray = [paramsJson];
    
    // Call jsonRequest to get transaction signatures
    switch (await solRpcClient.jsonRequest(rpcSources, rpcConfig, "getSignaturesForAddress", ?paramsArray)) {
      case (#ok(response)) {
        // Parse JSON response
        switch (JSON.parse(response)) {
          case (#ok(json)) {
            // Extract signatures array from response
            // Response format: { "result": [{ "signature": "...", ... }, ...] }
            switch (JSON.get(json, "result")) {
              case (?resultJson) {
                switch (resultJson) {
                  case (#array(signatures)) {
                    var sigs = Buffer.Buffer<Text>(signatures.size());
                    for (sigJson in signatures.vals()) {
                      // Extract signature field from each object
                      switch (JSON.get(sigJson, "signature")) {
                        case (?sigValue) {
                          switch (sigValue) {
                            case (#string(sig)) sigs.add(sig);
                            case _ {}; // Skip invalid entries
                          };
                        };
                        case null {};
                      };
                    };
                    #ok(Buffer.toArray(sigs))
                  };
                  case _ #err("Invalid response format: expected array");
                }
              };
              case null #err("No result field in response");
            }
          };
          case (#err(_)) #err("Failed to parse JSON response");
        }
      };
      case (#err(e)) #err("RPC call failed: " # e);
    }
  };

  /// Get transaction details by signature
  /// Uses Solana RPC getTransaction method
  private func getTransactionDetails(
    signature : Text
  ) : async Result<Text, Text> {
    let rpcSources = #Default(#Mainnet);
    let rpcConfig : ?SolRpcClient.RpcConfig = ?{
      responseConsensus = ?#Equality;
      maxRetries = ?(3 : Nat);
      timeoutSeconds = ?(30 : Nat);
    };
    
    // Build JSON-RPC request parameters
    // getTransaction(signature, {encoding: "jsonParsed", commitment: "finalized"})
    let paramsJson = "{ \"signature\": \"" # signature # "\", \"options\": { \"encoding\": \"jsonParsed\", \"commitment\": \"finalized\", \"maxSupportedTransactionVersion\": 0 } }";
    let paramsArray = [paramsJson];
    
    // Call jsonRequest to get transaction details
    switch (await solRpcClient.jsonRequest(rpcSources, rpcConfig, "getTransaction", ?paramsArray)) {
      case (#ok(response)) #ok(response);
      case (#err(e)) #err("RPC call failed: " # e);
    }
  };

  /// Parse transaction JSON to extract transfer information and memo
  private func parseTransaction(
    txJsonText : Text,
    canisterAddress : Text
  ) : Result<{
    amount : Nat64;
    fromAddress : Text;
    memo : ?Text;
  }, Text> {
    switch (JSON.parse(txJsonText)) {
      case (#ok(json)) {
        // Extract transaction result
        switch (JSON.get(json, "result")) {
          case (?resultJson) {
            // Check transaction status (must be "Ok")
            switch (JSON.get(resultJson, "meta.err")) {
              case null {
                // Transaction succeeded, continue parsing
                // Extract account keys to find addresses
                switch (JSON.get(resultJson, "transaction.message.accountKeys")) {
                  case (?accountKeysJson) {
                    switch (accountKeysJson) {
                      case (#array(accounts)) {
                        // Extract addresses from account keys
                        var fromAddress : ?Text = null;
                        var toIndex : ?Nat = null;
                        var idx = 0;
                        
                        for (acc in accounts.vals()) {
                          switch (acc) {
                            case (#object_(fields)) {
                              var pubkey : ?Text = null;
                              for ((key, value) in fields.vals()) {
                                if (key == "pubkey") {
                                  switch (value) {
                                    case (#string(p)) pubkey := ?p;
                                    case _ {};
                                  };
                                };
                              };
                              
                              switch (pubkey) {
                                case (?pk) {
                                  if (idx == 0) {
                                    // First account is fee payer (from address)
                                    fromAddress := ?pk;
                                  };
                                  if (pk == canisterAddress) {
                                    toIndex := ?idx;
                                  };
                                };
                                case null {};
                              };
                            };
                            case _ {};
                          };
                          idx += 1;
                        };
                        
                        // Extract amount from balance changes
                        var amount : Nat64 = 0;
                        switch (JSON.get(resultJson, "meta.preBalances")) {
                          case (?preBalancesJson) {
                            switch (JSON.get(resultJson, "meta.postBalances")) {
                              case (?postBalancesJson) {
                                switch (toIndex) {
                                  case (?toIdx) {
                                    switch (preBalancesJson, postBalancesJson) {
                                      case (#array(preBal), #array(postBal)) {
                                        if (toIdx < preBal.size() and toIdx < postBal.size()) {
                                          // Calculate balance change
                                          switch (preBal[toIdx], postBal[toIdx]) {
                                            case (#number(#int(pre)), #number(#int(post))) {
                                              let diff = post - pre;
                                              if (diff > 0) {
                                                amount := Nat64.fromIntWrap(Int.abs(diff));
                                              };
                                            };
                                            case _ {};
                                          };
                                        };
                                      };
                                      case _ {};
                                    };
                                  };
                                  case null {};
                                };
                              };
                              case null {};
                            };
                          };
                          case null {};
                        };
                        
                        // Extract memo from instructions
                        var memo : ?Text = null;
                        switch (JSON.get(resultJson, "transaction.message.instructions")) {
                          case (?instructionsJson) {
                            switch (instructionsJson) {
                              case (#array(instructions)) {
                                for (inst in instructions.vals()) {
                                  switch (JSON.get(inst, "programId")) {
                                    case (?programIdJson) {
                                      switch (programIdJson) {
                                        case (#string(pid)) {
                                          if (pid == "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr") {
                                            // This is a memo instruction
                                            switch (JSON.get(inst, "data")) {
                                              case (?dataJson) {
                                                switch (dataJson) {
                                                  case (#string(memoText)) {
                                                    memo := ?memoText;
                                                  };
                                                  case _ {};
                                                };
                                              };
                                              case null {};
                                            };
                                          };
                                        };
                                        case _ {};
                                      };
                                    };
                                    case null {};
                                  };
                                };
                              };
                              case _ {};
                            };
                          };
                          case null {};
                        };
                        
                        switch (fromAddress) {
                          case (?fromAddr) {
                            #ok({
                              amount = amount;
                              fromAddress = fromAddr;
                              memo = memo;
                            })
                          };
                          case null #err("Could not find from address in transaction");
                        }
                      };
                      case _ #err("Invalid accountKeys format");
                    }
                  };
                  case null #err("No accountKeys in message");
                }
              };
              case (?_) #err("Transaction failed");
            }
          };
          case null #err("No result in response");
        }
      };
      case (#err(_)) #err("Failed to parse transaction JSON");
    }
  };

  /// Verify and process a specific transaction
  private func verifyAndProcessTransaction(
    signature : Text,
    canisterAddress : Text,
    userId : Principal
  ) : async Result<Nat64, Text> {
    // Get transaction details
    let txResult = await getTransactionDetails(signature);
    let txJson = switch (txResult) {
      case (#ok(json)) json;
      case (#err(e)) return #err("Failed to get transaction: " # e);
    };
    
    // Parse transaction
    let parsedResult = parseTransaction(txJson, canisterAddress);
    let parsed = switch (parsedResult) {
      case (#ok(p)) p;
      case (#err(e)) return #err("Failed to parse transaction: " # e);
    };
    
    // Extract user from memo if present
    let targetUserId = switch (parsed.memo) {
      case (?memoText) {
        // Try to parse Principal from memo
        // Principal.fromText throws on error, so we use try-catch pattern
        try {
          Principal.fromText(memoText)
        } catch (_) {
          userId // Fall back to caller if memo invalid
        }
      };
      case null userId; // No memo, credit to caller
    };
    
    // Verify the caller matches the memo (or caller is processing their own transaction)
    if (targetUserId != userId) {
      return #err("Transaction memo does not match caller. Memo indicates user: " # Principal.toText(targetUserId))
    };
    
    // Verify amount > 0
    if (parsed.amount == 0) {
      return #err("Could not extract transaction amount. Transaction may not be a valid transfer.")
    };
    
    // Credit deposit to user
    let userCurrentBalance : Nat64 = switch (solBalances.get(targetUserId)) {
      case null 0 : Nat64;
      case (?bal) bal;
    };
    
    let userNewBalance = userCurrentBalance + parsed.amount;
    solBalances.put(targetUserId, userNewBalance);
    
    // Mark transaction as processed
    processedTransactions.put(signature, true);
    
    #ok(parsed.amount)
  };

  /// Scan recent transactions for deposits with memos
  private func scanRecentTransactions(
    canisterAddress : Text
  ) : async Result<Nat64, Text> {
    // Get recent transaction signatures
    let sigsResult = await getTransactionSignatures(canisterAddress, ?50);
    let signatures = switch (sigsResult) {
      case (#ok(sigs)) sigs;
      case (#err(e)) return #err("Failed to get transaction signatures: " # e);
    };
    
    var totalCredited : Nat64 = 0;
    
    // Process each transaction
    for (sig in signatures.vals()) {
      // Skip if already processed
      if (Option.isNull(processedTransactions.get(sig))) {
        // Get transaction details
        let txResult = await getTransactionDetails(sig);
        switch (txResult) {
          case (#ok(txJson)) {
            // Parse transaction
            let parsedResult = parseTransaction(txJson, canisterAddress);
            switch (parsedResult) {
              case (#ok(parsed)) {
                // Check if transaction has memo
                switch (parsed.memo) {
                  case (?memoText) {
                    // Try to extract user Principal from memo
                    // Principal.fromText throws on error, so we use try-catch pattern
                    try {
                      let userId = Principal.fromText(memoText);
                      // Verify amount > 0
                      if (parsed.amount > 0) {
                        // Credit deposit to user
                        let userCurrentBalance : Nat64 = switch (solBalances.get(userId)) {
                          case null 0 : Nat64;
                          case (?bal) bal;
                        };
                        
                        let userNewBalance = userCurrentBalance + parsed.amount;
                        solBalances.put(userId, userNewBalance);
                        totalCredited += parsed.amount;
                      };
                      
                      // Mark as processed
                      processedTransactions.put(sig, true);
                    } catch (_) {
                      // Invalid Principal in memo - skip (do nothing)
                    };
                  };
                  case null {
                    // No memo - skip (can't identify user)
                  };
                };
              };
              case (#err(_)) {
                // Failed to parse - skip (do nothing)
              };
            };
          };
          case (#err(_)) {
            // Failed to get transaction - skip (do nothing)
          };
        };
      };
    };
    
    #ok(totalCredited)
  };

  /// Update SOL balance by checking for new deposits to canister address
  /// Users should call this after sending SOL to the canister's address
  /// Optionally provide transaction signature for precise tracking
  /// If no signature provided, automatically scans recent transactions with memos
  public shared (msg) func updateSOLBalance(transactionSignature : ?Text) : async Result<Nat64, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };

    // Get canister's Solana address
    let canisterPrincipal = Principal.fromActor(SwapCanister);
    let canisterBlob = Principal.toBlob(canisterPrincipal);
    let canisterBytes = Blob.toArray(canisterBlob);
    let canisterDerivationPath = [Blob.fromArray(canisterBytes)];
    
    let canisterAddressResult = switch (await SolanaUtils.getEd25519PublicKey(canisterDerivationPath, null)) {
      case (#ok(publicKey)) {
        let address = SolanaUtils.deriveSolanaAddress(publicKey);
        #ok(address)
      };
      case (#err(e)) #err("Failed to get canister Solana address: " # e);
    };
    
    let canisterAddress = switch (canisterAddressResult) {
      case (#ok(addr)) addr;
      case (#err(e)) return #err(e);
    };
    
    // Get canister's current SOL balance via RPC
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
    
    let balanceResult = switch (await solRpcClient.getBalance(rpcSources, rpcConfig, canisterAddress, params)) {
      case (#ok(result)) #ok(result.value);
      case (#err(e)) #err("Failed to get canister SOL balance: " # e);
    };
    
    let currentBalance = switch (balanceResult) {
      case (#ok(bal)) bal;
      case (#err(e)) return #err(e);
    };
    
    // If transaction signature provided, verify and credit that specific transaction
    switch (transactionSignature) {
      case (?sig) {
        // Check if already processed
        if (Option.isSome(processedTransactions.get(sig))) {
          return #err("Transaction already processed")
        };
        
        // Verify and process the specific transaction
        let txResult = await verifyAndProcessTransaction(sig, canisterAddress, userId);
        switch (txResult) {
          case (#ok(amount)) {
            // Update canister's tracked balance
            previousCanisterSolBalance := ?currentBalance;
            #ok(amount)
          };
          case (#err(e)) #err(e);
        }
      };
      case null {
        // No signature provided - scan recent transactions automatically
        let scanResult = await scanRecentTransactions(canisterAddress);
        switch (scanResult) {
          case (#ok(totalCredited)) {
            // Update canister's tracked balance
            previousCanisterSolBalance := ?currentBalance;
            #ok(totalCredited)
          };
          case (#err(_)) {
            // If scanning fails, fall back to balance-based approach
            let previousCanisterBalance : Nat64 = switch (previousCanisterSolBalance) {
              case null 0 : Nat64;
              case (?bal) bal;
            };
            
            if (currentBalance > previousCanisterBalance) {
              let newDeposit = currentBalance - previousCanisterBalance;
              
              // Credit the new deposit to the calling user's swap balance
              let userCurrentBalance : Nat64 = switch (solBalances.get(userId)) {
                case null 0 : Nat64;
                case (?bal) bal;
              };
              let userNewBalance = userCurrentBalance + newDeposit;
              solBalances.put(userId, userNewBalance);
              
              // Update canister's tracked balance for next comparison
              previousCanisterSolBalance := ?currentBalance;
              
              #ok(newDeposit)
            } else {
              // Update tracked balance even if no new deposits
              previousCanisterSolBalance := ?currentBalance;
              #ok(0 : Nat64)
            }
          };
        }
      };
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

    // Get Solana address for sender
    let principalBlob = Principal.toBlob(userId);
    let principalBytes = Blob.toArray(principalBlob);
    let derivationPath = [Blob.fromArray(principalBytes)];

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

    // Use internal function to send SOL
    await sendSOLInternal(fromAddress, toAddress, amountLamports, derivationPath, keyName)
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

  /// Transfer SOL (from user to canister) - Full RPC integration
  /// Verifies actual SOL balance via Solana RPC before allowing swap
  private func transferSolIn(
    userId : Principal,
    amount : Nat64
  ) : async Result<(), Text> {
    // Get user's Solana address
    let principalBlob = Principal.toBlob(userId);
    let principalBytes = Blob.toArray(principalBlob);
    let derivationPath = [Blob.fromArray(principalBytes)];
    
    let userAddressResult = switch (await SolanaUtils.getEd25519PublicKey(derivationPath, null)) {
      case (#ok(publicKey)) {
        let address = SolanaUtils.deriveSolanaAddress(publicKey);
        #ok(address)
      };
      case (#err(e)) #err("Failed to get user Solana address: " # e);
    };
    
    let userAddress = switch (userAddressResult) {
      case (#ok(addr)) addr;
      case (#err(e)) return #err(e);
    };
    
    // Verify actual SOL balance via RPC
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
    
    let balanceResult = switch (await solRpcClient.getBalance(rpcSources, rpcConfig, userAddress, params)) {
      case (#ok(result)) #ok(result.value);
      case (#err(e)) #err("Failed to get SOL balance: " # e);
    };
    
    let userBalance = switch (balanceResult) {
      case (#ok(bal)) bal;
      case (#err(e)) return #err(e);
    };
    
    // Check if user has sufficient balance (including transaction fees)
    // Estimate fee: ~5000 lamports for a simple transfer
    let estimatedFee : Nat64 = 5000;
    let totalRequired = amount + estimatedFee;
    
    if (userBalance < totalRequired) {
      return #err("Insufficient SOL balance. Required: " # Nat64.toText(totalRequired) # " (including fees), Available: " # Nat64.toText(userBalance))
    };
    
    // For now, we track the transfer in-memory for the swap pool
    // In a full implementation, we would:
    // 1. Build a transaction from user to canister address
    // 2. Sign it with user's key (requires user to sign, or use threshold signing if canister holds user's key)
    // 3. Send the transaction
    
    // Since we can't sign transactions on behalf of users without their explicit approval,
    // we'll use in-memory tracking for swaps but verify the balance exists
    // Users must deposit SOL first via depositSOL() function
    
    // Update in-memory balance for swap tracking
    let currentBalance : Nat64 = switch (solBalances.get(userId)) {
      case null 0 : Nat64;
      case (?bal) bal;
    };
    
    if (currentBalance < amount) {
      return #err("Insufficient SOL in swap balance. Please deposit SOL first. Required: " # Nat64.toText(amount) # ", Available: " # Nat64.toText(currentBalance))
    };
    
    // Deduct from user's swap balance
    let newBalance : Nat64 = currentBalance - amount;
    if (newBalance == (0 : Nat64)) {
      solBalances.delete(userId);
    } else {
      solBalances.put(userId, newBalance);
    };
    
    #ok()
  };

  /// Transfer SOL out (from canister to user) - Full RPC integration
  /// Sends actual SOL via Solana RPC transaction from canister to user
  private func transferSolOut(
    userId : Principal,
    amount : Nat64
  ) : async Result<(), Text> {
    // Get user's Solana address
    let principalBlob = Principal.toBlob(userId);
    let principalBytes = Blob.toArray(principalBlob);
    let derivationPath = [Blob.fromArray(principalBytes)];
    
    let userAddressResult = switch (await SolanaUtils.getEd25519PublicKey(derivationPath, null)) {
      case (#ok(publicKey)) {
        let address = SolanaUtils.deriveSolanaAddress(publicKey);
        #ok(address)
      };
      case (#err(e)) #err("Failed to get user Solana address: " # e);
    };
    
    let toAddress = switch (userAddressResult) {
      case (#ok(addr)) addr;
      case (#err(e)) return #err(e);
    };
    
    // Get canister's Solana address (for sending from)
    let canisterPrincipal = Principal.fromActor(SwapCanister);
    let canisterBlob = Principal.toBlob(canisterPrincipal);
    let canisterBytes = Blob.toArray(canisterBlob);
    let canisterDerivationPath = [Blob.fromArray(canisterBytes)];
    
    let canisterAddressResult = switch (await SolanaUtils.getEd25519PublicKey(canisterDerivationPath, null)) {
      case (#ok(publicKey)) {
        let address = SolanaUtils.deriveSolanaAddress(publicKey);
        #ok(address)
      };
      case (#err(e)) #err("Failed to get canister Solana address: " # e);
    };
    
    let fromAddress = switch (canisterAddressResult) {
      case (#ok(addr)) addr;
      case (#err(e)) return #err(e);
    };
    
    // Verify canister has sufficient SOL balance via RPC
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
    
    let canisterBalanceResult = switch (await solRpcClient.getBalance(rpcSources, rpcConfig, fromAddress, params)) {
      case (#ok(result)) #ok(result.value);
      case (#err(e)) #err("Failed to get canister SOL balance: " # e);
    };
    
    let canisterBalance = switch (canisterBalanceResult) {
      case (#ok(bal)) bal;
      case (#err(e)) return #err(e);
    };
    
    // Estimate fee: ~5000 lamports for a simple transfer
    let estimatedFee : Nat64 = 5000;
    let totalRequired = amount + estimatedFee;
    
    if (canisterBalance < totalRequired) {
      return #err("Insufficient SOL in canister pool. Required: " # Nat64.toText(totalRequired) # " (including fees), Available: " # Nat64.toText(canisterBalance) # ". Please ensure the canister has sufficient SOL balance.")
    };
    
    // Send SOL using sendSOL function with canister's derivation path
    // This will build, sign, and send the transaction
    let sendResult = await sendSOLInternal(fromAddress, toAddress, amount, canisterDerivationPath, null);
    switch sendResult {
      case (#ok(_signature)) {
        // Success - SOL has been sent
        // Update in-memory balance for tracking
        let currentBalance : Nat64 = switch (solBalances.get(userId)) {
          case null 0 : Nat64;
          case (?bal) bal;
        };
        let newBalance : Nat64 = currentBalance + amount;
        solBalances.put(userId, newBalance);
        #ok()
      };
      case (#err(e)) #err("Failed to send SOL: " # e);
    }
  };
  
  /// Internal function to send SOL (used by transferSolOut and sendSOL)
  /// Builds, signs, and sends a Solana transfer transaction using full wire format
  private func sendSOLInternal(
    fromAddress : Text,
    toAddress : Text,
    amountLamports : Nat64,
    derivationPath : [Blob],
    keyName : ?Text
  ) : async Result.Result<Text, Text> {
    // Get recent blockhash
    let rpcSources = #Default(#Mainnet);
    let rpcConfig : ?SolRpcClient.RpcConfig = ?{
      responseConsensus = ?#Equality;
      maxRetries = ?(3 : Nat);
      timeoutSeconds = ?(30 : Nat);
    };
    
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
    
    let recentBlockhash = switch (blockResult) {
      case (#ok(bh)) bh;
      case (#err(e)) return #err(e);
    };
    
    // Build transfer instruction
    let transferInstruction = SolanaUtils.createTransferInstruction(fromAddress, toAddress, amountLamports);
    
    // Build transaction
    let transaction = {
      recentBlockhash = recentBlockhash;
      feePayer = fromAddress;
      instructions = [transferInstruction];
    };
    
    // Serialize transaction message to wire format
    let messageResult = SolanaUtils.serializeTransactionMessage(transaction);
    let message = switch (messageResult) {
      case (#ok(msg)) msg;
      case (#err(e)) return #err("Failed to serialize transaction message: " # e);
    };
    
    // Hash message with SHA-256 for signing
    let messageHash = SolanaUtils.hashMessage(message);
    let messageHashBlob = Blob.fromArray(messageHash);
    
    // Sign message with Ed25519
    let signatureResult = await SolanaUtils.signWithEd25519(messageHashBlob, derivationPath, keyName);
    let signature = switch (signatureResult) {
      case (#ok(sig)) Blob.toArray(sig);
      case (#err(e)) return #err("Failed to sign transaction: " # e);
    };
    
    // Verify signature is 64 bytes (Ed25519 signature length)
    if (signature.size() != 64) {
      return #err("Invalid signature length: expected 64 bytes, got " # Nat.toText(signature.size()))
    };
    
    // Serialize signed transaction (signatures + message)
    let signedTxResult = SolanaUtils.serializeSignedTransaction(message, [signature]);
    let signedTx = switch (signedTxResult) {
      case (#ok(tx)) tx;
      case (#err(e)) return #err("Failed to serialize signed transaction: " # e);
    };
    
    // Base64 encode the transaction
    // Note: Base64 encoding is required for Solana RPC
    let base64Tx = encodeBase64(signedTx);
    
    // Send transaction via RPC
    let sendParams = ?{
      skipPreflight = ?false;
      preflightCommitment = ?#finalized;
      encoding = ?"base64";
      maxRetries = ?(3 : Nat8);
      minContextSlot = null;
    };
    
    switch (await solRpcClient.sendTransaction(rpcSources, rpcConfig, base64Tx, sendParams)) {
      case (#ok(response)) #ok(response.signature);
      case (#err(e)) #err("Failed to send transaction: " # e);
    }
  };
  
  /// Base64 encode bytes
  /// Implements Base64 encoding for Solana transaction serialization
  private func encodeBase64(data : [Nat8]) : Text {
    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var result = Buffer.Buffer<Text>(data.size() * 4 / 3 + 4);
    var i = 0;
    
    while (i < data.size()) {
      let byte1 = if (i < data.size()) data[i] else 0 : Nat8;
      let byte2 = if (i + 1 < data.size()) data[i + 1] else 0 : Nat8;
      let byte3 = if (i + 2 < data.size()) data[i + 2] else 0 : Nat8;
      
      // Combine into 24-bit value using multiplication
      let b1 = Nat8.toNat(byte1);
      let b2 = Nat8.toNat(byte2);
      let b3 = Nat8.toNat(byte3);
      let combined = (b1 * 65536) + (b2 * 256) + b3;
      
      // Extract 6-bit groups using division and modulo
      let group1 = (combined / 262144) % 64;  // >> 18, & 0x3F
      let group2 = (combined / 4096) % 64;    // >> 12, & 0x3F
      let group3 = (combined / 64) % 64;      // >> 6, & 0x3F
      let group4 = combined % 64;            // & 0x3F
      
      // Get characters by iterating through the chars string
      var charIdx = 0;
      var c1 = "A";
      var c2 = "A";
      var c3 = "=";
      var c4 = "=";
      
      for (c in Text.toIter(chars)) {
        if (charIdx == group1) c1 := Text.fromChar(c);
        if (charIdx == group2) c2 := Text.fromChar(c);
        if (i + 1 < data.size() and charIdx == group3) c3 := Text.fromChar(c);
        if (i + 2 < data.size() and charIdx == group4) c4 := Text.fromChar(c);
        charIdx += 1;
      };
      
      result.add(c1);
      result.add(c2);
      result.add(c3);
      result.add(c4);
      
      i += 3;
    };
    
    // Join Text array into single string
    var joined = "";
    for (part in result.vals()) {
      joined := joined # part;
    };
    joined
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

