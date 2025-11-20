import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { usePortfolio } from '../usePortfolio'
import { createPortfolioActor } from '@/services/canisters'
import { createMockPrincipal } from '@/test/setup'

vi.mock('@/services/canisters')
vi.mock('@/utils/logger')
const mockUseICP = vi.fn(() => ({
  principal: createMockPrincipal(),
  isConnected: true,
  isLoading: false,
}))

vi.mock('./useICP', () => ({
  useICP: () => mockUseICP(),
}))

describe('usePortfolio', () => {
  const mockActor = {
    getPortfolio: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(createPortfolioActor).mockResolvedValue(mockActor as any)
  })

  it('should load portfolio on mount when connected', async () => {
    const mockPortfolio = {
      totalValue: 12450.75,
      totalRewards: BigInt(1250000), // 0.0125 BTC in nat64
      totalLended: 8000.0,
      assets: [
        { name: 'Bitcoin', symbol: 'BTC', amount: BigInt(1500000000), value: 9000.5 }, // 0.15 BTC
        { name: 'Ethereum', symbol: 'ETH', amount: BigInt(100000000), value: 3000.25 }, // 1.0 ETH
      ],
    }
    mockActor.getPortfolio.mockResolvedValue(mockPortfolio)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.portfolio).toBeDefined()
    expect(result.current.portfolio?.totalValue).toBe(12450.75)
    expect(result.current.portfolio?.totalRewards).toBe(0.0125)
    expect(result.current.portfolio?.assets.length).toBe(2)
  })

  it('should not load portfolio when not connected', async () => {
    mockUseICP.mockReturnValueOnce({
      principal: null,
      isConnected: false,
      isLoading: false,
    } as any)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.portfolio).toBeNull()
    expect(mockActor.getPortfolio).not.toHaveBeenCalled()
  })

  it('should handle portfolio loading errors gracefully', async () => {
    mockActor.getPortfolio.mockRejectedValue(new Error('Network error'))

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    // Should have empty portfolio on error
    expect(result.current.portfolio).toBeDefined()
    expect(result.current.portfolio?.totalValue).toBe(0)
    expect(result.current.portfolio?.assets.length).toBe(0)
    expect(result.current.error).toBeDefined()
  })

  it('should handle TrustError (network mismatch)', async () => {
    const error = new Error('TrustError: node signatures')
    error.name = 'TrustError'
    mockActor.getPortfolio.mockRejectedValue(error)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.error).toContain('network mismatch')
  })

  it('should handle canister not found errors', async () => {
    const error = new Error('Invalid canister ID')
    mockActor.getPortfolio.mockRejectedValue(error)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.error).toContain('not deployed')
  })

  it('should refresh portfolio', async () => {
    const mockPortfolio = {
      totalValue: 1000,
      totalRewards: BigInt(0),
      totalLended: 500,
      assets: [],
    }
    mockActor.getPortfolio.mockResolvedValue(mockPortfolio)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.refresh()

    expect(mockActor.getPortfolio).toHaveBeenCalledTimes(2) // Initial + refresh
  })

  it('should convert nat64 amounts correctly', async () => {
    const mockPortfolio = {
      totalValue: 1000,
      totalRewards: BigInt(100000000), // 1.0 BTC in nat64
      totalLended: 500,
      assets: [
        { name: 'Bitcoin', symbol: 'BTC', amount: BigInt(500000000), value: 1000 }, // 0.5 BTC
      ],
    }
    mockActor.getPortfolio.mockResolvedValue(mockPortfolio)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.portfolio?.totalRewards).toBe(1.0)
    expect(result.current.portfolio?.assets[0].amount).toBe(0.5)
  })
})

