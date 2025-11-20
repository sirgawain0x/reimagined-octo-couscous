import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { useRewards } from '../useRewards'
import { createRewardsActor } from '@/services/canisters'
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

  it('should handle purchase successfully', async () => {
    const mockReceipt = {
      ok: {
        purchaseId: BigInt(1),
        storeId: 1,
        amount: BigInt(1000),
        reward: BigInt(50),
        timestamp: BigInt(Date.now()),
      },
    }
    mockActor.purchase.mockResolvedValue(mockReceipt)

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.purchase(1, 1000)

    expect(mockActor.purchase).toHaveBeenCalledWith(1, BigInt(1000))
    expect(result.current.error).toBeNull()
  })

  it('should handle purchase errors', async () => {
    const errorMessage = 'Insufficient funds'
    mockActor.purchase.mockResolvedValue({ err: errorMessage })

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.purchase(1, 1000)

    expect(result.current.error).toBe(errorMessage)
  })

  it('should load user rewards', async () => {
    const mockRewards = BigInt(5000)
    mockActor.getUserRewards.mockResolvedValue(mockRewards)

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.rewards).toBe(5000)
    })
  })

  it('should handle claim rewards successfully', async () => {
    const mockTx = {
      ok: {
        txid: 'test-tx-id',
        amount: BigInt(5000),
      },
    }
    mockActor.claimRewards.mockResolvedValue(mockTx)

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.claimRewards()

    expect(mockActor.claimRewards).toHaveBeenCalled()
    expect(result.current.error).toBeNull()
  })

  it('should get user reward address', async () => {
    const mockAddress = 'bc1qtest123'
    mockActor.getUserRewardAddress.mockResolvedValue({ ok: mockAddress })

    const { result } = renderHook(() => useRewards())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const address = await result.current.getRewardAddress()

    expect(mockActor.getUserRewardAddress).toHaveBeenCalled()
    expect(address).toBe(mockAddress)
  })
})

