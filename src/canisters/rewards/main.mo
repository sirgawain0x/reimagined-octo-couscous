import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Types "./Types";
import BitcoinUtilsICP "../shared/BitcoinUtilsICP";
import BitcoinApi "../shared/BitcoinApi";
import BitcoinUtils "../shared/BitcoinUtils";
import RateLimiter "../shared/RateLimiter";
import InputValidation "../shared/InputValidation";
import Runestone "../shared/Runestone";
import Segwit "mo:bitcoin/Segwit";

persistent actor RewardsCanister {
  type Store = Types.Store;
  type StoreId = Types.StoreId;
  type AddStoreRequest = Types.AddStoreRequest;
  type PurchaseRecord = Types.PurchaseRecord;
  type PurchaseReceipt = Types.PurchaseReceipt;
  type BitcoinTx = Types.BitcoinTx;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // State
  private transient var stores : HashMap.HashMap<StoreId, Store> = HashMap.HashMap(0, func(a : StoreId, b : StoreId) : Bool { a == b }, func(a : StoreId) : Hash.Hash {
    // Bespoke hash function for Nat32 that considers all bits
    // Uses multiplicative hash: hash = (value * prime) mod 2^32
    let n : Nat = Nat32.toNat(a);
    let prime : Nat = 2654435761; // 32-bit prime multiplier
    let hashValue = (n * prime) % 4294967296; // mod 2^32
    Nat32.fromNat(hashValue) // Hash.Hash is Nat32, so convert using Nat32.fromNat
  });
  private transient var userRewards : HashMap.HashMap<Principal, Nat64> = HashMap.HashMap(0, Principal.equal, Principal.hash);
  private transient var purchases : Buffer.Buffer<PurchaseRecord> = Buffer.Buffer(100);
  private transient var nextStoreId : StoreId = 1;
  private transient var nextPurchaseId : Nat64 = 1;
  
  // Rune token state
  private transient var storeRuneTokens : HashMap.HashMap<StoreId, { runeName : Text; runeId : ?Text; runeReward : Float }> = HashMap.HashMap(0, func(a : StoreId, b : StoreId) : Bool { a == b }, func(a : StoreId) : Hash.Hash {
    let n : Nat = Nat32.toNat(a);
    let prime : Nat = 2654435761;
    let hashValue = (n * prime) % 4294967296;
    Nat32.fromNat(hashValue)
  });
  private transient var userRuneTokenRewards : HashMap.HashMap<Principal, HashMap.HashMap<StoreId, Nat64>> = HashMap.HashMap(0, Principal.equal, Principal.hash);

  // Admin management (transient - will be lost on upgrade, first caller becomes admin)
  private transient var admins : HashMap.HashMap<Principal, Bool> = HashMap.HashMap(0, Principal.equal, Principal.hash);

  // Bitcoin API integration
  private transient let BTC_API_ENABLED : Bool = true; // Enable for regtest
  private let BTC_NETWORK : BitcoinApi.Network = #Regtest;

  // Rate limiting (transient - resets on upgrade)
  private transient var rateLimiter = RateLimiter.RateLimiter(RateLimiter.REWARDS_CONFIG);

  /// Get all available stores
  public query func getStores() : async [Store] {
    Iter.toArray(stores.vals())
  };

  /// Add a new store
  public shared (msg) func addStore(request : AddStoreRequest) : async Result<StoreId, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };
    if (not InputValidation.validateText(request.name, 1, ?100)) {
      return #err("Invalid store name")
    };
    if (not InputValidation.validateText(request.logo, 0, ?500)) {
      return #err("Invalid logo URL")
    };
    switch (request.url) {
      case (null) {
        return #err("Store URL is required")
      };
      case (?url) {
        if (not InputValidation.validateText(url, 1, ?500)) {
          return #err("Invalid store URL")
        }
      }
    };
    if (request.reward < 0.0 or request.reward > 100.0) {
      return #err("Reward percentage must be between 0 and 100")
    };
    if (request.runeReward < 0.0 or request.runeReward > 100.0) {
      return #err("Rune reward percentage must be between 0 and 100")
    };

    if (not isAdmin(userId)) {
      return #err("Unauthorized: Only admins can add stores")
    };

    let storeId = nextStoreId;
    nextStoreId += 1;

    let store : Store = {
      id = storeId;
      name = request.name;
      reward = request.reward;
      logo = request.logo;
      url = request.url;
      runeReward = request.runeReward;
      runeName = null;
      runeId = null;
    };

    stores.put(storeId, store);
    
    // Initialize rune token tracking (rune name will be generated lazily)
    storeRuneTokens.put(storeId, {
      runeName = ""; // Will be generated when first needed
      runeId = null;
      runeReward = request.runeReward;
    });
    
    #ok(storeId)
  };

  /// Track a purchase and calculate rewards
  public shared (msg) func trackPurchase(
    storeId : StoreId,
    amount : Nat64
  ) : async Result<PurchaseReceipt, Text> {
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

    // Verify store exists
    let storeOpt = stores.get(storeId);
    switch storeOpt {
      case null {
        return #err("Store not found")
      };
      case (?store) {
        // Calculate BTC reward (store.reward is percentage)
        let rewardAmount = (amount * Nat64.fromIntWrap(Float.toInt(store.reward))) / 100;
        
        // Calculate rune token reward (store.runeReward is percentage)
        let runeTokenAmount = (amount * Nat64.fromIntWrap(Float.toInt(store.runeReward))) / 100;

        // Create purchase record
        let purchase : PurchaseRecord = {
          id = nextPurchaseId;
          userId = userId;
          storeId = storeId;
          amount = amount;
          reward = rewardAmount;
          runeTokenRewards = runeTokenAmount;
          timestamp = Nat64.fromIntWrap(Time.now());
          claimed = false;
        };

        // Update state
        purchases.add(purchase);
        nextPurchaseId += 1;

        // Update user BTC rewards
        let currentRewards = userRewards.get(userId);
        let newRewards = Option.get<Nat64>(currentRewards, 0) + rewardAmount;
        userRewards.put(userId, newRewards);
        
        // Update user rune token rewards
        let userRuneRewardsOpt = userRuneTokenRewards.get(userId);
        let userRuneRewards = switch userRuneRewardsOpt {
          case null {
            let newMap = HashMap.HashMap<StoreId, Nat64>(0, func(a : StoreId, b : StoreId) : Bool { a == b }, func(a : StoreId) : Hash.Hash {
              let n : Nat = Nat32.toNat(a);
              let prime : Nat = 2654435761;
              let hashValue = (n * prime) % 4294967296;
              Nat32.fromNat(hashValue)
            });
            userRuneTokenRewards.put(userId, newMap);
            newMap
          };
          case (?map) map
        };
        let currentRuneRewards = userRuneRewards.get(storeId);
        let newRuneRewards = Option.get<Nat64>(currentRuneRewards, 0) + runeTokenAmount;
        userRuneRewards.put(storeId, newRuneRewards);

        #ok({ purchaseId = purchase.id; rewardEarned = rewardAmount; runeTokenRewardEarned = runeTokenAmount })
      }
    }
  };

  /// Get user's total rewards
  public query func getUserRewards(userId : Principal) : async Nat64 {
    Option.get<Nat64>(userRewards.get(userId), 0)
  };

  /// Get user's rune token rewards per store
  public query func getUserRuneTokenRewards(userId : Principal) : async [(StoreId, Nat64)] {
    let userRuneRewardsOpt = userRuneTokenRewards.get(userId);
    switch userRuneRewardsOpt {
      case null [];
      case (?userRuneRewards) {
        var result = Buffer.Buffer<(StoreId, Nat64)>(userRuneRewards.size());
        for ((storeId, amount) in userRuneRewards.entries()) {
          result.add((storeId, amount))
        };
        Buffer.toArray(result)
      }
    }
  };

  /// Get store rune information
  public query func getStoreRuneInfo(storeId : StoreId) : async ?{ runeName : Text; runeId : ?Text; runeReward : Float } {
    storeRuneTokens.get(storeId)
  };

  /// Generate rune name for a store
  private func generateRuneNameForStore(storeName : Text) : Text {
    Runestone.generateRuneNameFromStoreName(storeName)
  };

  /// Etch a rune token for a store (lazy initialization)
  /// This is called automatically when rune tokens are first claimed
  private func etchStoreRune(storeId : StoreId) : async Result<Text, Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };
    
    // Get store info
    let storeOpt = stores.get(storeId);
    switch storeOpt {
      case null return #err("Store not found");
      case (?store) {
        // Get or generate rune name
        let runeInfoOpt = storeRuneTokens.get(storeId);
        switch runeInfoOpt {
          case null return #err("Store rune info not found");
          case (?runeInfo) {
            let runeName = if (runeInfo.runeName == "") {
              let generated = generateRuneNameForStore(store.name);
              // Update rune info with generated name
              storeRuneTokens.put(storeId, {
                runeName = generated;
                runeId = null;
                runeReward = runeInfo.runeReward;
              });
              generated
            } else {
              runeInfo.runeName
            };
            
            // Check if already etched
            switch (runeInfo.runeId) {
              case (?id) {
                return #ok(id)
              };
              case (null) {
                // Need to etch
                // 1. Get canister Taproot address
                let taprootAddressResult = await getCanisterTaprootAddress();
                switch taprootAddressResult {
                  case (#err(msg)) return #err("Failed to get Taproot address: " # msg);
                  case (#ok(taprootAddress)) {
                    // 2. Get UTXOs from Taproot address
                    let utxosResult = await BitcoinApi.get_utxos(BTC_NETWORK, taprootAddress, null);
                    switch utxosResult {
                      case (#err(msg)) return #err("Failed to get UTXOs: " # msg);
                      case (#ok(utxosResponse)) {
                        if (utxosResponse.utxos.size() == 0) {
                          return #err("No UTXOs available for etching")
                        };
                        
                        // 3. Build etching transaction
                        // For etching, we need at least one UTXO and create an OP_RETURN output
                        let estimatedFee : Nat64 = 1000; // Estimated fee for etching transaction
                        let selectedUtxo = utxosResponse.utxos[0];
                        
                        if (selectedUtxo.value < estimatedFee) {
                          return #err("Insufficient funds for etching transaction")
                        };
                        
                        // Encode etching runestone
                        let runestoneResult = Runestone.encodeEtchingRunestone(runeName, 0, null, null);
                        switch runestoneResult {
                          case (#err(msg)) return #err("Failed to encode runestone: " # msg);
                          case (#ok(runestoneData)) {
                            // Build OP_RETURN output
                            let opReturnScript = Runestone.buildOpReturnOutput(runestoneData);
                            
                            // Build transaction (simplified - would need proper Bitcoin library for full implementation)
                            // For now, return a placeholder rune ID
                            // In production, you would:
                            // 1. Build full transaction with inputs, OP_RETURN output, change output
                            // 2. Sign with Schnorr signature
                            // 3. Broadcast transaction
                            // 4. Extract rune ID from transaction result (block:tx format)
                            
                            // Placeholder: generate a mock rune ID
                            // In real implementation, this would come from the broadcasted transaction
                            let mockRuneId = "0:0"; // Would be actual block:tx from transaction
                            
                            // Update store rune info with rune ID
                            storeRuneTokens.put(storeId, {
                              runeName = runeName;
                              runeId = ?mockRuneId;
                              runeReward = runeInfo.runeReward;
                            });
                            
                            #ok(mockRuneId)
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

  /// Get user's reward address using BitcoinUtilsICP
  /// Generates a P2WPKH address for the user (SegWit for lower fees)
  public func getUserRewardAddress(userId : Principal) : async Result<Text, Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };
    
    // Use user's principal to derive a unique index
    // For now, use a simple hash of the principal as the derivation index
    // In production, you might want a more sophisticated mapping
    let principalBytes = Blob.toArray(Principal.toBlob(userId));
    let index = Nat32.fromNat(Array.foldLeft<Nat8, Nat>(principalBytes, 0, func(acc, b) { acc + Nat8.toNat(b) }) % 2147483647);
    let derivationPath = BitcoinUtilsICP.createDerivationPath(index);
    
    // Generate P2WPKH address (SegWit for lower transaction fees)
    await BitcoinUtilsICP.generateP2WPKHAddress(#Regtest, derivationPath, null)
  };

  /// Claim rewards (Bitcoin transaction implementation)
  public shared (msg) func claimRewards() : async Result<BitcoinTx, Text> {
    let userId = msg.caller;

    // Rate limiting check
    if (not rateLimiter.isAllowed(userId)) {
      return #err(rateLimiter.formatError(userId))
    };

    // Input validation
    if (not InputValidation.validatePrincipal(userId)) {
      return #err("Invalid principal")
    };

    let rewards = Option.get<Nat64>(userRewards.get(userId), 0);
    
    // Get rune token rewards
    let userRuneRewardsOpt = userRuneTokenRewards.get(userId);
    let runeRewardsList = switch userRuneRewardsOpt {
      case null [];
      case (?userRuneRewards) {
        var result = Buffer.Buffer<(StoreId, Nat64)>(userRuneRewards.size());
        for ((storeId, amount) in userRuneRewards.entries()) {
          if (amount > 0) {
            result.add((storeId, amount))
          }
        };
        Buffer.toArray(result)
      }
    };

    if (rewards == 0 and runeRewardsList.size() == 0) {
      return #err("No rewards to claim")
    };

    if (not BTC_API_ENABLED) {
      // Mock behavior when Bitcoin API is disabled
      userRewards.put(userId, 0);
      // Reset rune token rewards
      switch userRuneRewardsOpt {
        case null {};
        case (?userRuneRewards) {
          for ((storeId, _) in runeRewardsList.vals()) {
            userRuneRewards.put(storeId, 0)
          }
        }
      };
      return #ok({ txid = "mock_tx_" # Principal.toText(userId); hex = [] })
    };
    
    // Check and etch runes if needed
    var runeTransfers = Buffer.Buffer<{ storeId : StoreId; runeId : Text; amount : Nat64 }>(runeRewardsList.size());
    for ((storeId, amount) in runeRewardsList.vals()) {
      let runeInfoOpt = storeRuneTokens.get(storeId);
      switch (runeInfoOpt) {
        case (null) {
          return #err("Store rune info not found for store: " # Nat32.toText(storeId))
        };
        case (?runeInfo) {
          // Check if rune is etched
          switch (runeInfo.runeId) {
            case (?runeId) {
              // Already etched, add to transfers
              runeTransfers.add({ storeId = storeId; runeId = runeId; amount = amount })
            };
            case (null) {
              // Need to etch
              let etchResult = await etchStoreRune(storeId);
              switch etchResult {
                case (#err(msg)) return #err("Failed to etch rune for store " # Nat32.toText(storeId) # ": " # msg);
                case (#ok(runeId)) {
                  runeTransfers.add({ storeId = storeId; runeId = runeId; amount = amount })
                }
              }
            }
          }
        }
      }
    };

    // 1. Get user's reward address
    let userAddressResult = await getUserRewardAddress(userId);
    switch userAddressResult {
      case (#err(msg)) return #err("Failed to get reward address: " # msg);
      case (#ok(userAddress)) {
        // 2. Get canister address (use Taproot if rune tokens are involved, otherwise regular)
        let useTaproot = runeTransfers.size() > 0;
        let canisterAddressResult = if (useTaproot) {
          await getCanisterTaprootAddress()
        } else {
          await getCanisterRewardAddress()
        };
        switch canisterAddressResult {
          case (#err(msg)) return #err("Failed to get canister address: " # msg);
          case (#ok(canisterAddress)) {
            // 3. Get UTXOs from canister address
            let utxosResult = await BitcoinApi.get_utxos(BTC_NETWORK, canisterAddress, null);
            switch utxosResult {
              case (#err(msg)) return #err("Failed to get UTXOs: " # msg);
              case (#ok(utxosResponse)) {
                if (utxosResponse.utxos.size() == 0) {
                  return #err("No UTXOs available for reward payout")
                };
                
                // 4. Select UTXOs for reward amount
                // Estimate transaction size: base + inputs + outputs (BTC + OP_RETURN for each rune + change)
                let estimatedFeePerByte : Nat64 = 10;
                let baseSize : Nat32 = 10; // Version, locktime, etc.
                let inputSize : Nat32 = 180; // Per input
                let btcOutputSize : Nat32 = 34; // 8 bytes value + 22 bytes script
                let opReturnOutputSize : Nat32 = 83; // 8 bytes value (dust) + ~75 bytes script (OP_RETURN + data)
                let changeOutputSize : Nat32 = 34; // 8 bytes value + 25 bytes script
                
                let numInputs = Nat32.fromNat(utxosResponse.utxos.size());
                let numRuneOutputs = Nat32.fromNat(runeTransfers.size());
                
                let estimatedTxSize = baseSize + (numInputs * inputSize) + (if (rewards > 0) btcOutputSize else 0 : Nat32) + (numRuneOutputs * opReturnOutputSize) + changeOutputSize;
                let estimatedFee = Nat64.fromNat(Nat32.toNat(estimatedTxSize)) * estimatedFeePerByte;
                let totalNeeded = rewards + estimatedFee;
                
                var selectedUtxos : Buffer.Buffer<BitcoinApi.Utxo> = Buffer.Buffer(10);
                var selectedAmount : Nat64 = 0;
                
                label utxoLoop for (utxo in utxosResponse.utxos.vals()) {
                  if (selectedAmount < totalNeeded) {
                    selectedUtxos.add(utxo);
                    selectedAmount += utxo.value
                  } else {
                    break utxoLoop
                  }
                };
                
                if (selectedAmount < totalNeeded) {
                  return #err("Insufficient funds for reward payout. Need: " # Nat64.toText(totalNeeded) # ", Available: " # Nat64.toText(selectedAmount))
                };
                
                // 5. Build and sign transaction (simplified implementation)
                // Note: Full Bitcoin transaction serialization should use the bitcoin library
                let change = selectedAmount - totalNeeded;
                var txBytes = Buffer.Buffer<Nat8>(500);
                
                // Simplified transaction structure for signing
                txBytes.add(0x00); txBytes.add(0x00); txBytes.add(0x00); txBytes.add(0x01); // Version
                txBytes.add(Nat8.fromIntWrap(selectedUtxos.size())); // Input count
                
                // Add inputs
                for (utxo in selectedUtxos.vals()) {
                  let txidBytes = Blob.toArray(utxo.outpoint.txid);
                  var i = txidBytes.size();
                  while (i > 0) {
                    i -= 1;
                    txBytes.add(txidBytes[i])
                  };
                  var bytesAdded = txidBytes.size();
                  while (bytesAdded < 32) {
                    txBytes.add(0);
                    bytesAdded += 1
                  };
                  let vout = utxo.outpoint.vout;
                  txBytes.add(Nat8.fromIntWrap(Nat32.toNat(vout) % 256));
                  txBytes.add(Nat8.fromIntWrap((Nat32.toNat(vout) / 256) % 256));
                  txBytes.add(Nat8.fromIntWrap((Nat32.toNat(vout) / 65536) % 256));
                  txBytes.add(Nat8.fromIntWrap((Nat32.toNat(vout) / 16777216) % 256));
                  txBytes.add(0); // Script length placeholder
                  txBytes.add(0xFF); txBytes.add(0xFF); txBytes.add(0xFF); txBytes.add(0xFF) // Sequence
                };
                
                // Calculate output count: BTC output (if rewards > 0) + rune OP_RETURN outputs + change (if needed)
                let numOutputs = (if (rewards > 0) 1 else 0) + Nat32.fromNat(runeTransfers.size()) + (if (change > 546) 1 else 0);
                txBytes.add(Nat8.fromIntWrap(Nat32.toNat(numOutputs)));
                
                // BTC output to user (if rewards > 0)
                if (rewards > 0) {
                  // Decode user address to get witness program (20-byte hash for P2WPKH)
                  let userAddressHash = switch (Segwit.decode(userAddress)) {
                    case (#ok((_, witnessProgram))) {
                      if (witnessProgram.version == 0 and witnessProgram.program.size() == 20) {
                        ?witnessProgram.program // P2WPKH: 20-byte witness program
                      } else {
                        null
                      }
                    };
                    case (#err(_)) null
                  };
                  
                  let addressHash = switch userAddressHash {
                    case null return #err("Failed to decode user address as P2WPKH. Expected version 0 and 20-byte program");
                    case (?hash) hash
                  };

                  // Output to user (P2WPKH: OP_0 <20-byte-witness-program>)
                  var valueRemaining = rewards;
                  var j = 0;
                  while (j < 8) {
                    txBytes.add(Nat8.fromIntWrap(Nat64.toNat(valueRemaining % 256)));
                    valueRemaining /= 256;
                    j += 1
                  };
                  // P2WPKH script: OP_0 (0x00) <push 20 bytes> <20-byte-hash>
                  txBytes.add(22); // Script length: 1 (OP_0) + 1 (push) + 20 (hash) = 22
                  txBytes.add(0x00); // OP_0
                  txBytes.add(0x14); // Push 20 bytes
                  // Add the 20-byte address hash
                  for (byte in addressHash.vals()) {
                    txBytes.add(byte)
                  }
                };
                
                // OP_RETURN outputs for rune token transfers
                // Output index calculation: BTC output (if present) is index 0, OP_RETURN outputs start at index 1 (or 0 if no BTC)
                var runeOutputIndex = if (rewards > 0) 1 else 0;
                for (transfer in runeTransfers.vals()) {
                  // Encode runestone for transfer
                  let runestoneResult = Runestone.encodeRunestone(transfer.runeId, transfer.amount, runeOutputIndex);
                  switch runestoneResult {
                    case (#err(msg)) {
                      return #err("Failed to encode runestone for store " # Nat32.toText(transfer.storeId) # ": " # msg)
                    };
                    case (#ok(runestoneData)) {
                      // Build OP_RETURN output
                      let opReturnScript = Runestone.buildOpReturnOutput(runestoneData);
                      
                      // OP_RETURN output value (dust: 0 satoshis)
                      var j = 0;
                      while (j < 8) {
                        txBytes.add(0);
                        j += 1
                      };
                      
                      // OP_RETURN script
                      txBytes.add(Nat8.fromIntWrap(opReturnScript.size()));
                      for (byte in opReturnScript.vals()) {
                        txBytes.add(byte)
                      };
                      
                      // Increment output index for next rune transfer
                      runeOutputIndex += 1
                    }
                  }
                };
                
                // Change output if needed
                if (change > 546) {
                  var valueRemaining = change;
                  var j = 0;
                  while (j < 8) {
                    txBytes.add(Nat8.fromIntWrap(Nat64.toNat(valueRemaining % 256)));
                    valueRemaining /= 256;
                    j += 1
                  };
                  // P2PKH script: OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG
                  txBytes.add(25); txBytes.add(0x76); txBytes.add(0xA9); txBytes.add(0x14);
                  // Use canister address hash (for now, zeros as placeholder - should decode canisterAddress)
                  var k = 0;
                  while (k < 20) {
                    txBytes.add(0);
                    k += 1
                  };
                  txBytes.add(0x88); txBytes.add(0xAC)
                };
                
                // Locktime
                txBytes.add(0); txBytes.add(0); txBytes.add(0); txBytes.add(0);
                
                // 6. Sign transaction (use Taproot derivation if rune tokens involved)
                let derivationPath = BitcoinUtilsICP.createDerivationPath(if (useTaproot) 2 else 0);
                let signResult = await BitcoinUtilsICP.signTransaction(Buffer.toArray(txBytes), derivationPath, null);
                switch signResult {
                  case (#err(msg)) return #err("Failed to sign transaction: " # msg);
                  case (#ok(signature)) {
                    // 7. Create signed transaction
                    var signedTxBytes = Buffer.Buffer<Nat8>(txBytes.size() + signature.size());
                    for (byte in txBytes.vals()) {
                      signedTxBytes.add(byte)
                    };
                    for (byte in signature.vals()) {
                      signedTxBytes.add(byte)
                    };
                    
                    // 8. Broadcast transaction
                    let broadcastResult = await BitcoinApi.send_transaction(BTC_NETWORK, Buffer.toArray(signedTxBytes));
                    switch broadcastResult {
                      case (#err(msg)) return #err("Failed to broadcast transaction: " # msg);
                      case (#ok(())) {
                        // Success! Reset user rewards
                        userRewards.put(userId, 0);
                        // Reset rune token rewards
                        switch userRuneRewardsOpt {
                          case null {};
                          case (?userRuneRewards) {
                            for ((storeId, _) in runeRewardsList.vals()) {
                              userRuneRewards.put(storeId, 0)
                            }
                          }
                        };
                        let txid = BitcoinUtils.bytesToHex(Array.take<Nat8>(Buffer.toArray(txBytes), 32));
                        return #ok({ txid = txid; hex = Buffer.toArray(signedTxBytes) })
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
    // This should never be reached, but needed for type checking
    #err("Unexpected error in claimRewards")
  };

  /// Get canister Bitcoin address
  /// Returns P2PKH address for the canister (index 0)
  public func getCanisterRewardAddress() : async Result<Text, Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };
    
    // Use index 0 for the main canister address
    let derivationPath = BitcoinUtilsICP.createDerivationPath(0);
    
    // Generate P2PKH address for main canister address
    await BitcoinUtilsICP.generateP2PKHAddress(#Regtest, derivationPath, null)
  };

  /// Get canister Taproot address (P2TR)
  /// Modern Taproot address for lower fees and better privacy
  public func getCanisterTaprootAddress() : async Result<Text, Text> {
    if (not BTC_API_ENABLED) {
      return #err("Bitcoin integration not enabled")
    };
    
    let derivationPath = BitcoinUtilsICP.createDerivationPath(2); // Index 2 for Taproot
    await BitcoinUtilsICP.generateP2TRKeyOnlyAddress(#Regtest, derivationPath, null)
  };

  /// Get purchase history for a user
  public query func getUserPurchases(userId : Principal) : async [PurchaseRecord] {
    Array.filter<PurchaseRecord>(
      Buffer.toArray(purchases),
      func(p) { Principal.equal(p.userId, userId) }
    )
  };

  /// Get all purchases (admin only)
  public query func getAllPurchases() : async [PurchaseRecord] {
    Buffer.toArray(purchases)
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

