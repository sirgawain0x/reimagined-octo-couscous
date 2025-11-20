import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { usePortfolio } from '../usePortfolio'
import { createPortfolioActor } from '@/services/canisters'
import { createMockPrincipal } from '@/test/setup'

vi.mock('@/services/canisters')
vi.mock('@/utils/logger')
vi.mock('./useICP', () => ({
  useICP: () => ({
    principal: createMockPrincipal(),
    isConnected: true,
  }),
}))

describe('usePortfolio', () => {
  const mockActor = {
    getBalance: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(createPortfolioActor).mockResolvedValue(mockActor as any)
  })

  it('should load portfolio balances on mount', async () => {
    mockActor.getBalance
      .mockResolvedValueOnce(1000) // BTC
      .mockResolvedValueOnce(500) // ETH
      .mockResolvedValueOnce(2000) // SOL

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.balances.btc).toBe(1000)
    expect(result.current.balances.eth).toBe(500)
    expect(result.current.balances.sol).toBe(2000)
  })

  it('should handle balance loading errors gracefully', async () => {
    mockActor.getBalance.mockRejectedValue(new Error('Network error'))

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    // Should still have default balances (0)
    expect(result.current.balances.btc).toBe(0)
  })

  it('should refresh balances', async () => {
    mockActor.getBalance
      .mockResolvedValueOnce(1000)
      .mockResolvedValueOnce(500)
      .mockResolvedValueOnce(2000)

    const { result } = renderHook(() => usePortfolio())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    await result.current.refresh()

    expect(mockActor.getBalance).toHaveBeenCalledTimes(6) // 3 initial + 3 refresh
  })
})

