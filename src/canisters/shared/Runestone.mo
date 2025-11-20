// Runestone Module
// Implements Bitcoin Runes protocol according to specification
// Uses LEB128 encoding for tag-value pairs and proper OP_RETURN format
// WARNING: Incorrect encoding causes Cenotaphs (permanent asset burn)

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";

module Runestone {
  public type Result<Ok, Err> = Result.Result<Ok, Err>;

  // Runestone Tag Constants (u128 values)
  private let TAG_EDICTS : Nat = 0; // Transfer instructions
  private let TAG_FLAGS : Nat = 2; // Etching flags
  private let TAG_RUNE : Nat = 4; // Rune name (base-26 encoded)
  private let TAG_PREMINE : Nat = 6; // Premine amount
  private let TAG_CAP : Nat = 8; // Mint cap
  private let TAG_AMOUNT : Nat = 10; // Mint amount
  private let TAG_OFFSET_END : Nat = 10; // Mint offset end
  private let TAG_OFFSET_START : Nat = 12; // Mint offset start
  private let TAG_HEIGHT_END : Nat = 14; // Mint height end
  private let TAG_HEIGHT_START : Nat = 16; // Mint height start
  private let TAG_DIVISIBILITY : Nat = 1; // Decimal places

  // Flag bits
  private let FLAG_ETCHING : Nat = 0; // Indicates this is an etching
  private let FLAG_TERMS : Nat = 1; // Indicates mint terms are present

  // Maximum values
  private let MAX_RUNE_NAME_LENGTH : Nat = 28;
  private let MAX_LEB128_BYTES : Nat = 18; // Maximum bytes for a single LEB128 value
  private let MAX_OP_RETURN_SIZE : Nat = 80; // Maximum OP_RETURN size

  // OP_RETURN script constants
  private let OP_RETURN : Nat8 = 0x6a;
  private let OP_13 : Nat8 = 0x5d; // Required after OP_RETURN for runestones

  /// Encode a u128 value using LEB128 (Little Endian Base 128)
  /// Each byte encodes 7 bits, MSB (bit 7) is continuation bit
  /// Returns error if value exceeds 18 bytes (Cenotaph risk)
  private func encodeLEB128(value : Nat) : Result<[Nat8], Text> {
    if (value == 0) {
      return #ok([0])
    };
    
    var buffer = Buffer.Buffer<Nat8>(MAX_LEB128_BYTES);
    var remaining = value;
    var byteCount = 0;
    
    while (remaining > 0 and byteCount < MAX_LEB128_BYTES) {
      let byte = Nat8.fromIntWrap(remaining % 128);
      remaining := remaining / 128;
      
      if (remaining > 0) {
        // Set continuation bit (MSB = 1)
        buffer.add(byte | 0x80)
      } else {
        // Last byte, no continuation bit
        buffer.add(byte)
      };
      byteCount += 1
    };
    
    if (remaining > 0) {
      return #err("LEB128 value exceeds 18 bytes (Cenotaph risk)")
    };
    
    #ok(Buffer.toArray(buffer))
  };

  /// Encode a rune name to a u128 value using base-26 encoding
  /// Rune names must contain only uppercase letters A-Z
  /// Returns the encoded value or an error if invalid
  public func encodeRuneName(name : Text) : Result<Nat, Text> {
    if (name.size() == 0) {
      return #err("Rune name cannot be empty")
    };
    
    if (name.size() > MAX_RUNE_NAME_LENGTH) {
      return #err("Rune name cannot exceed 28 characters")
    };

    var value : Nat = 0;
    var index : Nat = 0;
    
    for (char in name.chars()) {
      let code = Char.toNat32(char);
      
      // Check if character is A-Z
      if (code < 65 or code > 90) {
        return #err("Rune name must contain only uppercase letters A-Z, got: " # Text.fromChar(char))
      };
      
      let digit = Nat32.toNat(code - 65); // A=0, B=1, ..., Z=25
      
      if (index == 0) {
        value := digit
      } else {
        // Multiply previous value by 26 and add new digit
        let multiplied = value * 26;
        if (multiplied < value) {
          return #err("Rune name value overflow")
        };
        let added = multiplied + digit;
        if (added < multiplied) {
          return #err("Rune name value overflow")
        };
        value := added
      };
      
      index += 1
    };
    
    #ok(value)
  };

  /// Generate a valid rune name from a store name
  /// Converts to uppercase, replaces spaces with •, removes invalid characters
  /// Truncates to 28 characters max
  public func generateRuneNameFromStoreName(storeName : Text) : Text {
    // Convert to uppercase
    let upper = Text.map(storeName, func(char : Char) : Char {
      let code = Char.toNat32(char);
      // If lowercase letter (a-z), convert to uppercase (A-Z)
      if (code >= 97 and code <= 122) {
        Char.fromNat32(code - 32)
      } else {
        char
      }
    });
    
    // Replace spaces with bullet (•)
    let withBullets = Text.replace(upper, #text " ", "•");
    
    // Filter to keep only A-Z and •, and truncate to max length
    var result = Buffer.Buffer<Char>(MAX_RUNE_NAME_LENGTH);
    var count = 0;
    for (char in withBullets.chars()) {
      if (count < MAX_RUNE_NAME_LENGTH) {
      let code = Char.toNat32(char);
      // Keep A-Z (65-90) and • (8226)
      if ((code >= 65 and code <= 90) or code == 8226) {
        result.add(char);
        count := count + 1
      }
      }
    };
    Text.fromIter(result.vals())
  };

  /// Encode a tag-value pair
  /// Both tag and value are u128 encoded with LEB128
  private func encodeTagValue(tag : Nat, value : Nat) : Result<[Nat8], Text> {
    let tagBytes = encodeLEB128(tag);
    let valueBytes = encodeLEB128(value);
    
    switch (tagBytes, valueBytes) {
      case (#err(msg), _) {
        #err("Failed to encode tag: " # msg)
      };
      case (_, #err(msg)) {
        #err("Failed to encode value: " # msg)
      };
      case (#ok(tagArr), #ok(valueArr)) {
        var buffer = Buffer.Buffer<Nat8>(tagArr.size() + valueArr.size());
        for (byte in tagArr.vals()) {
          buffer.add(byte)
        };
        for (byte in valueArr.vals()) {
          buffer.add(byte)
        };
        #ok(Buffer.toArray(buffer))
      }
    }
  };

  /// Encode an Edict (transfer instruction)
  /// Edicts use delta encoding: first edict uses absolute rune ID,
  /// subsequent edicts use delta from previous rune ID
  /// Format: [rune_id_delta (LEB128)] [output_index (LEB128)] [amount (LEB128)]
  private func encodeEdict(
    runeIdDelta : Nat,
    outputIndex : Nat,
    amount : Nat
  ) : Result<[Nat8], Text> {
    let runeBytes = encodeLEB128(runeIdDelta);
    let outputBytes = encodeLEB128(outputIndex);
    let amountBytes = encodeLEB128(amount);
    
    switch (runeBytes, outputBytes, amountBytes) {
      case (#err(msg), _, _) {
        #err("Failed to encode rune ID delta: " # msg)
      };
      case (_, #err(msg), _) {
        #err("Failed to encode output index: " # msg)
      };
      case (_, _, #err(msg)) {
        #err("Failed to encode amount: " # msg)
      };
      case (#ok(runeArr), #ok(outputArr), #ok(amountArr)) {
        var buffer = Buffer.Buffer<Nat8>(runeArr.size() + outputArr.size() + amountArr.size());
        for (byte in runeArr.vals()) {
          buffer.add(byte)
        };
        for (byte in outputArr.vals()) {
          buffer.add(byte)
        };
        for (byte in amountArr.vals()) {
          buffer.add(byte)
        };
        #ok(Buffer.toArray(buffer))
      }
    }
  };

  /// Encode a runestone for transferring runes
  /// runeId format: "block:tx" (e.g., "840000:846")
  /// amount: amount of rune tokens to transfer
  /// outputIndex: index of the output receiving the runes (typically 1 for first output after OP_RETURN)
  public func encodeRunestone(
    runeId : Text,
    amount : Nat64,
    outputIndex : Nat
  ) : Result<[Nat8], Text> {
    // Parse rune ID (format: "block:tx")
    let parts = Iter.toArray(Text.split(runeId, #text ":"));
    if (parts.size() != 2) {
      return #err("Invalid rune ID format. Expected 'block:tx', got: " # runeId)
    };
    
    // Parse block number and tx index
    let blockNatOpt = Nat.fromText(parts[0]);
    let txNatOpt = Nat.fromText(parts[1]);
    let blockOpt = switch blockNatOpt {
      case null null;
      case (?n) ?n
    };
    let txOpt = switch txNatOpt {
      case null null;
      case (?n) ?n
    };
    
    switch (blockOpt, txOpt) {
      case (null, _) {
        #err("Invalid block number in rune ID")
      };
      case (_, null) {
        #err("Invalid transaction index in rune ID")
      };
      case (?block, ?tx) {
        // Calculate rune ID: block * 2^16 + tx (as per Runes spec)
        let calculatedRuneId = block * 65536 + tx;
        
        // Encode Edict (Tag 0)
        // For single transfer, delta is the absolute rune ID
        let edictResult = encodeEdict(calculatedRuneId, outputIndex, Nat64.toNat(amount));
        switch edictResult {
          case (#err(msg)) {
            #err("Failed to encode edict: " # msg)
          };
          case (#ok(edictBytes)) {
            // Encode Tag 0 (Edicts) with the edict data
            // Tag 0 value is the length of edict data in bytes
            let edictLength = edictBytes.size();
            let tagValueResult = encodeTagValue(TAG_EDICTS, edictLength);
            switch tagValueResult {
              case (#err(msg)) {
                #err("Failed to encode tag-value: " # msg)
              };
              case (#ok(tagValueBytes)) {
                // Combine tag-value pair with edict data
                var buffer = Buffer.Buffer<Nat8>(tagValueBytes.size() + edictBytes.size());
                for (byte in tagValueBytes.vals()) {
                  buffer.add(byte)
                };
                for (byte in edictBytes.vals()) {
                  buffer.add(byte)
                };
                
                // Check size limit
                if (buffer.size() > MAX_OP_RETURN_SIZE) {
                  #err("Runestone data exceeds 80 bytes limit (Cenotaph risk)")
                } else {
                  #ok(Buffer.toArray(buffer))
                }
              }
            }
          }
        }
      }
    }
  };

  /// Encode a runestone for an etching command
  /// runeName: the rune name (will be encoded using encodeRuneName)
  /// divisibility: number of decimal places (0-38)
  /// symbol: optional emoji or symbol
  /// premine: optional amount to premine
  public func encodeEtchingRunestone(
    runeName : Text,
    divisibility : Nat8,
    symbol : ?Text,
    premine : ?Nat64
  ) : Result<[Nat8], Text> {
    // Encode rune name
    let encodedName = encodeRuneName(runeName);
    switch encodedName {
      case (#err(msg)) {
        #err("Failed to encode rune name: " # msg)
      };
      case (#ok(nameValue)) {
        var buffer = Buffer.Buffer<Nat8>(MAX_OP_RETURN_SIZE);
        
        // Tag 2: Flags (set FLAG_ETCHING bit)
        // In Motoko, use multiplication for bit shifts: 1 << 0 = 1 * (2^0) = 1
        let flagsValue = 1; // Bit 0 = etching (1 << 0 = 1)
        let flagsResult = encodeTagValue(TAG_FLAGS, flagsValue);
        switch flagsResult {
          case (#err(msg)) {
            #err("Failed to encode flags: " # msg)
          };
          case (#ok(flagsBytes)) {
            for (byte in flagsBytes.vals()) {
              buffer.add(byte)
            };
            // Tag 4: Rune name
            let runeResult = encodeTagValue(TAG_RUNE, nameValue);
            switch runeResult {
              case (#err(msg)) {
                #err("Failed to encode rune name tag: " # msg)
              };
              case (#ok(runeBytes)) {
                for (byte in runeBytes.vals()) {
                  buffer.add(byte)
                };
                // Tag 1: Divisibility
                let divResult = encodeTagValue(TAG_DIVISIBILITY, Nat8.toNat(divisibility));
                switch divResult {
                  case (#err(msg)) {
                    #err("Failed to encode divisibility: " # msg)
                  };
                  case (#ok(divBytes)) {
                    for (byte in divBytes.vals()) {
                      buffer.add(byte)
                    };
                    // Tag 6: Premine (if present)
                    switch premine {
                      case null {
                        // Check size limit
                        if (buffer.size() > MAX_OP_RETURN_SIZE) {
                          #err("Runestone data exceeds 80 bytes limit (Cenotaph risk)")
                        } else {
                          #ok(Buffer.toArray(buffer))
                        }
                      };
                      case (?premineAmount) {
                        let premineResult = encodeTagValue(TAG_PREMINE, Nat64.toNat(premineAmount));
                        switch premineResult {
                          case (#err(msg)) {
                            #err("Failed to encode premine: " # msg)
                          };
                          case (#ok(premineBytes)) {
                            for (byte in premineBytes.vals()) {
                              buffer.add(byte)
                            };
                            // Check size limit
                            if (buffer.size() > MAX_OP_RETURN_SIZE) {
                              #err("Runestone data exceeds 80 bytes limit (Cenotaph risk)")
                            } else {
                              #ok(Buffer.toArray(buffer))
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
    }
  };

  /// Build an OP_RETURN script output for a runestone
  /// Format: OP_RETURN (0x6a) OP_13 (0x5d) [data_push] [runestone_data]
  /// Returns the script bytes
  public func buildOpReturnOutput(runestoneData : [Nat8]) : [Nat8] {
    var buffer = Buffer.Buffer<Nat8>(runestoneData.size() + 20);
    
    // OP_RETURN opcode (0x6a)
    buffer.add(OP_RETURN);
    
    // OP_13 (0x5d) - required for runestones
    buffer.add(OP_13);
    
    // Push data length (Bitcoin script push encoding)
    let dataLen = Nat64.fromNat(runestoneData.size());
    var len = dataLen;
    if (len < 76) {
      // Single byte push (OP_PUSHDATA1-75)
      buffer.add(Nat8.fromIntWrap(Nat64.toNat(len)))
    } else if (len < 256) {
      // OP_PUSHDATA1 (0x4c) followed by 1-byte length
      buffer.add(0x4c);
      buffer.add(Nat8.fromIntWrap(Nat64.toNat(len)))
    } else if (len < 65536) {
      // OP_PUSHDATA2 (0x4d) followed by 2-byte length (little-endian)
      buffer.add(0x4d);
      buffer.add(Nat8.fromIntWrap(Nat64.toNat(len % 256)));
      buffer.add(Nat8.fromIntWrap(Nat64.toNat(len / 256)))
    } else {
      // OP_PUSHDATA4 (0x4e) followed by 4-byte length (little-endian)
      buffer.add(0x4e);
      var lenVal = len;
      var i = 0;
      while (i < 4) {
        buffer.add(Nat8.fromIntWrap(Nat64.toNat(lenVal % 256)));
        lenVal /= 256;
        i += 1
      }
    };
    
    // Add the runestone data
    for (byte in runestoneData.vals()) {
      buffer.add(byte)
    };
    
    Buffer.toArray(buffer)
  };
};
