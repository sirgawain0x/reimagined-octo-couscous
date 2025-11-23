import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { useLending } from '../useLending'
import { createLendingActor } from '../../services/canisters'
import { Principal } from '@dfinity/principal'
import { createMockPrincipal } from '../../test/setup'

// Mock dependencies
vi.mock('../../services/canisters')
vi.mock('../../utils/logger')
// Mock retry to actually call the functions
vi.mock('../../utils/retry', () => ({
  retry: async <T>(fn: () => Promise<T>) => await fn(),
  retryWithTimeout: async <T>(fn: () => Promise<T>) => await fn(),
}))
vi.mock('../../utils/rateLimiter', () => ({
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

describe('useLending', () => {
  const mockActor = {
    getLendingAssets: vi.fn(),
    getUserDeposits: vi.fn(),
    getUserBorrows: vi.fn(),
    getAvailableLiquidity: vi.fn(),
    deposit: vi.fn(),
    withdraw: vi.fn(),
    borrow: vi.fn(),
    repay: vi.fn(),
    getBitcoinDepositAddress: vi.fn(),
    getUserBitcoinDepositAddress: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(createLendingActor).mockResolvedValue(mockActor as any)
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })
  })

  it('should load lending assets on mount', async () => {
    const mockAssets = [
      { id: 'btc', name: 'Bitcoin', symbol: 'BTC', apy: 4.2 },
      { id: 'eth', name: 'Ethereum', symbol: 'ETH', apy: 5.1 },
    ]
    mockActor.getLendingAssets.mockResolvedValue(mockAssets)
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.assets).toHaveLength(2)
      expect(result.current.assets[0].id).toBe('btc')
    })
  })

  it('should handle deposit successfully', async () => {
    const mockDepositId = BigInt(1)
    mockActor.deposit.mockResolvedValue({ ok: mockDepositId })
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const depositResult = await result.current.deposit('btc', 1000)

    // Hook converts human-readable amount (1000 BTC) to satoshi-like format (1000 * 1e8)
    expect(mockActor.deposit).toHaveBeenCalledWith('btc', BigInt(1000 * 1e8))
    expect(depositResult).toBe(true)
    expect(result.current.error).toBeNull()
  })

  it('should handle deposit errors', async () => {
    const errorMessage = 'Insufficient balance'
    mockActor.deposit.mockResolvedValue({ err: errorMessage })
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const depositResult = await result.current.deposit('btc', 1000)

    expect(depositResult).toBe(false)
    expect(result.current.error).toBe(errorMessage)
  })

  it('should handle withdrawal successfully', async () => {
    const mockWithdrawal = { txid: 'test-tx-id', amount: BigInt(500) }
    mockActor.withdraw.mockResolvedValue({ ok: mockWithdrawal })
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const withdrawResult = await result.current.withdraw('btc', 500, 'test-address')

    // Hook converts human-readable amount (500 BTC) to satoshi-like format (500 * 1e8)
    expect(mockActor.withdraw).toHaveBeenCalledWith('btc', BigInt(500 * 1e8), 'test-address')
    expect(withdrawResult).toBe(true)
    expect(result.current.error).toBeNull()
  })

  it('should handle borrow successfully', async () => {
    const mockBorrowId = BigInt(1)
    mockActor.borrow.mockResolvedValue({ ok: mockBorrowId })
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const borrowResult = await result.current.borrow('btc', 1000, 'eth', 2000)

    // Hook converts human-readable amounts to satoshi-like format
    expect(mockActor.borrow).toHaveBeenCalledWith('btc', BigInt(1000 * 1e8), 'eth', BigInt(2000 * 1e8))
    expect(borrowResult).toBe(true)
    expect(result.current.error).toBeNull()
  })

  it('should handle repay successfully', async () => {
    mockActor.repay.mockResolvedValue({ ok: null })
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const repayResult = await result.current.repay(BigInt(1), 500)

    // Hook converts human-readable amount (500) to satoshi-like format (500 * 1e8)
    expect(mockActor.repay).toHaveBeenCalledWith(BigInt(1), BigInt(500 * 1e8))
    expect(repayResult).toBe(true)
    expect(result.current.error).toBeNull()
  })

  it('should load user deposits', async () => {
    const mockDeposits = [
      { asset: 'btc', amount: BigInt(1000 * 1e8), apy: 4.2 },
      { asset: 'eth', amount: BigInt(500 * 1e8), apy: 5.1 },
    ]
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))
    mockActor.getUserDeposits.mockResolvedValue(mockDeposits)

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    await waitFor(() => {
      expect(result.current.deposits).toHaveLength(2)
    }, { timeout: 5000 })
  })

  it('should load user borrows', async () => {
    const mockBorrows = [
      {
        id: BigInt(1),
        asset: 'btc',
        borrowedAmount: BigInt(1000 * 1e8),
        collateralAmount: BigInt(2000 * 1e8),
        collateralAsset: 'eth',
        interestRate: 6.3,
        ltv: 0.5,
      },
    ]
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))
    mockActor.getUserBorrows.mockResolvedValue(mockBorrows)

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    await waitFor(() => {
      expect(result.current.borrows).toHaveLength(1)
    }, { timeout: 5000 })
  })

  it('should handle loading states correctly', async () => {
    mockActor.getLendingAssets.mockImplementation(() => new Promise(() => {})) // Never resolves

    const { result } = renderHook(() => useLending())

    expect(result.current.isLoading).toBe(true)
  })

  it('should load available liquidity', async () => {
    const mockAssets = [
      { id: 'btc', name: 'Bitcoin', symbol: 'BTC', apy: 4.2 },
    ]
    mockActor.getLendingAssets.mockResolvedValue(mockAssets)
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(1000000000)) // 10 BTC in nat64

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.availableLiquidity['btc']).toBe(10)
  })

  it('should handle Bitcoin deposit validation', async () => {
    // Bitcoin deposit validation happens in the canister
    // The hook calls deposit which triggers validation
    const mockDepositId = BigInt(1)
    mockActor.deposit.mockResolvedValue({ ok: mockDepositId })
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const success = await result.current.deposit('btc', 1000)

    expect(mockActor.deposit).toHaveBeenCalledWith('btc', BigInt(1000 * 1e8))
    expect(success).toBe(true)
  })

  it('should handle withdrawal errors', async () => {
    const errorMessage = 'Insufficient funds'
    mockActor.withdraw.mockResolvedValue({ err: errorMessage })
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const withdrawResult = await result.current.withdraw('btc', 500, 'test-address')

    expect(withdrawResult).toBe(false)
    expect(result.current.error).toBe(errorMessage)
  })

  it('should handle borrow errors', async () => {
    const errorMessage = 'Insufficient collateral'
    mockActor.borrow.mockResolvedValue({ err: errorMessage })
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const borrowResult = await result.current.borrow('btc', 1000, 'eth', 2000)

    expect(borrowResult).toBe(false)
    expect(result.current.error).toBe(errorMessage)
  })

  it('should handle repay errors', async () => {
    const errorMessage = 'Borrow not found'
    mockActor.repay.mockResolvedValue({ err: errorMessage })
    mockActor.getLendingAssets.mockResolvedValue([])
    mockActor.getAvailableLiquidity.mockResolvedValue(BigInt(0))

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const repayResult = await result.current.repay(BigInt(1), 500)

    expect(repayResult).toBe(false)
    expect(result.current.error).toBe(errorMessage)
  })

  it('should refresh data', async () => {
    mockActor.getLendingAssets.mockResolvedValue([])

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.refresh()

    expect(mockActor.getLendingAssets).toHaveBeenCalledTimes(2) // Initial + refresh
  })
})

