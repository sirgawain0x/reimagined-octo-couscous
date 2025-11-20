// Rate Limiter Module for Motoko Canisters
// Implements sliding window rate limiting to prevent abuse

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Int "mo:base/Int";

module RateLimiter {
  // Rate limit entry tracking requests in current window
  public type RateLimitEntry = {
    count : Nat64;
    resetTime : Int; // Timestamp in nanoseconds when limit resets
  };

  // Rate limit configuration
  public type RateLimitConfig = {
    maxRequests : Nat64; // Maximum requests allowed
    windowMs : Nat64; // Time window in milliseconds
  };

  // Rate limit status for error messages
  public type RateLimitStatus = {
    remaining : Nat64;
    resetTime : Int; // Timestamp in nanoseconds when limit resets
    maxRequests : Nat64;
  };

  // Default configurations for different operation types
  public let DEFAULT_CONFIG : RateLimitConfig = {
    maxRequests = 100;
    windowMs = 60_000; // 1 minute
  };

  public let LENDING_CONFIG : RateLimitConfig = {
    maxRequests = 20;
    windowMs = 60_000;
  };

  public let SWAP_CONFIG : RateLimitConfig = {
    maxRequests = 30;
    windowMs = 60_000;
  };

  public let REWARDS_CONFIG : RateLimitConfig = {
    maxRequests = 50;
    windowMs = 60_000;
  };

  // In-memory storage for rate limit entries
  // Note: This is transient and will reset on canister upgrade
  // For persistent rate limiting, consider using stable storage
  public class RateLimiter(config : RateLimitConfig) {
    private var entries : HashMap.HashMap<Principal, RateLimitEntry> = HashMap.HashMap(0, Principal.equal, Principal.hash);

    // Check if request is allowed for given principal
    public func isAllowed(principal : Principal) : Bool {
      let now = Time.now();
      let entry = entries.get(principal);
      
      switch (entry) {
        case null {
          // No entry, allow request and create new entry
          // Convert milliseconds to nanoseconds (Int)
          let windowMsNat = Nat64.toNat(config.windowMs);
          let windowNs = windowMsNat * 1_000_000; // Convert ms to ns
          entries.put(principal, {
            count = 1;
            resetTime = now + windowNs;
          });
          true
        };
        case (?e) {
          if (now > e.resetTime) {
            // Window expired, reset
            // Convert milliseconds to nanoseconds (Int)
            let windowMsNat = Nat64.toNat(config.windowMs);
            let windowNs = windowMsNat * 1_000_000; // Convert ms to ns
            entries.put(principal, {
              count = 1;
              resetTime = now + windowNs;
            });
            true
          } else if (e.count < config.maxRequests) {
            // Within limit, increment count
            entries.put(principal, {
              count = e.count + 1;
              resetTime = e.resetTime;
            });
            true
          } else {
            // Rate limited
            false
          }
        }
      }
    };

    // Get remaining requests for principal
    public func getRemaining(principal : Principal) : Nat64 {
      let now = Time.now();
      let entry = entries.get(principal);
      
      switch (entry) {
        case null config.maxRequests;
        case (?e) {
          if (now > e.resetTime) {
            config.maxRequests
          } else {
            if (e.count >= config.maxRequests) {
              0
            } else {
              config.maxRequests - e.count
            }
          }
        }
      }
    };

    // Get rate limit status for error messages
    public func getStatus(principal : Principal) : RateLimitStatus {
      let now = Time.now();
      let entry = entries.get(principal);
      
      switch (entry) {
        case null {
          {
            remaining = config.maxRequests;
            resetTime = now + (Nat64.toNat(config.windowMs) * 1_000_000); // Convert ms to ns
            maxRequests = config.maxRequests;
          }
        };
        case (?e) {
          if (now > e.resetTime) {
            {
              remaining = config.maxRequests;
              resetTime = now + (Nat64.toNat(config.windowMs) * 1_000_000);
              maxRequests = config.maxRequests;
            }
          } else {
            let remaining : Nat64 = if (e.count >= config.maxRequests) {
              0 : Nat64
            } else {
              config.maxRequests - e.count
            };
            {
              remaining = remaining;
              resetTime = e.resetTime;
              maxRequests = config.maxRequests;
            }
          }
        }
      }
    };

    // Reset rate limit for principal (useful for testing)
    public func reset(principal : Principal) {
      entries.delete(principal)
    };

    // Clean up expired entries (call periodically)
    public func cleanup() {
      let now = Time.now();
      var toDelete : [Principal] = [];
      
      for ((principal, entry) in entries.entries()) {
        if (now > entry.resetTime) {
          toDelete := Array.append(toDelete, [principal])
        }
      };
      
      for (principal in toDelete.vals()) {
        entries.delete(principal)
      }
    };

    // Format rate limit error message with remaining requests and reset time
    public func formatError(principal : Principal) : Text {
      let status = getStatus(principal);
      let now = Time.now();
      let secondsUntilReset : Int = if (status.resetTime > now) {
        (status.resetTime - now) / 1_000_000_000 // Convert nanoseconds to seconds
      } else {
        0
      };
      
      let windowSecondsNat = Nat64.toNat(config.windowMs) / 1000; // Convert ms to seconds
      let windowSeconds = Nat64.fromNat(windowSecondsNat); // Convert back to Nat64 for consistency
      
      if (status.remaining == 0) {
        "Rate limit exceeded. " # Nat64.toText(status.maxRequests) # " requests per " # 
        Nat64.toText(windowSeconds) # " seconds. Please try again in " # 
        Int.toText(secondsUntilReset) # " seconds."
      } else {
        "Rate limit exceeded. " # Nat64.toText(status.remaining) # " requests remaining. " #
        "Limit resets in " # Int.toText(secondsUntilReset) # " seconds."
      }
    };
  };
};

