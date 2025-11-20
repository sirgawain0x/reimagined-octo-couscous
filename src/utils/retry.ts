/**
 * Retry utility for canister calls with exponential backoff
 * Handles transient errors and provides configurable retry logic
 */

import { logWarn } from './logger'

export interface RetryOptions {
  maxRetries?: number
  initialDelayMs?: number
  maxDelayMs?: number
  backoffMultiplier?: number
  retryableErrors?: string[]
  onRetry?: (attempt: number, error: Error) => void
}

const DEFAULT_OPTIONS: Required<RetryOptions> = {
  maxRetries: 3,
  initialDelayMs: 1000,
  maxDelayMs: 10000,
  backoffMultiplier: 2,
  retryableErrors: [],
  onRetry: () => {},
}

/**
 * Determines if an error is retryable
 */
function isRetryableError(error: Error, retryableErrors: string[]): boolean {
  const errorMessage = error.message.toLowerCase()
  
  // Check for specific retryable error patterns
  const retryablePatterns = [
    'network',
    'timeout',
    'connection',
    'transient',
    'system_unknown',
    'system_transient',
    'temporarily unavailable',
    'rate limit',
    'too many requests',
  ]
  
  // Check if error message matches retryable patterns
  if (retryablePatterns.some(pattern => errorMessage.includes(pattern))) {
    return true
  }
  
  // Check custom retryable errors
  if (retryableErrors.some(pattern => errorMessage.includes(pattern.toLowerCase()))) {
    return true
  }
  
  return false
}

/**
 * Calculate delay with exponential backoff
 */
function calculateDelay(attempt: number, options: Required<RetryOptions>): number {
  const delay = options.initialDelayMs * Math.pow(options.backoffMultiplier, attempt - 1)
  return Math.min(delay, options.maxDelayMs)
}

/**
 * Sleep for specified milliseconds
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

/**
 * Retry a function with exponential backoff
 * 
 * @param fn - Function to retry (should return a Promise)
 * @param options - Retry configuration options
 * @returns Promise that resolves with the function result or rejects after max retries
 * 
 * @example
 * ```typescript
 * const result = await retry(
 *   () => canister.someMethod(args),
 *   { maxRetries: 3, initialDelayMs: 1000 }
 * )
 * ```
 */
export async function retry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const opts = { ...DEFAULT_OPTIONS, ...options }
  let lastError: Error | null = null
  
  for (let attempt = 1; attempt <= opts.maxRetries; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error as Error
      
      // Don't retry if it's the last attempt or error is not retryable
      if (attempt === opts.maxRetries || !isRetryableError(lastError, opts.retryableErrors)) {
        throw lastError
      }
      
      // Calculate delay and wait before retrying
      const delay = calculateDelay(attempt, opts)
      
      logWarn(`Retry attempt ${attempt}/${opts.maxRetries} after ${delay}ms`, {
        error: lastError.message,
        attempt,
        maxRetries: opts.maxRetries,
      })
      
      opts.onRetry(attempt, lastError)
      
      await sleep(delay)
    }
  }
  
  // This should never be reached, but TypeScript needs it
  throw lastError || new Error('Retry failed: unknown error')
}

/**
 * Retry with timeout
 * 
 * @param fn - Function to retry
 * @param timeoutMs - Maximum time to wait in milliseconds
 * @param options - Additional retry options
 */
export async function retryWithTimeout<T>(
  fn: () => Promise<T>,
  timeoutMs: number,
  options: RetryOptions = {}
): Promise<T> {
  return Promise.race([
    retry(fn, options),
    new Promise<never>((_, reject) => {
      setTimeout(() => {
        reject(new Error(`Operation timed out after ${timeoutMs}ms`))
      }, timeoutMs)
    }),
  ])
}

