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
  // Testnet: (to be configured via environment)
  
  // ckBTC actors (will be initialized with actual canister IDs)
  // For now, using placeholder - should be set from environment config
  private let CKBTC_LEDGER_ID : Principal = Principal.fromText("mxzaz-hqaaa-aaaah-aaada-cai"); // Mainnet ledger
  private let CKBTC_MINTER_ID : Principal = Principal.fromText("mqygn-kiaaa-aaaah-aaaqaa-cai"); // Mainnet minter
  
  private let ckbtcLedger = CKBTC.createLedgerActor(CKBTC_LEDGER_ID);
  private let ckbtcMinter = CKBTC.createMinterActor(CKBTC_MINTER_ID);
  
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

            // Update pool reserves (simplified - in production, verify actual token transfers)
            let newReserveA = pool.reserveA + amountIn;
            let newReserveB = pool.reserveB - quote.amountOut;
            
            pools.put(poolId, {
              tokenA = pool.tokenA;
              tokenB = pool.tokenB;
              reserveA = newReserveA;
              reserveB = newReserveB;
              kLast = Nat64.toNat(pool.reserveA) * Nat64.toNat(pool.reserveB);
            });

            // Record swap
            let swapId = nextSwapId;
            nextSwapId += 1;
            
            swaps.add({
              id = swapId;
              user = userId;
              tokenIn = tokenIn;
              tokenOut = getOppositeToken(pool, tokenIn);
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
  };

  /// Get ckBTC balance for user
  public func getCKBTCBalance(userId : Principal) : async Result<Nat, Text> {
    let account : CKBTC.Account = {
      owner = userId;
      subaccount = null;
    };
    await CKBTC.getBalance(ckbtcLedger, account)
  };

  /// Get Bitcoin address for ckBTC deposit
  public func getBTCAddress(userId : Principal) : async Result<Text, Text> {
    await CKBTC.getBTCAddress(ckbtcMinter, ?userId)
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
    let result = await CKBTC.updateBalance(ckbtcMinter, userId);
    switch result {
      case (#err(msg)) #err(msg);
      case (#ok(mintTx)) {
        // Return the minted amount
        #ok(mintTx.amount)
      }
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

    // Retrieve BTC via ckBTC minter
    await CKBTC.retrieveBTC(ckbtcMinter, btcAddress, Nat64.toNat(amount), null)
  };

  /// Get swap history for user
  public query func getSwapHistory(userId : Principal) : async [SwapRecord] {
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
    pools.get(poolId)
  };

  /// Get SOL balance for a Solana address
  public shared (msg) func getSOLBalance(solAddress : Text) : async Result<Nat64, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
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
  public shared (_msg) func getSOLAccountInfo(solAddress : Text) : async Result.Result<?SolRpcClient.AccountInfo, Text> {
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
  public shared (_msg) func getRecentBlockhash() : async Result.Result<Text, Text> {
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
  public shared (_msg) func getSolanaSlot() : async Result.Result<Nat64, Text> {
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

    let recentBlockhash = switch (blockResult) {
      case (#ok(bh)) bh;
      case (#err(e)) return #err(e);
    };

    // 4. Build transaction using jsonRequest (more flexible than wire format)
    // Create a transfer instruction using System Program
    let transferInstruction = SolanaUtils.createTransferInstruction(fromAddress, toAddress, amountLamports);
    
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

