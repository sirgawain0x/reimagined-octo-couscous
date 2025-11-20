import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { useLending } from '../useLending'
import { createLendingActor } from '@/services/canisters'
import { Principal } from '@dfinity/principal'
import { createMockPrincipal } from '@/test/setup'

// Mock dependencies
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

describe('useLending', () => {
  const mockPrincipal = createMockPrincipal()
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
  })

  it('should load lending assets on mount', async () => {
    const mockAssets = [
      { id: 'btc', name: 'Bitcoin', symbol: 'BTC', apy: 4.2 },
      { id: 'eth', name: 'Ethereum', symbol: 'ETH', apy: 5.1 },
    ]
    mockActor.getLendingAssets.mockResolvedValue(mockAssets)

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.assets).toHaveLength(2)
      expect(result.current.assets[0].id).toBe('btc')
    })
  })

  it('should handle deposit successfully', async () => {
    const mockDepositId = BigInt(1)
    mockActor.deposit.mockResolvedValue({ ok: mockDepositId })

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.deposit('btc', 1000)

    expect(mockActor.deposit).toHaveBeenCalledWith('btc', BigInt(1000))
    expect(result.current.error).toBeNull()
  })

  it('should handle deposit errors', async () => {
    const errorMessage = 'Insufficient balance'
    mockActor.deposit.mockResolvedValue({ err: errorMessage })

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.deposit('btc', 1000)

    expect(result.current.error).toBe(errorMessage)
  })

  it('should handle withdrawal successfully', async () => {
    const mockWithdrawal = { txid: 'test-tx-id', amount: BigInt(500) }
    mockActor.withdraw.mockResolvedValue({ ok: mockWithdrawal })

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.withdraw('btc', 500, 'test-address')

    expect(mockActor.withdraw).toHaveBeenCalledWith('btc', BigInt(500), 'test-address')
    expect(result.current.error).toBeNull()
  })

  it('should handle borrow successfully', async () => {
    const mockBorrowId = BigInt(1)
    mockActor.borrow.mockResolvedValue({ ok: mockBorrowId })

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.borrow('btc', 1000, 'eth', 2000)

    expect(mockActor.borrow).toHaveBeenCalledWith('btc', BigInt(1000), 'eth', BigInt(2000))
    expect(result.current.error).toBeNull()
  })

  it('should handle repay successfully', async () => {
    mockActor.repay.mockResolvedValue({ ok: null })

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.repay(BigInt(1), 500)

    expect(mockActor.repay).toHaveBeenCalledWith(BigInt(1), BigInt(500))
    expect(result.current.error).toBeNull()
  })

  it('should load user deposits', async () => {
    const mockDeposits = [
      { asset: 'btc', amount: BigInt(1000), apy: 4.2 },
      { asset: 'eth', amount: BigInt(500), apy: 5.1 },
    ]
    mockActor.getUserDeposits.mockResolvedValue(mockDeposits)

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.deposits).toHaveLength(2)
    })
  })

  it('should load user borrows', async () => {
    const mockBorrows = [
      {
        id: BigInt(1),
        asset: 'btc',
        borrowedAmount: BigInt(1000),
        collateralAmount: BigInt(2000),
        collateralAsset: 'eth',
        interestRate: 6.3,
        ltv: 0.5,
      },
    ]
    mockActor.getUserBorrows.mockResolvedValue(mockBorrows)

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.borrows).toHaveLength(1)
    })
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

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.withdraw('btc', 500, 'test-address')

    expect(result.current.error).toBe(errorMessage)
  })

  it('should handle borrow errors', async () => {
    const errorMessage = 'Insufficient collateral'
    mockActor.borrow.mockResolvedValue({ err: errorMessage })

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.borrow('btc', 1000, 'eth', 2000)

    expect(result.current.error).toBe(errorMessage)
  })

  it('should handle repay errors', async () => {
    const errorMessage = 'Borrow not found'
    mockActor.repay.mockResolvedValue({ err: errorMessage })

    const { result } = renderHook(() => useLending())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.repay(BigInt(1), 500)

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

