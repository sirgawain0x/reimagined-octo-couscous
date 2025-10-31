/**
 * Tests for retry utility
 */

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { retry, retryWithTimeout } from '../retry'

describe('retry', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('should succeed on first attempt', async () => {
    const fn = vi.fn().mockResolvedValue('success')
    const result = await retry(fn)
    expect(result).toBe('success')
    expect(fn).toHaveBeenCalledTimes(1)
  })

  it('should retry on retryable errors', async () => {
    const fn = vi
      .fn()
      .mockRejectedValueOnce(new Error('network error'))
      .mockRejectedValueOnce(new Error('timeout'))
      .mockResolvedValue('success')

    const result = await retry(fn, { maxRetries: 3 })
    expect(result).toBe('success')
    expect(fn).toHaveBeenCalledTimes(3)
  })

  it('should fail after max retries', async () => {
    const fn = vi.fn().mockRejectedValue(new Error('network error'))
    await expect(retry(fn, { maxRetries: 2 })).rejects.toThrow('network error')
    expect(fn).toHaveBeenCalledTimes(2)
  })

  it('should not retry non-retryable errors', async () => {
    const fn = vi.fn().mockRejectedValue(new Error('validation error'))
    await expect(retry(fn)).rejects.toThrow('validation error')
    expect(fn).toHaveBeenCalledTimes(1)
  })

  it('should use exponential backoff', async () => {
    const delays: number[] = []
    const fn = vi
      .fn()
      .mockImplementationOnce(() => {
        delays.push(Date.now())
        throw new Error('network error')
      })
      .mockImplementationOnce(() => {
        delays.push(Date.now())
        throw new Error('network error')
      })
      .mockResolvedValue('success')

    const start = Date.now()
    await retry(fn, { maxRetries: 3, initialDelayMs: 100 })
    const end = Date.now()

    // Should have waited at least 100ms (first retry delay)
    expect(end - start).toBeGreaterThanOrEqual(90) // Allow some margin
    expect(fn).toHaveBeenCalledTimes(3)
  })

  it('should respect custom retryable errors', async () => {
    const fn = vi
      .fn()
      .mockRejectedValueOnce(new Error('custom error'))
      .mockResolvedValue('success')

    const result = await retry(fn, {
      retryableErrors: ['custom error'],
    })
    expect(result).toBe('success')
    expect(fn).toHaveBeenCalledTimes(2)
  })

  it('should call onRetry callback', async () => {
    const onRetry = vi.fn()
    const fn = vi
      .fn()
      .mockRejectedValueOnce(new Error('network error'))
      .mockResolvedValue('success')

    await retry(fn, { onRetry, maxRetries: 3 })
    expect(onRetry).toHaveBeenCalledTimes(1)
    expect(onRetry).toHaveBeenCalledWith(1, expect.any(Error))
  })
})

describe('retryWithTimeout', () => {
  it('should timeout if operation takes too long', async () => {
    const fn = vi.fn().mockImplementation(
      () => new Promise(resolve => setTimeout(() => resolve('success'), 2000))
    )

    await expect(retryWithTimeout(fn, 1000)).rejects.toThrow('timed out')
  })

  it('should succeed if operation completes before timeout', async () => {
    const fn = vi.fn().mockResolvedValue('success')
    const result = await retryWithTimeout(fn, 1000)
    expect(result).toBe('success')
  })
})

