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
      // Use a valid Principal ID format
      const validCanisterId = 'rrkah-fqaaa-aaaaa-aaaaq-cai'
      process.env.VITE_CANISTER_ID_LENDING = validCanisterId
      
      // Reload module to get fresh config
      await vi.resetModules()
      const { createLendingActor: createLendingActorReloaded } = await import('../canisters')
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createLendingActorReloaded()

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })

    it('should throw error if canister ID not configured', async () => {
      // Mock config with empty canister ID
      await vi.resetModules()
      vi.doMock('@/config/env', () => ({
        ICP_CONFIG: {
          network: 'local',
          internetIdentityUrl: 'https://identity.ic0.app',
          canisterIds: {
            icSiwbProvider: 'be2us-64aaa-aaaaa-qaabq-cai',
            rewards: 'rrkah-fqaaa-aaaaa-aaaaq-cai',
            lending: '', // Empty canister ID
            portfolio: 'rrkah-fqaaa-aaaaa-aaaaq-cai',
            swap: 'rrkah-fqaaa-aaaaa-aaaaq-cai',
          },
        },
        isLocalNetwork: true,
        host: 'http://localhost:4943',
      }))
      
      const { createLendingActor: createLendingActorReloaded } = await import('../canisters')

      await expect(createLendingActorReloaded()).rejects.toThrow('Lending canister ID not configured')
      
      vi.doUnmock('@/config/env')
    })
  })

  describe('createSwapActor', () => {
    it('should create swap actor with valid canister ID', async () => {
      // Use a valid Principal ID format
      const validCanisterId = 'rrkah-fqaaa-aaaaa-aaaaq-cai'
      process.env.VITE_CANISTER_ID_SWAP = validCanisterId
      
      // Reload module to get fresh config
      await vi.resetModules()
      const { createSwapActor: createSwapActorReloaded } = await import('../canisters')
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createSwapActorReloaded()

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })

    it('should allow anonymous access for query methods', async () => {
      // Use a valid Principal ID format
      const validCanisterId = 'rrkah-fqaaa-aaaaa-aaaaq-cai'
      process.env.VITE_CANISTER_ID_SWAP = validCanisterId
      
      // Reload module to get fresh config
      await vi.resetModules()
      const { createSwapActor: createSwapActorReloaded } = await import('../canisters')
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createSwapActorReloaded(true)

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })
  })

  describe('createRewardsActor', () => {
    it('should create rewards actor with valid canister ID', async () => {
      // Use a valid Principal ID format
      const validCanisterId = 'rrkah-fqaaa-aaaaa-aaaaq-cai'
      process.env.VITE_CANISTER_ID_REWARDS = validCanisterId
      
      // Reload module to get fresh config
      await vi.resetModules()
      const { createRewardsActor: createRewardsActorReloaded } = await import('../canisters')
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createRewardsActorReloaded()

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })
  })

  describe('createPortfolioActor', () => {
    it('should create portfolio actor with valid canister ID', async () => {
      // Use a valid Principal ID format
      const validCanisterId = 'rrkah-fqaaa-aaaaa-aaaaq-cai'
      process.env.VITE_CANISTER_ID_PORTFOLIO = validCanisterId
      
      // Reload module to get fresh config
      await vi.resetModules()
      const { createPortfolioActor: createPortfolioActorReloaded } = await import('../canisters')
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockResolvedValue(mockActor as any)

      const actor = await createPortfolioActorReloaded()

      expect(createActor).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })
  })

  describe('requireAuth', () => {
    it('should return principal if authenticated', async () => {
      const { getIdentity } = await import('../icp')
      vi.mocked(getIdentity).mockResolvedValue(mockPrincipal)

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
      // Use a valid Principal ID format
      const validCanisterId = 'rrkah-fqaaa-aaaaa-aaaaq-cai'
      process.env.VITE_CANISTER_ID_REWARDS = validCanisterId
      
      // Reload module to get fresh config
      await vi.resetModules()
      const { createRewardsActor: createRewardsActorReloaded } = await import('../canisters')
      const { createActor } = await import('../icp')
      vi.mocked(createActor).mockRejectedValue(new Error('Network error'))

      await expect(createRewardsActorReloaded()).rejects.toThrow()
    })

    it('should handle missing canister IDs with clear error messages', async () => {
      // Mock config with empty canister ID
      await vi.resetModules()
      vi.doMock('@/config/env', () => ({
        ICP_CONFIG: {
          network: 'local',
          internetIdentityUrl: 'https://identity.ic0.app',
          canisterIds: {
            icSiwbProvider: 'be2us-64aaa-aaaaa-qaabq-cai',
            rewards: '', // Empty canister ID
            lending: 'rrkah-fqaaa-aaaaa-aaaaq-cai',
            portfolio: 'rrkah-fqaaa-aaaaa-aaaaq-cai',
            swap: 'rrkah-fqaaa-aaaaa-aaaaq-cai',
          },
        },
        isLocalNetwork: true,
        host: 'http://localhost:4943',
      }))
      
      const { createRewardsActor: createRewardsActorReloaded } = await import('../canisters')

      await expect(createRewardsActorReloaded()).rejects.toThrow('Rewards canister ID not configured')
      
      vi.doUnmock('@/config/env')
    })
  })
})

