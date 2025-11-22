import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { usePortfolio } from '../usePortfolio'
import { createPortfolioActor } from '@/services/canisters'
import { createMockPrincipal } from '@/test/setup'

vi.mock('@/services/canisters')
vi.mock('@/utils/logger')
// Mock retry to actually call the functions
vi.mock('@/utils/retry', () => ({
  retry: async <T>(fn: () => Promise<T>) => await fn(),
  retryWithTimeout: async <T>(fn: () => Promise<T>) => await fn(),
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

describe('usePortfolio', () => {
  const mockActor = {
    getPortfolio: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(createPortfolioActor).mockResolvedValue(mockActor as any)
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })
  })

  it('should load portfolio on mount when connected', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const mockPortfolio = {
      totalValue: 12450.75,
      totalRewards: BigInt(1250000), // 0.0125 BTC in nat64
      totalLended: 8000.0,
      totalBorrowed: 2000.0,
      assets: [
        { name: 'Bitcoin', symbol: 'BTC', amount: BigInt(1500000000), value: 9000.5 }, // 0.15 BTC
        { name: 'Ethereum', symbol: 'ETH', amount: BigInt(100000000), value: 3000.25 }, // 1.0 ETH
      ],
    }
    mockActor.getPortfolio.mockResolvedValue(mockPortfolio)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    await waitFor(() => {
      expect(result.current.portfolio).toBeDefined()
    }, { timeout: 5000 })

    expect(result.current.portfolio?.totalValue).toBe(12450.75)
    expect(result.current.portfolio?.totalRewards).toBe(0.0125)
    expect(result.current.portfolio?.totalBorrowed).toBe(2000.0)
    expect(result.current.portfolio?.assets.length).toBe(2)
  })

  it('should not load portfolio when not connected', async () => {
    mockUseICP.mockReturnValueOnce({
      principal: null,
      isConnected: false,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.portfolio).toBeNull()
    expect(mockActor.getPortfolio).not.toHaveBeenCalled()
  })

  it('should handle portfolio loading errors gracefully', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    mockActor.getPortfolio.mockRejectedValue(new Error('Network error'))

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    // Should have empty portfolio on error
    await waitFor(() => {
      expect(result.current.portfolio).toBeDefined()
    }, { timeout: 5000 })

    expect(result.current.portfolio?.totalValue).toBe(0)
    expect(result.current.portfolio?.totalBorrowed).toBe(0)
    expect(result.current.portfolio?.assets.length).toBe(0)
    expect(result.current.error).toBeDefined()
  })

  it('should handle TrustError (network mismatch)', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const error = new Error('TrustError: node signatures')
    error.name = 'TrustError'
    mockActor.getPortfolio.mockRejectedValue(error)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    await waitFor(() => {
      expect(result.current.error).toBeTruthy()
    }, { timeout: 5000 })

    expect(result.current.error).toContain('network mismatch')
  })

  it('should handle canister not found errors', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const error = new Error('contains no Wasm module')
    mockActor.getPortfolio.mockRejectedValue(error)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    await waitFor(() => {
      expect(result.current.error).toBeTruthy()
    }, { timeout: 5000 })

    expect(result.current.error).toContain('not deployed')
  })

  it('should refresh portfolio', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const mockPortfolio = {
      totalValue: 1000,
      totalRewards: BigInt(0),
      totalLended: 500,
      totalBorrowed: 100,
      assets: [],
    }
    mockActor.getPortfolio.mockResolvedValue(mockPortfolio)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    await waitFor(() => {
      expect(mockActor.getPortfolio).toHaveBeenCalled()
    }, { timeout: 5000 })

    const callCountBefore = mockActor.getPortfolio.mock.calls.length
    await result.current.refresh()
    
    await waitFor(() => {
      expect(mockActor.getPortfolio.mock.calls.length).toBeGreaterThan(callCountBefore)
    }, { timeout: 5000 })
  })

  it('should convert nat64 amounts correctly', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const mockPortfolio = {
      totalValue: 1000,
      totalRewards: BigInt(100000000), // 1.0 BTC in nat64
      totalLended: 500,
      totalBorrowed: 200,
      assets: [
        { name: 'Bitcoin', symbol: 'BTC', amount: BigInt(500000000), value: 1000 }, // 0.5 BTC
      ],
    }
    mockActor.getPortfolio.mockResolvedValue(mockPortfolio)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    await waitFor(() => {
      expect(result.current.portfolio).toBeDefined()
    }, { timeout: 5000 })

    expect(result.current.portfolio?.totalRewards).toBe(1.0)
    expect(result.current.portfolio?.totalBorrowed).toBe(200)
    expect(result.current.portfolio?.assets[0].amount).toBe(0.5)
  })

  it('should handle totalBorrowed calculation correctly', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const mockPortfolio = {
      totalValue: 5000, // assets + rewards + lended - borrowed
      totalRewards: BigInt(0),
      totalLended: 3000,
      totalBorrowed: 1500, // Should be subtracted from total value
      assets: [
        { name: 'Bitcoin', symbol: 'BTC', amount: BigInt(500000000), value: 3500 }, // 0.5 BTC
      ],
    }
    mockActor.getPortfolio.mockResolvedValue(mockPortfolio)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    await waitFor(() => {
      expect(result.current.portfolio).toBeDefined()
    }, { timeout: 5000 })

    expect(result.current.portfolio?.totalBorrowed).toBe(1500)
    expect(result.current.portfolio?.totalValue).toBe(5000)
  })

  it('should handle zero borrowed amount', async () => {
    mockUseICP.mockReturnValue({
      principal: mockPrincipal,
      isConnected: true,
      isLoading: false,
      connect: vi.fn(),
      setConnected: vi.fn(),
      disconnect: vi.fn(),
    })

    const mockPortfolio = {
      totalValue: 10000,
      totalRewards: BigInt(0),
      totalLended: 5000,
      totalBorrowed: 0,
      assets: [
        { name: 'Bitcoin', symbol: 'BTC', amount: BigInt(1000000000), value: 5000 }, // 1.0 BTC
      ],
    }
    mockActor.getPortfolio.mockResolvedValue(mockPortfolio)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    }, { timeout: 5000 })

    await waitFor(() => {
      expect(result.current.portfolio).toBeDefined()
    }, { timeout: 5000 })

    expect(result.current.portfolio?.totalBorrowed).toBe(0)
    expect(result.current.portfolio?.totalValue).toBe(10000)
  })
})

