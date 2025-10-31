import Types "../shared/Types";

module {
  public type ChainKeyToken = {
    #ckBTC;
    #ckETH;
    #ICP;
  };

  public type SwapPool = {
    tokenA : ChainKeyToken;
    tokenB : ChainKeyToken;
    reserveA : Nat64;
    reserveB : Nat64;
    kLast : Nat;
  };

  public type SwapRecord = {
    id : Nat64;
    user : Principal;
    tokenIn : ChainKeyToken;
    tokenOut : ChainKeyToken;
    amountIn : Nat64;
    amountOut : Nat64;
    timestamp : Nat64;
  };

  public type SwapQuote = {
    amountOut : Nat64;
    priceImpact : Float;
    fee : Nat64;
  };

  public type SwapResult = {
    txIndex : Nat;
    amountOut : Nat64;
    priceImpact : Float;
  };

  public type Result<Ok, Err> = Types.Result<Ok, Err>;
};

