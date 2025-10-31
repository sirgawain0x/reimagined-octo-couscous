// Rate Limiter Module for Motoko Canisters
// Implements sliding window rate limiting to prevent abuse

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Int64 "mo:base/Int64";
import Array "mo:base/Array";
import Hash "mo:base/Hash";

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
          let windowNs = Int64.fromIntWrap(Nat64.toNat(config.windowMs)) * 1_000_000; // Convert ms to ns
          entries.put(principal, {
            count = 1;
            resetTime = now + windowNs;
          });
          true
        };
        case (?e) {
          if (now > e.resetTime) {
            // Window expired, reset
            let windowNs = Int64.fromIntWrap(Nat64.toNat(config.windowMs)) * 1_000_000;
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
  };
};

