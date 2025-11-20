import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { useRewards } from '../useRewards'
import { createRewardsActor } from '@/services/canisters'
import { createMockPrincipal } from '@/test/setup'

vi.mock('@/services/canisters')
vi.mock('@/utils/logger')
vi.mock('@/utils/retry')
vi.mock('@/utils/rateLimiter')
const mockUseICP = vi.fn(() => ({
  principal: createMockPrincipal(),
  isConnected: true,
  isLoading: false,
}))

vi.mock('./useICP', () => ({
  useICP: () => mockUseICP(),
}))

describe('useRewards', () => {
  const mockActor = {
    getStores: vi.fn(),
    purchase: vi.fn(),
    getUserRewards: vi.fn(),
    claimRewards: vi.fn(),
    getUserRewardAddress: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(createRewardsActor).mockResolvedValue(mockActor as any)
    mockUseICP.mockReturnValue({
      principal: createMockPrincipal(),
      isConnected: true,
      isLoading: false,
    })
  })

  it('should load stores on mount', async () => {
    const mockStores = [
      {
        id: 1,
        name: 'Test Store',
        reward: 5.0,
        logo: 'https://example.com/logo.png',
        url: { some: 'https://example.com' },
        runeReward: 2.0,
        runeName: null,
        runeId: null,
      },
    ]
    mockActor.getStores.mockResolvedValue(mockStores)

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.stores).toHaveLength(1)
    })
  })

  it('should handle trackPurchase successfully', async () => {
    const mockReceipt = {
      ok: {
        purchaseId: BigInt(1),
        rewardEarned: BigInt(50 * 1e8), // 50 BTC in nat64
        runeTokenRewardEarned: BigInt(20 * 1e8),
      },
    }
    mockActor.trackPurchase.mockResolvedValue(mockReceipt)

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const purchaseResult = await result.current.trackPurchase(1, 1000)

    expect(mockActor.trackPurchase).toHaveBeenCalledWith(1, BigInt(1000 * 1e8))
    expect(purchaseResult.success).toBe(true)
    expect(purchaseResult.reward).toBe(50)
    expect(result.current.error).toBeNull()
  })

  it('should handle trackPurchase errors', async () => {
    const errorMessage = 'Insufficient funds'
    mockActor.trackPurchase.mockResolvedValue({ err: errorMessage })

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const purchaseResult = await result.current.trackPurchase(1, 1000)

    expect(purchaseResult.success).toBe(false)
    expect(purchaseResult.error).toBe(errorMessage)
  })

  it('should validate purchase amount', async () => {
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
    } as any)

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

