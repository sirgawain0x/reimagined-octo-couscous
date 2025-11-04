import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";

module {
  /// SOL RPC Canister Principal (Mainnet)
  /// Principal: tghme-zyaaa-aaaar-qarca-cai
  private let SOL_RPC_CANISTER_TEXT : Text = "tghme-zyaaa-aaaar-qarca-cai";

  /// Solana Cluster Type
  public type SolanaCluster = {
    #Mainnet;
    #Devnet;
  };

  /// Commitment Level
  public type CommitmentLevel = {
    #finalized;
    #confirmed;
    #processed;
  };

  /// Consensus Strategy
  public type ConsensusStrategy = {
    #Equality;
    #Majority;
    #AtLeast;
    #Quorum;
  };

  /// RPC Sources
  public type RpcSources = {
    #Default : SolanaCluster;
    #Custom : {
      mainnet : [Text];
      devnet : [Text];
    };
  };

  /// RPC Config
  public type RpcConfig = {
    responseConsensus : ?ConsensusStrategy;
    maxRetries : ?Nat;
    timeoutSeconds : ?Nat;
  };

  /// Get Slot Params
  public type GetSlotParams = {
    commitment : ?CommitmentLevel;
    minContextSlot : ?Nat64;
  };

  /// Get Block Params
  public type GetBlockParams = {
    slot : ?Nat64;
    commitment : ?CommitmentLevel;
    encoding : ?Text; // "base58", "base64", "jsonParsed"
    transactionDetails : ?Text; // "full", "signatures", "none"
    maxSupportedTransactionVersion : ?Nat8;
    rewards : ?Bool;
  };

  /// Get Balance Params
  public type GetBalanceParams = {
    commitment : ?CommitmentLevel;
    minContextSlot : ?Nat64;
  };

  /// Get Account Info Params
  public type GetAccountInfoParams = {
    commitment : ?CommitmentLevel;
    encoding : ?Text; // "base58", "base64", "jsonParsed"
    dataSlice : ?{
      offset : Nat;
      length : Nat;
    };
    minContextSlot : ?Nat64;
  };

  /// Send Transaction Params
  public type SendTransactionParams = {
    skipPreflight : ?Bool;
    preflightCommitment : ?CommitmentLevel;
    encoding : ?Text; // "base58", "base64"
    maxRetries : ?Nat8;
    minContextSlot : ?Nat64;
  };

  /// Get Slot Response
  public type GetSlotResponse = {
    slot : Nat64;
  };

  /// Get Balance Response
  public type GetBalanceResponse = {
    value : Nat64; // lamports
  };

  /// Account Info
  public type AccountInfo = {
    data : [Nat8];
    executable : Bool;
    lamports : Nat64;
    owner : Text; // Solana address (base58)
    rentEpoch : ?Nat64;
  };

  /// Get Account Info Response
  public type GetAccountInfoResponse = {
    value : ?AccountInfo;
  };

  /// Send Transaction Response
  public type SendTransactionResponse = {
    signature : Text;
  };

  /// Block Header
  public type BlockHeader = {
    blockhash : Text;
    previousBlockhash : Text;
    parentSlot : Nat64;
    slot : Nat64;
  };

  /// Get Block Response
  public type GetBlockResponse = {
    blockhash : ?Text;
    previousBlockhash : ?Text;
    parentSlot : ?Nat64;
    slot : ?Nat64;
    transactions : ?[Text]; // Transaction signatures or full transactions
    rewards : ?[{
      pubkey : Text;
      lamports : Int;
      postBalance : Nat64;
      rewardType : ?Text;
    }];
  };

  /// SOL RPC Canister Actor Interface
  public type SolRpcCanister = actor {
    getSlot : (
      RpcSources,
      ?RpcConfig,
      ?GetSlotParams
    ) -> async {
      #ok : GetSlotResponse;
      #err : Text;
    };

    getBalance : (
      RpcSources,
      ?RpcConfig,
      Text, // address
      ?GetBalanceParams
    ) -> async {
      #ok : GetBalanceResponse;
      #err : Text;
    };

    getAccountInfo : (
      RpcSources,
      ?RpcConfig,
      Text, // address
      ?GetAccountInfoParams
    ) -> async {
      #ok : GetAccountInfoResponse;
      #err : Text;
    };

    getBlock : (
      RpcSources,
      ?RpcConfig,
      ?GetBlockParams
    ) -> async {
      #ok : GetBlockResponse;
      #err : Text;
    };

    sendTransaction : (
      RpcSources,
      ?RpcConfig,
      Text, // base64 encoded transaction
      ?SendTransactionParams
    ) -> async {
      #ok : SendTransactionResponse;
      #err : Text;
    };

    jsonRequest : (
      RpcSources,
      ?RpcConfig,
      Text, // method
      ?[Text] // params
    ) -> async {
      #ok : Text;
      #err : Text;
    };
  };

  /// Create a SOL RPC client actor
  public func createClient() : SolRpcCanister {
    actor (SOL_RPC_CANISTER_TEXT) : SolRpcCanister;
  };
};

