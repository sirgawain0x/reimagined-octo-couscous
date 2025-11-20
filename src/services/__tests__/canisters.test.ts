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
  getIdentity: vi.fn(),
  createActor: vi.fn(),
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
    it('should return principal if authenticated', () => {
      const principal = requireAuth(mockPrincipal)

      expect(principal).toBe(mockPrincipal)
    })

    it('should throw error if not authenticated', () => {
      const anonymousPrincipal = Principal.anonymous()

      expect(() => requireAuth(anonymousPrincipal)).toThrow('Authentication required')
    })
  })
})

