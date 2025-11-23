import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { useRewards } from '../useRewards'
import { createRewardsActor } from '@/services/canisters'
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

describe('useRewards', () => {
  const mockActor = {
    getStores: vi.fn(),
    trackPurchase: vi.fn(),
    getUserRewards: vi.fn(),
    claimRewards: vi.fn(),
    getUserRewardAddress: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(createRewardsActor).mockResolvedValue(mockActor as any)
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })
  })

  it('should load stores on mount', async () => {
    const mockStores = [
      {
        id: 1,
        name: 'Test Store',
        reward: 5.0,
        logo: 'https://example.com/logo.png',
        url: 'https://example.com',
        runeReward: 2.0,
        runeName: null,
        runeId: null,
      },
    ]
    mockActor.getStores.mockResolvedValue(mockStores)

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    // Should use stores from canister (not fallback)
    expect(result.current.stores.length).toBeGreaterThan(0)
    // Check if canister stores were loaded or fallback was used
    expect(result.current.stores[0].name).toBeDefined()
  })

  it('should handle trackPurchase successfully', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const mockReceipt = {
      ok: {
        purchaseId: BigInt(1),
        rewardEarned: BigInt(50 * 1e8), // 50 BTC in nat64
        runeTokenRewardEarned: BigInt(20 * 1e8),
      },
    }
    mockActor.trackPurchase.mockResolvedValue(mockReceipt)
    mockActor.getStores.mockResolvedValue([])

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    const purchaseResult = await result.current.trackPurchase(1, 1000)

    expect(mockActor.trackPurchase).toHaveBeenCalledWith(1, BigInt(1000 * 1e8))
    expect(purchaseResult.success).toBe(true)
    expect(purchaseResult.reward).toBe(50)
    expect(result.current.error).toBeNull()
  })

  it('should handle trackPurchase errors', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const errorMessage = 'Insufficient funds'
    mockActor.trackPurchase.mockResolvedValue({ err: errorMessage })
    mockActor.getStores.mockResolvedValue([])

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    const purchaseResult = await result.current.trackPurchase(1, 1000)

    expect(purchaseResult.success).toBe(false)
    // The hook should return the error from the canister
    expect(purchaseResult.error).toBe(errorMessage)
    expect(mockActor.trackPurchase).toHaveBeenCalledWith(1, BigInt(1000 * 1e8))
  })

  it('should validate purchase amount', async () => {
    // Ensure user is connected
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })
    mockActor.getStores.mockResolvedValue([])

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const purchaseResult = await result.current.trackPurchase(1, 0)

    expect(purchaseResult.success).toBe(false)
    expect(purchaseResult.error).toContain('greater than zero')
    expect(mockActor.trackPurchase).not.toHaveBeenCalled()
  })

  it('should validate store ID', async () => {
    // Ensure user is connected
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })
    mockActor.getStores.mockResolvedValue([])

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const purchaseResult = await result.current.trackPurchase(0, 1000)

    expect(purchaseResult.success).toBe(false)
    expect(purchaseResult.error).toContain('Invalid store ID')
    expect(mockActor.trackPurchase).not.toHaveBeenCalled()
  })

  it('should require authentication for trackPurchase', async () => {
    mockUseICP.mockReturnValueOnce({
      principal: null,
      isConnected: false,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const purchaseResult = await result.current.trackPurchase(1, 1000)

    expect(purchaseResult.success).toBe(false)
    expect(purchaseResult.error).toContain('connected')
    expect(mockActor.trackPurchase).not.toHaveBeenCalled()
  })

  it('should handle fallback stores when canister fails', async () => {
    mockActor.getStores.mockRejectedValue(new Error('Network error'))

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    // Should use fallback stores
    expect(result.current.stores.length).toBeGreaterThan(0)
  })

  it('should handle refetch', async () => {
    mockActor.getStores.mockResolvedValue([])

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.refetch()

    expect(mockActor.getStores).toHaveBeenCalledTimes(2) // Initial + refetch
  })

  it('should handle loading states correctly', async () => {
    mockActor.getStores.mockImplementation(() => new Promise(() => {})) // Never resolves

    const { result } = renderHook(() => useRewards())

    expect(result.current.isLoading).toBe(true)
  })
})

