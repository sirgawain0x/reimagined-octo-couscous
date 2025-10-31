/**
 * Rate limiter utility for canister calls
 * Prevents excessive API calls and protects against rate limiting
 */

interface RateLimitEntry {
  count: number
  resetTime: number
}

interface RateLimitConfig {
  maxRequests: number
  windowMs: number
  identifier?: string // Optional identifier for different rate limiters
}

/**
 * In-memory rate limiter
 * Uses sliding window algorithm
 */
class RateLimiter {
  private entries: Map<string, RateLimitEntry> = new Map()
  private config: RateLimitConfig

  constructor(config: RateLimitConfig) {
    this.config = config
    // Clean up old entries periodically
    this.startCleanup()
  }

  /**
   * Check if request is allowed
   * @param key - Unique identifier for the rate limit (e.g., user principal or method name)
   * @returns true if request is allowed, false if rate limited
   */
  isAllowed(key: string): boolean {
    const now = Date.now()
    const entry = this.entries.get(key)

    // No entry or window expired, allow request
    if (!entry || now > entry.resetTime) {
      this.entries.set(key, {
        count: 1,
        resetTime: now + this.config.windowMs,
      })
      return true
    }

    // Check if within limit
    if (entry.count < this.config.maxRequests) {
      entry.count++
      return true
    }

    // Rate limited
    return false
  }

  /**
   * Get remaining requests in current window
   */
  getRemaining(key: string): number {
    const entry = this.entries.get(key)
    if (!entry) {
      return this.config.maxRequests
    }
    return Math.max(0, this.config.maxRequests - entry.count)
  }

  /**
   * Get time until rate limit resets (in milliseconds)
   */
  getResetTime(key: string): number {
    const entry = this.entries.get(key)
    if (!entry) {
      return 0
    }
    const now = Date.now()
    return Math.max(0, entry.resetTime - now)
  }

  /**
   * Reset rate limit for a key (useful for testing or manual override)
   */
  reset(key: string): void {
    this.entries.delete(key)
  }

  /**
   * Clean up expired entries periodically
   */
  private startCleanup(): void {
    // Run cleanup every 5 minutes
    setInterval(() => {
      const now = Date.now()
      for (const [key, entry] of this.entries.entries()) {
        if (now > entry.resetTime) {
          this.entries.delete(key)
        }
      }
    }, 5 * 60 * 1000)
  }
}

// Default rate limiters for different use cases
const DEFAULT_RATE_LIMITERS = {
  // General canister calls: 100 requests per minute
  general: new RateLimiter({
    maxRequests: 100,
    windowMs: 60 * 1000,
    identifier: 'general',
  }),
  
  // Lending operations: 20 requests per minute (more restrictive)
  lending: new RateLimiter({
    maxRequests: 20,
    windowMs: 60 * 1000,
    identifier: 'lending',
  }),
  
  // Swap operations: 30 requests per minute
  swap: new RateLimiter({
    maxRequests: 30,
    windowMs: 60 * 1000,
    identifier: 'swap',
  }),
  
  // Rewards operations: 50 requests per minute
  rewards: new RateLimiter({
    maxRequests: 50,
    windowMs: 60 * 1000,
    identifier: 'rewards',
  }),
}

/**
 * Check rate limit for a specific operation
 * @param type - Type of rate limiter to use
 * @param key - Unique key (e.g., user principal)
 * @throws Error if rate limited
 */
export function checkRateLimit(
  type: keyof typeof DEFAULT_RATE_LIMITERS,
  key: string
): void {
  const limiter = DEFAULT_RATE_LIMITERS[type]
  
  if (!limiter.isAllowed(key)) {
    const resetTime = limiter.getResetTime(key)
    throw new Error(
      `Rate limit exceeded. Please try again in ${Math.ceil(resetTime / 1000)} seconds.`
    )
  }
}

/**
 * Get rate limit status for a key
 */
export function getRateLimitStatus(
  type: keyof typeof DEFAULT_RATE_LIMITERS,
  key: string
): {
  remaining: number
  resetTime: number
} {
  const limiter = DEFAULT_RATE_LIMITERS[type]
  return {
    remaining: limiter.getRemaining(key),
    resetTime: limiter.getResetTime(key),
  }
}

/**
 * Create a rate-limited wrapper for async functions
 */
export function withRateLimit<T extends (...args: any[]) => Promise<any>>(
  fn: T,
  type: keyof typeof DEFAULT_RATE_LIMITERS,
  getKey: (...args: Parameters<T>) => string
): T {
  return (async (...args: Parameters<T>) => {
    const key = getKey(...args)
    checkRateLimit(type, key)
    return fn(...args)
  }) as T
}

/**
 * Reset rate limit for a key (useful for testing)
 */
export function resetRateLimit(
  type: keyof typeof DEFAULT_RATE_LIMITERS,
  key: string
): void {
  const limiter = DEFAULT_RATE_LIMITERS[type]
  limiter.reset(key)
}

