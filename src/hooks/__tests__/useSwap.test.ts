import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { useSwap } from '../useSwap'
import { createSwapActor } from '@/services/canisters'
import { createMockPrincipal } from '@/test/setup'

vi.mock('@/services/canisters')
vi.mock('@/utils/logger')
// Mock retry to actually call the functions
vi.mock('@/utils/retry', () => ({
  retry: async <T>(fn: () => Promise<T>) => await fn(),
  retryWithTimeout: async <T>(fn: () => Promise<T>) => await fn(),
}))
vi.mock('@/utils/rateLimiter', () => ({
  checkRateLimit: vi.fn(),
}))
const mockPrincipal = createMockPrincipal()
const mockUseICP = vi.fn(() => ({
  principal: mockPrincipal,
  isConnected: true,
  isLoading: false,
  connect: vi.fn(),
  setConnected: vi.fn(),
  disconnect: vi.fn(),
}))

vi.mock('./useICP', () => ({
  useICP: () => mockUseICP(),
}))

describe('useSwap', () => {
  const mockActor = {
    getQuote: vi.fn(),
    swap: vi.fn(),
    getPools: vi.fn(),
    getSwapHistory: vi.fn(),
    getCKBTCBalance: vi.fn(),
    getBTCAddress: vi.fn(),
    updateBalance: vi.fn(),
    withdrawBTC: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(createSwapActor).mockResolvedValue(mockActor as any)
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })
  })

  it('should load pools on mount', async () => {
    const mockPools = [
      {
        tokenA: { ckBTC: null },
        tokenB: { ICP: null },
        reserveA: BigInt(1000),
        reserveB: BigInt(2000),
        kLast: BigInt(2000000),
      },
    ]
    mockActor.getPools.mockResolvedValue(mockPools)

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.pools).toHaveLength(1)
    })
  })

  it('should get quote successfully', async () => {
    const mockQuote = {
      ok: {
        amountOut: BigInt(1900),
        priceImpact: 5.0,
        fee: BigInt(6),
      },
    }
    mockActor.getQuote.mockResolvedValue(mockQuote)

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const quote = await result.current.getQuote('pool1', 1000)

    expect(mockActor.getQuote).toHaveBeenCalledWith('pool1', BigInt(1000))
    expect(quote).toEqual(mockQuote.ok)
  })

  it('should handle executeSwap successfully', async () => {
    const mockSwapResult = {
      ok: {
        txIndex: BigInt(1),
        amountOut: BigInt(1900),
        priceImpact: 5.0,
      },
    }
    mockActor.swap.mockResolvedValue(mockSwapResult)
    mockActor.getPools.mockResolvedValue([])

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const swapResult = await result.current.executeSwap('pool1', 'ckBTC', BigInt(1000), BigInt(1800))

    expect(mockActor.swap).toHaveBeenCalledWith(
      'pool1',
      { ckBTC: null },
      BigInt(1000),
      BigInt(1800)
    )
    expect(swapResult.success).toBe(true)
    expect(swapResult.txIndex).toBe(BigInt(1))
  })

  it('should handle executeSwap errors', async () => {
    const errorMessage = 'Insufficient liquidity'
    mockActor.swap.mockResolvedValue({ err: errorMessage })

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const swapResult = await result.current.executeSwap('pool1', 'ckBTC', BigInt(1000), BigInt(1800))

    expect(swapResult.success).toBe(false)
  })

  it('should validate swap amount', async () => {
    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const swapResult = await result.current.executeSwap('pool1', 'ckBTC', BigInt(0), BigInt(1800))

    expect(swapResult.success).toBe(false)
    expect(mockActor.swap).not.toHaveBeenCalled()
  })

  it('should require authentication for executeSwap', async () => {
    mockUseICP.mockReturnValueOnce({
      principal: null,
      isConnected: false,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const swapResult = await result.current.executeSwap('pool1', 'ckBTC', BigInt(1000), BigInt(1800))

    expect(swapResult.success).toBe(false)
    expect(mockActor.swap).not.toHaveBeenCalled()
  })

  it('should handle getSwapHistory', async () => {
    const mockHistory = [
      {
        id: BigInt(1),
        user: mockPrincipal,
        tokenIn: { ckBTC: null },
        tokenOut: { ICP: null },
        amountIn: BigInt(1000),
        amountOut: BigInt(1900),
        timestamp: BigInt(Date.now()),
      },
    ]
    mockActor.getSwapHistory.mockResolvedValue(mockHistory)

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const history = await result.current.getSwapHistory()

    expect(mockActor.getSwapHistory).toHaveBeenCalledWith(mockPrincipal)
    expect(history.length).toBe(1)
    expect(history[0].tokenIn).toBe('ckBTC')
    expect(history[0].tokenOut).toBe('ICP')
  })

  it('should return empty history when not connected', async () => {
    mockUseICP.mockReturnValueOnce({
      principal: null,
      isConnected: false,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const history = await result.current.getSwapHistory()

    expect(history).toEqual([])
    expect(mockActor.getSwapHistory).not.toHaveBeenCalled()
  })

  it('should handle quote with zero amount', async () => {
    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const quote = await result.current.getQuote('pool1', BigInt(0))

    expect(quote).toBeNull()
    expect(mockActor.getQuote).not.toHaveBeenCalled()
  })

  it('should handle refresh', async () => {
    mockActor.getPools.mockResolvedValue([])

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.refresh()

    expect(mockActor.getPools).toHaveBeenCalledTimes(2) // Initial + refresh
  })
})

