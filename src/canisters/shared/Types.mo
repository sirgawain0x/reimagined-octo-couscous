module Types {
  public type Result<Ok, Err> = {
    #ok : Ok;
    #err : Err;
  };

  public type Store = {
    id : Nat32;
    name : Text;
    reward : Float;
    logo : Text;
    url : ?Text;
  };

  public type StoreId = Nat32;

  public type AddStoreRequest = {
    name : Text;
    reward : Float;
    logo : Text;
    url : ?Text;
  };

  public type PurchaseRecord = {
    id : Nat64;
    userId : Principal;
    storeId : Nat32;
    amount : Nat64;
    reward : Nat64;
    timestamp : Nat64;
    claimed : Bool;
  };

  public type PurchaseReceipt = {
    purchaseId : Nat64;
    rewardEarned : Nat64;
  };

  public type BitcoinTx = {
    txid : Text;
    hex : [Nat8];
  };

  public type LendingAsset = {
    id : Text;
    name : Text;
    symbol : Text;
    apy : Float;
  };

  public type Deposit = {
    id : Nat64;
    userId : Principal;
    asset : Text;
    amount : Nat64;
    timestamp : Nat64;
    apy : Float;
  };

  public type DepositInfo = {
    asset : Text;
    amount : Nat64;
    apy : Float;
  };

  public type WithdrawalTx = {
    txid : Text;
    amount : Nat64;
  };

  public type PortfolioAsset = {
    name : Text;
    symbol : Text;
    amount : Nat64;
    value : Float;
  };

  public type Portfolio = {
    totalValue : Float;
    totalRewards : Nat64;
    totalLended : Float;
    assets : [PortfolioAsset];
  };

  public type UtxoInfo = {
    outpoint : { txid : [Nat8]; vout : Nat32 };
    value : Nat64;
    height : Nat32;
  };
};

