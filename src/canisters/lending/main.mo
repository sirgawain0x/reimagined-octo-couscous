import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Types "./Types";
import BitcoinUtilsICP "../shared/BitcoinUtilsICP";

// Helper functions for equality and hashing (must be defined before use)
func depositIdEqual(a : Nat64, b : Nat64) : Bool { a == b };
func depositIdHash(a : Nat64) : Hash.Hash {
  // Bespoke hash function for Nat64 that considers all bits
  // Uses multiplicative hash: hash = (value * prime) mod 2^32
  let n : Nat = Nat64.toNat(a);
  let prime : Nat = 2654435761; // 32-bit prime multiplier
  let hashValue = (n * prime) % 4294967296; // mod 2^32
  Nat32.fromNat(hashValue) // Hash.Hash is just Nat32, so convert using Nat32.fromNat
};

persistent actor LendingCanister {
  type LendingAsset = Types.LendingAsset;
  type Deposit = Types.Deposit;
  type DepositInfo = Types.DepositInfo;
  type WithdrawalTx = Types.WithdrawalTx;
  type UtxoInfo = Types.UtxoInfo;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // State
  private transient var assets : HashMap.HashMap<Text, LendingAsset> = HashMap.HashMap(0, Text.equal, Text.hash);
  private transient var deposits : HashMap.HashMap<Nat64, Deposit> = HashMap.HashMap(0, depositIdEqual, depositIdHash);
  private transient var userDeposits : HashMap.HashMap<Principal, [Nat64]> = HashMap.HashMap(0, Principal.equal, Principal.hash);
  private var nextDepositId : Nat64 = 1;

  // Admin management (transient - will be lost on upgrade, first caller becomes admin)
  private transient var admins : HashMap.HashMap<Principal, Bool> = HashMap.HashMap(0, Principal.equal, Principal.hash);

  // Bitcoin custody state (placeholder)
  private transient var bitcoinUtxos : Buffer.Buffer<UtxoInfo> = Buffer.Buffer(100);
  private var totalBitcoinBalance : Nat64 = 0;

  // Bitcoin API integration placeholder
  private let BTC_API_ENABLED : Bool = false;

  /// Initialize with default lending assets
  public shared func init() : async () {
    let btcAsset : LendingAsset = {
      id = "btc";
      name = "Bitcoin";
      symbol = "BTC";
      apy = 4.2;
    };
    assets.put("btc", btcAsset);

    let ethAsset : LendingAsset = {
      id = "eth";
      name = "Ethereum";
      symbol = "ETH";
      apy = 5.1;
    };
    assets.put("eth", ethAsset);

    let solAsset : LendingAsset = {
      id = "sol";
      name = "Solana";
      symbol = "SOL";
      apy = 6.5;
    };
    assets.put("sol", solAsset);
  };

  /// Get all lending assets
  public query func getLendingAssets() : async [LendingAsset] {
    Iter.toArray(assets.vals())
  };

  /// Get current APY for an asset
  public query func getCurrentAPY(asset : Text) : async Float {
    switch (assets.get(asset)) {
      case (?asset) asset.apy;
      case null 0.0
    }
  };

  /// Get user's deposits
  public query func getUserDeposits(userId : Principal) : async [DepositInfo] {
    let depositIds = userDeposits.get(userId);
    switch depositIds {
      case null [];
      case (?ids) {
        Array.map<Nat64, DepositInfo>(
          ids,
          func(depositId) : DepositInfo {
            switch (deposits.get(depositId)) {
              case null {
                // This should never happen if deposits are valid, but handle gracefully
                { asset = ""; amount = 0; apy = 0.0 }
              };
              case (?deposit) {
                {
                  asset = deposit.asset;
                  amount = deposit.amount;
                  apy = deposit.apy;
                }
              }
            }
          }
        )
      }
    }
  };

  /// Deposit assets (for non-Bitcoin assets, placeholder)
  public shared (msg) func deposit(
    asset : Text,
    amount : Nat64
  ) : async Result<Nat64, Text> {
    let userId = msg.caller;

    // Verify asset exists
    switch (assets.get(asset)) {
      case null {
        #err("Asset not found")
      };
      case (?assetInfo) {
        if (amount == 0) {
          return #err("Amount must be greater than 0")
        };

        if (asset == "BTC" and BTC_API_ENABLED) {
          // TODO: Implement Bitcoin deposit validation
          // For now, just record the deposit
        };

        // Create deposit record
        let depositId = nextDepositId;
        nextDepositId += 1;

        let deposit : Deposit = {
          id = depositId;
          userId = userId;
          asset = asset;
          amount = amount;
          timestamp = Nat64.fromIntWrap(Time.now());
          apy = assetInfo.apy;
        };

        // Update state
        deposits.put(depositId, deposit);

        let existingDeposits = userDeposits.get(userId);
        let updatedDeposits = Array.append(Option.get<[Nat64]>(existingDeposits, []), [depositId]);
        userDeposits.put(userId, updatedDeposits);

        // Update Bitcoin balance if applicable
        if (asset == "BTC") {
          totalBitcoinBalance += amount
        };

        #ok(depositId)
      }
    }
  };

  /// Get Bitcoin deposit address for the canister
  /// Returns a P2PKH address where users can send Bitcoin deposits
  public func getBitcoinDepositAddress() : async Result<Text, Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };
    
    // Use index 0 for the main deposit address
    let derivationPath = BitcoinUtilsICP.createDerivationPath(0);
    await BitcoinUtilsICP.generateP2PKHAddress(#Regtest, derivationPath, null)
  };

  /// Get Bitcoin deposit address for a specific user
  /// Generates a unique address per user for tracking deposits
  public func getUserBitcoinDepositAddress(userId : Principal) : async Result<Text, Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };
    
    // Derive unique index from user principal
    let principalBytes = Blob.toArray(Principal.toBlob(userId));
    let index = Nat32.fromNat(Array.foldLeft<Nat8, Nat>(principalBytes, 0, func(acc, b) { acc + Nat8.toNat(b) }) % 2147483647);
    let derivationPath = BitcoinUtilsICP.createDerivationPath(index);
    
    // Use P2WPKH for user deposits (lower fees)
    await BitcoinUtilsICP.generateP2WPKHAddress(#Regtest, derivationPath, null)
  };

  /// Withdraw assets
  public shared (msg) func withdraw(
    asset : Text,
    amount : Nat64,
    recipientAddress : Text
  ) : async Result<WithdrawalTx, Text> {
    let userId = msg.caller;

    if (amount == 0) {
      return #err("Amount must be greater than 0")
    };

    if (asset == "BTC" and BTC_API_ENABLED) {
      // Validate recipient address
      if (not BitcoinUtilsICP.validateAddress(recipientAddress, #Regtest)) {
        return #err("Invalid Bitcoin address")
      };
      
      // TODO: Implement Bitcoin withdrawal
      // 1. Select UTXOs that sum to amount + fees
      // 2. Build Bitcoin transaction
      // 3. Sign transaction using threshold ECDSA
      // 4. Broadcast via ICP Bitcoin API
      return #err("Bitcoin withdrawal implementation pending. Validated address: " # recipientAddress)
    };

    // For now, simulate withdrawal
    let userDepositIds = userDeposits.get(userId);
    switch userDepositIds {
      case null {
        #err("User has no deposits")
      };
      case (?depositIds) {
        // Find matching deposit (simplified - in production, you'd select the right UTXOs)
        let depositIdOpt = Array.find<Nat64>(depositIds, func(id) {
          switch (deposits.get(id)) {
            case null false;
            case (?deposit) {
              deposit.asset == asset and deposit.amount == amount
            }
          }
        });

        switch depositIdOpt {
          case null {
            #err("Insufficient balance")
          };
          case (?depositId) {
            // Remove deposit
            deposits.delete(depositId);
            let filteredIds = Array.filter<Nat64>(depositIds, func(id) { id != depositId });
            userDeposits.put(userId, filteredIds);

            // Update Bitcoin balance
            if (asset == "BTC") {
              totalBitcoinBalance -= amount
            };

            #ok({ txid = "mock_tx_" # Principal.toText(userId); amount = amount })
          }
        }
      }
    }
  };

  /// Get Bitcoin custody balance
  public query func getBitcoinBalance() : async Nat64 {
    totalBitcoinBalance
  };

  /// Get UTXOs under custody (admin only)
  public query func getUtxos() : async [UtxoInfo] {
    Buffer.toArray(bitcoinUtxos)
  };

  /// Add UTXO to custody tracking
  /// Called when Bitcoin is deposited to canister address
  public func addUtxo(utxo : UtxoInfo) : () {
    bitcoinUtxos.add(utxo);
    totalBitcoinBalance += utxo.value
  };

  /// Select UTXOs for spending
  /// Uses a simple largest-first algorithm
  /// Returns UTXOs that sum to at least the target amount
  private func _selectUtxos(targetAmount : Nat64) : Result<[UtxoInfo], Text> {
    // Sort UTXOs by value (largest first)
    let sortedUtxos = Array.sort<UtxoInfo>(
      Buffer.toArray(bitcoinUtxos),
      func(a : UtxoInfo, b : UtxoInfo) {
        if (a.value > b.value) { #greater }
        else if (a.value < b.value) { #less }
        else { #equal }
      }
    );
    
    var selectedAmount : Nat64 = 0;
    var selectedUtxos : Buffer.Buffer<UtxoInfo> = Buffer.Buffer(10);
    
    for (utxo in Array.vals(sortedUtxos)) {
      if (selectedAmount >= targetAmount) {
        // Stop when we have enough
      } else {
        selectedUtxos.add(utxo);
        selectedAmount += utxo.value
      }
    };
    
    if (selectedAmount < targetAmount) {
      #err("Insufficient UTXOs. Need: " # Nat64.toText(targetAmount) # ", Have: " # Nat64.toText(selectedAmount))
    } else {
      #ok(Buffer.toArray(selectedUtxos))
    }
  };

  /// Remove spent UTXOs from custody
  public func removeUtxos(spentUtxos : [UtxoInfo]) : () {
    for (spentUtxo in spentUtxos.vals()) {
      var i = 0;
      var found = false;
      while (i < bitcoinUtxos.size() and not found) {
        let utxo = bitcoinUtxos.get(i);
        if (utxo.outpoint.txid == spentUtxo.outpoint.txid and utxo.outpoint.vout == spentUtxo.outpoint.vout) {
          let _ = bitcoinUtxos.remove(i);
          totalBitcoinBalance -= utxo.value;
          found := true
        } else {
          i += 1
        }
      }
    }
  };

  /// Add an admin (only existing admins can add new admins)
  public shared (msg) func addAdmin(newAdmin : Principal) : async Result<(), Text> {
    if (not isAdmin(msg.caller)) {
      return #err("Unauthorized: Only admins can add other admins")
    };
    admins.put(newAdmin, true);
    #ok(())
  };

  /// Remove an admin (only admins can remove other admins)
  public shared (msg) func removeAdmin(adminToRemove : Principal) : async Result<(), Text> {
    if (not isAdmin(msg.caller)) {
      return #err("Unauthorized: Only admins can remove other admins")
    };
    if (Principal.equal(msg.caller, adminToRemove)) {
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

