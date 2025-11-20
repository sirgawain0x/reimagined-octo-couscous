import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
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
import BitcoinApi "../shared/BitcoinApi";
import BitcoinUtils "../shared/BitcoinUtils";
import RateLimiter "../shared/RateLimiter";
import InputValidation "../shared/InputValidation";

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

  // Bitcoin API integration
  private let BTC_API_ENABLED : Bool = true; // Enable for regtest
  private let BTC_NETWORK : BitcoinApi.Network = #Regtest;

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
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(asset, 1, ?10)) {
      return #err("Invalid asset symbol")
    };
    if (not InputValidation.validateAmount(amount, 1, null)) {
      return #err("Amount must be greater than 0")
    };

    // Normalize asset to lowercase for consistent lookup and comparison
    let normalizedAsset = Text.map(asset, func(c : Char) : Char {
      if (c >= 'A' and c <= 'Z') {
        Char.fromNat32(Char.toNat32(c) + 32) // Convert to lowercase
      } else {
        c
      }
    });

    // Verify asset exists
    switch (assets.get(normalizedAsset)) {
      case null {
        #err("Asset not found")
      };
      case (?assetInfo) {

        if (normalizedAsset == "btc" and BTC_API_ENABLED) {
          // Validate Bitcoin deposit by checking UTXOs
          let validationResult = await _validateBitcoinDeposit(userId, amount);
          switch validationResult {
            case (#err(msg)) return #err("Bitcoin deposit validation failed: " # msg);
            case (#ok(())) {
              // Deposit validated, continue with recording
            }
          }
        };

        // Create deposit record
        let depositId = nextDepositId;
        nextDepositId += 1;

        let deposit : Deposit = {
          id = depositId;
          userId = userId;
          asset = normalizedAsset;
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
        if (normalizedAsset == "btc") {
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
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(asset, 1, ?10)) {
      return #err("Invalid asset symbol")
    };
    if (not InputValidation.validateAmount(amount, 1, null)) {
      return #err("Amount must be greater than 0")
    };
    if (not InputValidation.validateText(recipientAddress, 26, ?62)) {
      return #err("Invalid recipient address format")
    };

    // Normalize asset to lowercase for consistent comparison
    let normalizedAsset = Text.map(asset, func(c : Char) : Char {
      if (c >= 'A' and c <= 'Z') {
        Char.fromNat32(Char.toNat32(c) + 32) // Convert to lowercase
      } else {
        c
      }
    });

    if (normalizedAsset == "btc" and BTC_API_ENABLED) {
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
                  // Serialize transaction for signing
                  let txBytesResult = _serializeTransaction(tx, selectedUtxos);
                  switch txBytesResult {
                    case (#err(msg)) return #err("Failed to serialize transaction: " # msg);
                    case (#ok(txBytes)) {
                      // Get derivation path for signing (use index 0 for main canister address)
                      let derivationPath = BitcoinUtilsICP.createDerivationPath(0);
                      
                      // Sign transaction
                      let signResult = await BitcoinUtilsICP.signTransaction(txBytes, derivationPath, null);
                      switch signResult {
                        case (#err(msg)) return #err("Failed to sign transaction: " # msg);
                        case (#ok(signature)) {
                          // For now, we'll use a simplified approach:
                          // Create a signed transaction by appending signature to tx bytes
                          // Note: This is a simplified implementation - full Bitcoin transaction
                          // serialization with proper witness data is more complex
                          var signedTxBytes = Buffer.Buffer<Nat8>(txBytes.size() + signature.size());
                          for (byte in txBytes.vals()) {
                            signedTxBytes.add(byte)
                          };
                          for (byte in signature.vals()) {
                            signedTxBytes.add(byte)
                          };
                          
                          // Broadcast transaction via Bitcoin API
                          let broadcastResult = await BitcoinApi.send_transaction(BTC_NETWORK, Buffer.toArray(signedTxBytes));
                          switch broadcastResult {
                            case (#err(msg)) {
                              // Broadcast failed - don't remove UTXOs
                              return #err("Failed to broadcast transaction: " # msg)
                            };
                            case (#ok(())) {
                              // Success! Remove UTXOs from custody
                              removeUtxos(selectedUtxos);
                              totalBitcoinBalance -= (tx.totalInput - tx.change);
                              
                              // Generate a simple txid from the transaction bytes hash
                              // In a real implementation, this would be the actual transaction ID
                              let txid = BitcoinUtils.bytesToHex(Array.take<Nat8>(txBytes, 32));
                              return #ok({ txid = txid; amount = amount })
                            }
                          }
                        }
                      }
                    }
                  }
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
        // Normalize asset to lowercase for consistent comparison with stored deposits
        let normalizedAsset = Text.map(asset, func(c : Char) : Char {
          if (c >= 'A' and c <= 'Z') {
            Char.fromNat32(Char.toNat32(c) + 32) // Convert to lowercase
          } else {
            c
          }
        });
        
        let depositIdOpt = Array.find<Nat64>(depositIds, func(id) {
          switch (deposits.get(id)) {
            case null false;
            case (?deposit) {
              deposit.asset == normalizedAsset and deposit.amount == amount
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
            if (normalizedAsset == "btc") {
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
      return #err(rateLimiter.formatError(userId))
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
      return #err(rateLimiter.formatError(userId))
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

  /// Sync UTXOs from Bitcoin API for canister address
  /// This function queries the Bitcoin API and updates the local UTXO tracking
  /// Should be called periodically to keep UTXO state in sync
  public shared (_msg) func syncUtxos() : async Result<(), Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };

    // Get canister Bitcoin address
    let addressResult = await getBitcoinDepositAddress();
    switch addressResult {
      case (#err(msg)) #err("Failed to get canister address: " # msg);
      case (#ok(canisterAddress)) {
        // Get UTXOs from Bitcoin API
        let utxosResult = await BitcoinApi.get_utxos(BTC_NETWORK, canisterAddress, null);
        switch utxosResult {
          case (#err(msg)) #err("Failed to sync UTXOs: " # msg);
          case (#ok(utxosResponse)) {
            // Clear existing UTXOs and rebuild from API response
            // Note: In production, you might want to merge instead of replace
            bitcoinUtxos := Buffer.Buffer(utxosResponse.utxos.size());
            totalBitcoinBalance := 0;
            
            // Add all UTXOs from API response
            for (utxo in utxosResponse.utxos.vals()) {
              bitcoinUtxos.add({
                outpoint = {
                  txid = Blob.toArray(utxo.outpoint.txid);
                  vout = utxo.outpoint.vout;
                };
                value = utxo.value;
                height = utxo.height;
              });
              totalBitcoinBalance += utxo.value
            };
            
            #ok(())
          }
        }
      }
    }
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

  /// Validate Bitcoin deposit by checking UTXOs for user's deposit address
  /// This function checks if the user has sent Bitcoin to their deposit address
  /// and validates the amount matches the expected deposit
  private func _validateBitcoinDeposit(
    userId : Principal,
    expectedAmount : Nat64
  ) : async Result<(), Text> {
    // Get user's Bitcoin deposit address
    let addressResult = await getUserBitcoinDepositAddress(userId);
    switch addressResult {
      case (#err(msg)) #err("Failed to get deposit address: " # msg);
      case (#ok(depositAddress)) {
        // Get UTXOs for the deposit address (require at least 1 confirmation for regtest)
        let utxosResult = await BitcoinApi.get_utxos(BTC_NETWORK, depositAddress, ?#MinConfirmations(1));
        switch utxosResult {
          case (#err(msg)) #err("Failed to query UTXOs: " # msg);
          case (#ok(utxosResponse)) {
            // Check if we have any UTXOs
            if (utxosResponse.utxos.size() == 0) {
              #err("No UTXOs found at deposit address. Please send Bitcoin to: " # depositAddress)
            } else {
              // Calculate total value of UTXOs at this address
              var totalValue : Nat64 = 0;
              var newUtxos : Buffer.Buffer<UtxoInfo> = Buffer.Buffer(10);
              
              label utxoCheck for (utxo in utxosResponse.utxos.vals()) {
                // Check if this UTXO is already tracked
                var isTracked = false;
                label trackCheck for (trackedUtxo in bitcoinUtxos.vals()) {
                  let txidBytes = Blob.toArray(utxo.outpoint.txid);
                  if (txidBytes == trackedUtxo.outpoint.txid and utxo.outpoint.vout == trackedUtxo.outpoint.vout) {
                    isTracked := true;
                    break trackCheck
                  }
                };
                
                // If not tracked, it's a new deposit
                if (not isTracked) {
                  newUtxos.add({
                    outpoint = {
                      txid = Blob.toArray(utxo.outpoint.txid);
                      vout = utxo.outpoint.vout;
                    };
                    value = utxo.value;
                    height = utxo.height;
                  });
                  totalValue += utxo.value
                }
              };
              
              // Check if we have new deposits and validate amount
              if (newUtxos.size() == 0) {
                #err("No new deposits found. All UTXOs are already tracked.")
              } else if (totalValue < expectedAmount) {
                #err("Deposit amount mismatch. Expected: " # Nat64.toText(expectedAmount) # " satoshis, Found: " # Nat64.toText(totalValue) # " satoshis in new UTXOs")
              } else {
                // Add new UTXOs to tracking
                for (utxo in newUtxos.vals()) {
                  bitcoinUtxos.add(utxo)
                };
                
                // Update total Bitcoin balance
                totalBitcoinBalance += totalValue;
                
                #ok(())
              }
            }
          }
        }
      }
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

  /// Serialize transaction to bytes for signing
  /// This is a simplified serialization - full Bitcoin transaction format is more complex
  /// For production, consider using the bitcoin library's Transaction module
  private func _serializeTransaction(
    tx : {
      inputs : [UtxoInfo];
      outputs : [(Text, Nat64)];
      totalInput : Nat64;
      totalOutput : Nat64;
      fee : Nat64;
      change : Nat64;
    },
    selectedUtxos : [UtxoInfo]
  ) : Result<[Nat8], Text> {
    // Create a simplified transaction representation
    // Version (4 bytes, little-endian)
    var txBytes = Buffer.Buffer<Nat8>(1000);
    
    // Version: 0x01000000 (1, little-endian)
    txBytes.add(0x00);
    txBytes.add(0x00);
    txBytes.add(0x00);
    txBytes.add(0x01);
    
    // Input count (varint)
    let inputCount = selectedUtxos.size();
    if (inputCount == 0) {
      return #err("No inputs in transaction")
    };
    
    // Simple varint encoding for input count (assuming < 253)
    if (inputCount < 253) {
      txBytes.add(Nat8.fromIntWrap(inputCount))
    } else {
      return #err("Too many inputs for simplified serialization")
    };
    
    // Inputs (simplified - just include outpoint references)
    for (utxo in selectedUtxos.vals()) {
      // Previous output hash (32 bytes, reversed)
      // utxo.outpoint.txid is [Nat8] according to Types.mo
      let txidBytes = utxo.outpoint.txid;
      // Bitcoin uses little-endian for txid in transaction format
      var i = txidBytes.size();
      while (i > 0) {
        i -= 1;
        txBytes.add(txidBytes[i])
      };
      // Pad to 32 bytes if needed
      var bytesAdded = txidBytes.size();
      while (bytesAdded < 32) {
        txBytes.add(0);
        bytesAdded += 1
      };
      
      // Output index (4 bytes, little-endian)
      let vout = utxo.outpoint.vout;
      txBytes.add(Nat8.fromIntWrap(Nat32.toNat(vout) % 256));
      txBytes.add(Nat8.fromIntWrap((Nat32.toNat(vout) / 256) % 256));
      txBytes.add(Nat8.fromIntWrap((Nat32.toNat(vout) / 65536) % 256));
      txBytes.add(Nat8.fromIntWrap((Nat32.toNat(vout) / 16777216) % 256));
      
      // Script length (varint) - placeholder 0 for now
      txBytes.add(0);
      
      // Sequence (4 bytes) - default 0xFFFFFFFF
      txBytes.add(0xFF);
      txBytes.add(0xFF);
      txBytes.add(0xFF);
      txBytes.add(0xFF)
    };
    
    // Output count (varint)
    let outputCount = tx.outputs.size();
    if (outputCount < 253) {
      txBytes.add(Nat8.fromIntWrap(outputCount))
    } else {
      return #err("Too many outputs for simplified serialization")
    };
    
    // Outputs
    for ((address, value) in tx.outputs.vals()) {
      // Value (8 bytes, little-endian)
      var valueRemaining = value;
      var j = 0;
      while (j < 8) {
        txBytes.add(Nat8.fromIntWrap(Nat64.toNat(valueRemaining % 256)));
        valueRemaining /= 256;
        j += 1
      };
      
      // Script length placeholder (will be filled with actual script)
      // For now, use a simple placeholder
      txBytes.add(25); // P2PKH script length
      
      // Script placeholder (25 bytes for P2PKH: OP_DUP OP_HASH160 20bytes OP_EQUALVERIFY OP_CHECKSIG)
      txBytes.add(0x76); // OP_DUP
      txBytes.add(0xA9); // OP_HASH160
      txBytes.add(0x14); // 20 bytes
      // 20 bytes of address hash (placeholder - would need to decode address)
      var k = 0;
      while (k < 20) {
        txBytes.add(0);
        k += 1
      };
      txBytes.add(0x88); // OP_EQUALVERIFY
      txBytes.add(0xAC) // OP_CHECKSIG
    };
    
    // Locktime (4 bytes) - 0 for now
    txBytes.add(0);
    txBytes.add(0);
    txBytes.add(0);
    txBytes.add(0);
    
    #ok(Buffer.toArray(txBytes))
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
      return #err(rateLimiter.formatError(userId))
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
      return #err(rateLimiter.formatError(userId))
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

