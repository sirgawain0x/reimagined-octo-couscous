import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  createLendingActor,
  createSwapActor,
  createRewardsActor,
  createPortfolioActor,
  requireAuth,
} from '../canisters'
import { Principal } from '@dfinity/principal'
import { createMockPrincipal } from '@/test/setup'

// Mock ICP service
vi.mock('../icp', () => ({
  getAgent: vi.fn(() => null),
  getAnonymousAgent: vi.fn(async () => ({})),
  createAuthClient: vi.fn(async () => ({
    create: vi.fn(),
    login: vi.fn(),
    logout: vi.fn(),
    isAuthenticated: vi.fn(() => false),
  })),
  getIdentity: vi.fn(async () => null),
  createActor: vi.fn(async () => ({})),
  login: vi.fn(async () => null),
  logout: vi.fn(async () => {}),
  loginWithBitcoin: vi.fn(async () => null),
  loginWithBitcoinWallet: vi.fn(async () => null),
  setBitcoinIdentity: vi.fn(async () => {}),
}))

describe('canisters service', () => {
  const mockPrincipal = createMockPrincipal()
  const mockActor = {
    getLendingAssets: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('createLendingActor', () => {
    it('should create lending actor with valid canister ID', async () => {
      process.env.VITE_CANISTER_ID_LENDING = 'test-canister-id'
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createLendingActor()

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })

    it('should throw error if canister ID not configured', async () => {
      delete process.env.VITE_CANISTER_ID_LENDING

      await expect(createLendingActor()).rejects.toThrow('Lending canister ID not configured')
    })
  })

  describe('createSwapActor', () => {
    it('should create swap actor with valid canister ID', async () => {
      process.env.VITE_CANISTER_ID_SWAP = 'test-canister-id'
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createSwapActor()

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })

    it('should allow anonymous access for query methods', async () => {
      process.env.VITE_CANISTER_ID_SWAP = 'test-canister-id'
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createSwapActor(true)

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })
  })

  describe('createRewardsActor', () => {
    it('should create rewards actor with valid canister ID', async () => {
      process.env.VITE_CANISTER_ID_REWARDS = 'test-canister-id'
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createRewardsActor()

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })
  })

  describe('createPortfolioActor', () => {
    it('should create portfolio actor with valid canister ID', async () => {
      process.env.VITE_CANISTER_ID_PORTFOLIO = 'test-canister-id'
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createPortfolioActor()

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })
  })

  describe('requireAuth', () => {
    it('should return principal if authenticated', async () => {
      const { getIdentity } = await import('../icp')
      vi.mocked(getIdentity).mockResolvedValue({
        getPrincipal: vi.fn().mockResolvedValue(mockPrincipal),
      } as any)

      const principal = await requireAuth()

      expect(principal).toBe(mockPrincipal)
    })

    it('should throw error if not authenticated', async () => {
      const { getIdentity } = await import('../icp')
      vi.mocked(getIdentity).mockResolvedValue(null)

      await expect(requireAuth()).rejects.toThrow('User must be authenticated')
    })
  })

  describe('error handling', () => {
    it('should handle actor creation errors gracefully', async () => {
      process.env.VITE_CANISTER_ID_REWARDS = 'test-canister-id'
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockRejectedValue(new Error('Network error'))

      await expect(createRewardsActor()).rejects.toThrow()
    })

    it('should handle missing canister IDs with clear error messages', async () => {
      delete process.env.VITE_CANISTER_ID_REWARDS

      await expect(createRewardsActor()).rejects.toThrow('Rewards canister ID not configured')
    })
  })
})

