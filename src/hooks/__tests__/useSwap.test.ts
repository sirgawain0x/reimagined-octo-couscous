import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { useSwap } from '../useSwap'
import { createSwapActor } from '@/services/canisters'
import { createMockPrincipal } from '@/test/setup'

vi.mock('@/services/canisters')
vi.mock('@/utils/logger')
vi.mock('@/utils/retry')
vi.mock('@/utils/rateLimiter')
vi.mock('./useICP', () => ({
  useICP: () => ({
    principal: createMockPrincipal(),
    isConnected: true,
  }),
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

  it('should handle swap successfully', async () => {
    const mockSwapResult = {
      ok: {
        txIndex: BigInt(1),
        amountOut: BigInt(1900),
        priceImpact: 5.0,
      },
    }
    mockActor.swap.mockResolvedValue(mockSwapResult)

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.swap('pool1', { ckBTC: null }, 1000, 1800)

    expect(mockActor.swap).toHaveBeenCalledWith(
      'pool1',
      { ckBTC: null },
      BigInt(1000),
      BigInt(1800)
    )
    expect(result.current.error).toBeNull()
  })

  it('should handle swap errors', async () => {
    const errorMessage = 'Insufficient liquidity'
    mockActor.swap.mockResolvedValue({ err: errorMessage })

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.swap('pool1', { ckBTC: null }, 1000, 1800)

    expect(result.current.error).toBe(errorMessage)
  })

  it('should get ckBTC balance', async () => {
    const mockBalance = BigInt(1000000)
    mockActor.getCKBTCBalance.mockResolvedValue(mockBalance)

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const balance = await result.current.getCKBTCBalance()

    expect(mockActor.getCKBTCBalance).toHaveBeenCalled()
    expect(balance).toBe(mockBalance)
  })

  it('should get BTC address', async () => {
    const mockAddress = 'bc1qtest123'
    mockActor.getBTCAddress.mockResolvedValue(mockAddress)

    const { result } = renderHook(() => useSwap())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const address = await result.current.getBTCAddress()

    expect(mockActor.getBTCAddress).toHaveBeenCalled()
    expect(address).toBe(mockAddress)
  })
})

