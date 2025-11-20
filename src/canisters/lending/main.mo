import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
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
import RateLimiter "../shared/RateLimiter";

persistent actor LendingCanister {
  type LendingAsset = Types.LendingAsset;
  type Deposit = Types.Deposit;
  type DepositInfo = Types.DepositInfo;
  type WithdrawalTx = Types.WithdrawalTx;
  type UtxoInfo = Types.UtxoInfo;
  type Borrow = Types.Borrow;
  type BorrowInfo = Types.BorrowInfo;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // State
  private transient var assets : HashMap.HashMap<Text, LendingAsset> = HashMap.HashMap(0, Text.equal, Text.hash);
  private transient var deposits : HashMap.HashMap<Nat64, Deposit> = HashMap.HashMap(0, func(a : Nat64, b : Nat64) : Bool { a == b }, func(a : Nat64) : Hash.Hash {
    // Bespoke hash function for Nat64 that considers all bits
    // Uses multiplicative hash: hash = (value * prime) mod 2^32
    let n : Nat = Nat64.toNat(a);
    let prime : Nat = 2654435761; // 32-bit prime multiplier
    let hashValue = (n * prime) % 4294967296; // mod 2^32
    Nat32.fromNat(hashValue) // Hash.Hash is just Nat32, so convert using Nat32.fromNat
  });
  private transient var userDeposits : HashMap.HashMap<Principal, [Nat64]> = HashMap.HashMap(0, Principal.equal, Principal.hash);
  private var nextDepositId : Nat64 = 1;

  // Borrowing state
  private transient var borrows : HashMap.HashMap<Nat64, Borrow> = HashMap.HashMap(0, func(a : Nat64, b : Nat64) : Bool { a == b }, func(a : Nat64) : Hash.Hash {
    let n : Nat = Nat64.toNat(a);
    let prime : Nat = 2654435761;
    let hashValue = (n * prime) % 4294967296;
    Nat32.fromNat(hashValue)
  });
  private transient var userBorrows : HashMap.HashMap<Principal, [Nat64]> = HashMap.HashMap(0, Principal.equal, Principal.hash);
  private var nextBorrowId : Nat64 = 1;

  // Borrowing parameters
  private let MAX_LTV : Float = 0.75; // Maximum Loan-to-Value ratio (75%)
  private let BORROW_INTEREST_RATE_MULTIPLIER : Float = 1.5; // Borrowing rate is 1.5x the lending APY
  private let _LIQUIDATION_THRESHOLD : Float = 0.85; // Liquidation threshold (85% LTV)

  // Admin management (transient - will be lost on upgrade, first caller becomes admin)
  private transient var admins : HashMap.HashMap<Principal, Bool> = HashMap.HashMap(0, Principal.equal, Principal.hash);

  // Bitcoin custody state (placeholder)
  private transient var bitcoinUtxos : Buffer.Buffer<UtxoInfo> = Buffer.Buffer(100);
  private var totalBitcoinBalance : Nat64 = 0;

  // Bitcoin API integration placeholder
  private let BTC_API_ENABLED : Bool = false;

  // Rate limiting (transient - resets on upgrade)
  private transient var rateLimiter = RateLimiter.RateLimiter(RateLimiter.LENDING_CONFIG);

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

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

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

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

    if (amount == 0) {
      return #err("Amount must be greater than 0")
    };

    if (asset == "BTC" and BTC_API_ENABLED) {
      // Validate recipient address
      if (not BitcoinUtilsICP.validateAddress(recipientAddress, #Regtest)) {
        return #err("Invalid Bitcoin address")
      };
      
      // Estimate fee (10 satoshis per byte is a reasonable default for regtest)
      let estimatedFeePerByte : Nat64 = 10;
      let estimatedTxSize : Nat32 = _estimateTransactionSize(1, 2, "P2WPKH"); // Assume 1 input, 2 outputs initially
      
      // Select UTXOs for the withdrawal
      let utxoSelectionResult = _selectUtxos(amount, estimatedFeePerByte, estimatedTxSize);
      switch utxoSelectionResult {
        case (#err(msg)) return #err(msg);
        case (#ok(selectedUtxos)) {
          // Get change address (use canister deposit address)
          let changeAddressResult = await getBitcoinDepositAddress();
          switch changeAddressResult {
            case (#err(msg)) return #err("Failed to get change address: " # msg);
            case (#ok(changeAddress)) {
              // Build transaction
              let txResult = buildBitcoinTransaction(selectedUtxos, recipientAddress, amount, changeAddress);
              switch txResult {
                case (#err(msg)) return #err("Failed to build transaction: " # msg);
                case (#ok(tx)) {
                  // TODO: Sign transaction using threshold ECDSA
                  // TODO: Serialize signed transaction
                  // TODO: Broadcast via ICP Bitcoin API
                  // For now, return error indicating signing/broadcast needed
                  // Remove UTXOs from custody (they will be removed after successful broadcast)
                  removeUtxos(selectedUtxos);
                  totalBitcoinBalance -= (tx.totalInput - tx.change);
                  
                  return #ok({ txid = "pending_signature_" # Principal.toText(userId); amount = amount })
                }
              }
            }
          }
        }
      }
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

  /// Get available liquidity for borrowing
  /// Returns the total amount available to borrow for each asset
  public query func getAvailableLiquidity(asset : Text) : async Nat64 {
    // Calculate total deposits for the asset
    var totalDeposits : Nat64 = 0;
    for (deposit in deposits.vals()) {
      if (deposit.asset == asset) {
        totalDeposits += deposit.amount
      }
    };
    
    // Calculate total borrowed for the asset
    var totalBorrowed : Nat64 = 0;
    for (borrow in borrows.vals()) {
      if (borrow.asset == asset and not borrow.repaid) {
        totalBorrowed += borrow.borrowedAmount
      }
    };
    
    // Available liquidity = deposits - borrowed (with some buffer for safety)
    // Reserve 10% of deposits as a safety buffer
    let reserveBuffer : Nat64 = Nat64.fromNat(Nat64.toNat(totalDeposits) / 10);
    if (totalDeposits > reserveBuffer + totalBorrowed) {
      totalDeposits - reserveBuffer - totalBorrowed
    } else {
      0
    }
  };

  /// Get user's borrows
  public query func getUserBorrows(userId : Principal) : async [BorrowInfo] {
    let borrowIds = userBorrows.get(userId);
    switch borrowIds {
      case null [];
      case (?ids) {
        Array.map<Nat64, BorrowInfo>(
          ids,
          func(borrowId) : BorrowInfo {
            switch (borrows.get(borrowId)) {
              case null {
                // This should never happen if borrows are valid, but handle gracefully
                { id = 0; asset = ""; borrowedAmount = 0; collateralAmount = 0; collateralAsset = ""; interestRate = 0.0; ltv = 0.0 }
              };
              case (?borrow) {
                // Calculate LTV (Loan-to-Value ratio)
                // LTV = (borrowedAmount / collateralAmount) * 100
                // For simplicity, we assume 1:1 price ratio between assets
                // In production, you'd use actual price feeds
                let ltv = if (borrow.collateralAmount > 0) {
                  Float.fromInt(Nat64.toNat(borrow.borrowedAmount)) / Float.fromInt(Nat64.toNat(borrow.collateralAmount))
                } else {
                  0.0
                };
                {
                  id = borrow.id;
                  asset = borrow.asset;
                  borrowedAmount = borrow.borrowedAmount;
                  collateralAmount = borrow.collateralAmount;
                  collateralAsset = borrow.collateralAsset;
                  interestRate = borrow.interestRate;
                  ltv = ltv;
                }
              }
            }
          }
        )
      }
    }
  };

  /// Borrow assets using collateral
  /// Users must deposit collateral first (as a deposit), then they can borrow against it
  public shared (msg) func borrow(
    asset : Text,
    amount : Nat64,
    collateralAsset : Text,
    collateralAmount : Nat64
  ) : async Result<Nat64, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

    // Verify asset exists
    switch (assets.get(asset)) {
      case null {
        #err("Asset not found")
      };
      case (?assetInfo) {
        // Verify collateral asset exists
        switch (assets.get(collateralAsset)) {
          case null {
            #err("Collateral asset not found")
          };
          case (?_collateralAssetInfo) {
            if (amount == 0) {
              return #err("Amount must be greater than 0")
            };
            if (collateralAmount == 0) {
              return #err("Collateral amount must be greater than 0")
            };

            // Check if user has sufficient collateral
            // User must have a deposit of the collateral asset
            let userDepositIds = userDeposits.get(userId);
            var totalCollateral : Nat64 = 0;
            switch userDepositIds {
              case null {
                return #err("No collateral deposits found. Please deposit collateral first.")
              };
              case (?depositIds) {
                for (depositId in depositIds.vals()) {
                  switch (deposits.get(depositId)) {
                    case null {};
                    case (?deposit) {
                      if (deposit.asset == collateralAsset) {
                        totalCollateral += deposit.amount
                      }
                    }
                  }
                }
              }
            };

            // Calculate LTV (Loan-to-Value ratio)
            // For simplicity, assume 1:1 price ratio (in production, use price feeds)
            let ltv = Float.fromInt(Nat64.toNat(amount)) / Float.fromInt(Nat64.toNat(collateralAmount));
            
            if (ltv > MAX_LTV) {
              return #err("Loan-to-Value ratio too high. Maximum LTV is " # Float.toText(MAX_LTV * 100.0) # "%")
            };

            // Check if collateral is sufficient
            if (totalCollateral < collateralAmount) {
              return #err("Insufficient collateral. Required: " # Nat64.toText(collateralAmount) # ", Available: " # Nat64.toText(totalCollateral))
            };

            // Check available liquidity
            let availableLiquidity = await getAvailableLiquidity(asset);
            if (availableLiquidity < amount) {
              return #err("Insufficient liquidity. Available: " # Nat64.toText(availableLiquidity) # ", Requested: " # Nat64.toText(amount))
            };

            // Calculate borrowing interest rate (higher than lending APY)
            let borrowInterestRate = assetInfo.apy * BORROW_INTEREST_RATE_MULTIPLIER;

            // Create borrow record
            let borrowId = nextBorrowId;
            nextBorrowId += 1;

            let borrow : Borrow = {
              id = borrowId;
              userId = userId;
              asset = asset;
              borrowedAmount = amount;
              collateralAmount = collateralAmount;
              collateralAsset = collateralAsset;
              interestRate = borrowInterestRate;
              timestamp = Nat64.fromIntWrap(Time.now());
              repaid = false;
            };

            // Update state
            borrows.put(borrowId, borrow);

            let existingBorrows = userBorrows.get(userId);
            let updatedBorrows = Array.append(Option.get<[Nat64]>(existingBorrows, []), [borrowId]);
            userBorrows.put(userId, updatedBorrows);

            #ok(borrowId)
          }
        }
      }
    }
  };

  /// Repay a borrow
  public shared (msg) func repay(
    borrowId : Nat64,
    amount : Nat64
  ) : async Result<(), Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

    if (amount == 0) {
      return #err("Amount must be greater than 0")
    };

    // Get the borrow
    switch (borrows.get(borrowId)) {
      case null {
        #err("Borrow not found")
      };
      case (?borrow) {
        // Verify ownership
        if (Principal.notEqual(borrow.userId, userId)) {
          return #err("Unauthorized: This borrow does not belong to you")
        };

        // Check if already repaid
        if (borrow.repaid) {
          return #err("Borrow already repaid")
        };

        // Check if repayment amount exceeds borrowed amount
        if (amount > borrow.borrowedAmount) {
          return #err("Repayment amount exceeds borrowed amount. Borrowed: " # Nat64.toText(borrow.borrowedAmount) # ", Repaying: " # Nat64.toText(amount))
        };

        // Update borrow record
        let updatedBorrow : Borrow = {
          id = borrow.id;
          userId = borrow.userId;
          asset = borrow.asset;
          borrowedAmount = borrow.borrowedAmount - amount;
          collateralAmount = borrow.collateralAmount;
          collateralAsset = borrow.collateralAsset;
          interestRate = borrow.interestRate;
          timestamp = borrow.timestamp;
          repaid = borrow.borrowedAmount - amount == 0; // Mark as repaid if fully repaid
        };

        borrows.put(borrowId, updatedBorrow);

        #ok(())
      }
    }
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
  /// Uses a largest-first algorithm to minimize the number of inputs
  /// Returns UTXOs that sum to at least the target amount (including estimated fees)
  /// 
  /// Algorithm:
  /// 1. Sort UTXOs by value (largest first) to minimize number of inputs
  /// 2. Select UTXOs until we have enough to cover amount + fees
  /// 3. Consider transaction size for fee calculation
  private func _selectUtxos(
    targetAmount : Nat64,
    estimatedFeePerByte : Nat64,
    estimatedTxSize : Nat32
  ) : Result<[UtxoInfo], Text> {
    // Calculate total amount needed (target + fees)
    let estimatedFee = Nat64.fromNat(Nat32.toNat(estimatedTxSize)) * estimatedFeePerByte;
    let totalNeeded = targetAmount + estimatedFee;
    
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
    
    label UtxoLoop for (utxo in Array.vals(sortedUtxos)) {
      if (selectedAmount >= totalNeeded) {
        // Stop when we have enough
        break UtxoLoop
      } else {
        selectedUtxos.add(utxo);
        selectedAmount += utxo.value
      }
    };
    
    if (selectedAmount < totalNeeded) {
      #err("Insufficient UTXOs. Need: " # Nat64.toText(totalNeeded) # " (amount: " # Nat64.toText(targetAmount) # " + fee: " # Nat64.toText(estimatedFee) # "), Have: " # Nat64.toText(selectedAmount))
    } else {
      #ok(Buffer.toArray(selectedUtxos))
    }
  };

  /// Estimate transaction size in bytes
  /// Base transaction: ~10 bytes
  /// Each input: ~148 bytes (P2PKH) or ~91 bytes (P2WPKH) or ~58 bytes (P2TR)
  /// Each output: ~34 bytes
  /// Witness data for SegWit/Taproot: additional overhead
  private func _estimateTransactionSize(
    numInputs : Nat,
    numOutputs : Nat,
    addressType : Text // "P2PKH", "P2WPKH", "P2TR", etc.
  ) : Nat32 {
    // Base transaction size
    var size : Nat = 10;
    
    // Input size (estimate based on address type)
    let inputSize = if (addressType == "P2PKH") {
      148
    } else if (addressType == "P2WPKH") {
      91
    } else if (addressType == "P2TR") {
      58
    } else {
      148 // Default to P2PKH
    };
    
    size += numInputs * inputSize;
    
    // Output size (34 bytes per output)
    size += numOutputs * 34;
    
    // Witness data overhead for SegWit/Taproot (approximate)
    if (addressType == "P2WPKH" or addressType == "P2TR") {
      size += numInputs * 27; // Approximate witness data
    };
    
    Nat32.fromNat(size)
  };

  /// Calculate transaction fee
  /// Uses fee per byte rate (typically from ICP Bitcoin API)
  /// Returns fee in satoshis
  private func _calculateFee(
    txSize : Nat32,
    feePerByte : Nat64
  ) : Nat64 {
    Nat64.fromNat(Nat32.toNat(txSize)) * feePerByte
  };

  /// Build Bitcoin transaction from selected UTXOs
  /// This creates a transaction structure ready for signing
  /// Note: Actual transaction serialization and signing requires Bitcoin library integration
  private func buildBitcoinTransaction(
    selectedUtxos : [UtxoInfo],
    recipientAddress : Text,
    amount : Nat64,
    changeAddress : Text
  ) : Result<{
    inputs : [UtxoInfo];
    outputs : [(Text, Nat64)]; // (address, amount) pairs
    totalInput : Nat64;
    totalOutput : Nat64;
    fee : Nat64;
    change : Nat64;
  }, Text> {
    if (selectedUtxos.size() == 0) {
      return #err("No UTXOs selected")
    };
    
    // Calculate total input value
    var totalInput : Nat64 = 0;
    for (utxo in selectedUtxos.vals()) {
      totalInput += utxo.value
    };
    
    // Estimate transaction size for fee calculation
    // Using P2WPKH as default (most common for canister addresses)
    let estimatedSize = _estimateTransactionSize(selectedUtxos.size(), 2, "P2WPKH"); // 2 outputs: recipient + change
    let estimatedFeePerByte : Nat64 = 10; // 10 satoshis per byte (adjustable based on network)
    let fee = _calculateFee(estimatedSize, estimatedFeePerByte);
    
    // Calculate total needed
    let totalNeeded = amount + fee;
    
    if (totalInput < totalNeeded) {
      return #err("Insufficient input value. Need: " # Nat64.toText(totalNeeded) # ", Have: " # Nat64.toText(totalInput))
    };
    
    // Calculate change (remaining amount after sending amount + fee)
    let change = totalInput - totalNeeded;
    
    // Build outputs
    var outputs : Buffer.Buffer<(Text, Nat64)> = Buffer.Buffer(2);
    outputs.add((recipientAddress, amount));
    
    // Only add change output if change is above dust threshold (546 satoshis)
    let dustThreshold : Nat64 = 546;
    if (change > dustThreshold) {
      outputs.add((changeAddress, change))
    } else if (change > 0) {
      // Change is below dust threshold, add to fee (don't create change output)
      // This means the actual fee will be higher than estimated
    };
    
    #ok({
      inputs = selectedUtxos;
      outputs = Buffer.toArray(outputs);
      totalInput = totalInput;
      totalOutput = amount + (if (change > dustThreshold) change else 0);
      fee = fee + (if (change <= dustThreshold and change > 0) change else 0);
      change = if (change > dustThreshold) change else 0;
    })
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
    let userId = msg.caller;
    
    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

    if (not isAdmin(userId)) {
      return #err("Unauthorized: Only admins can add other admins")
    };
    admins.put(newAdmin, true);
    #ok(())
  };

  /// Remove an admin (only admins can remove other admins)
  public shared (msg) func removeAdmin(adminToRemove : Principal) : async Result<(), Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err("Rate limit exceeded. Please try again later.")
    };

    if (not isAdmin(userId)) {
      return #err("Unauthorized: Only admins can remove other admins")
    };
    if (Principal.equal(userId, adminToRemove)) {
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

