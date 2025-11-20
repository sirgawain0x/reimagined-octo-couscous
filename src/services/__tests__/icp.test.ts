import { describe, it, expect, vi, beforeEach } from 'vitest'
import { Principal, HttpAgent, AnonymousIdentity } from '@dfinity/agent'
import { AuthClient } from '@dfinity/auth-client'
import {
  getAgent,
  getAnonymousAgent,
  createAuthClient,
  login,
  logout,
  getIdentity,
  createActor,
} from '../icp'
import { createMockPrincipal } from '@/test/setup'

// Mock dependencies
vi.mock('@dfinity/auth-client')
vi.mock('@dfinity/agent')

describe('ICP service', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('getAgent', () => {
    it('should return null if agent not initialized', () => {
      const agent = getAgent()
      expect(agent).toBeNull()
    })
  })

  describe('getAnonymousAgent', () => {
    it('should create and return anonymous agent', async () => {
      const mockAgent = {
        fetchRootKey: vi.fn().mockResolvedValue(undefined),
      } as any

      vi.mocked(HttpAgent).mockImplementation(() => mockAgent)

      const agent = await getAnonymousAgent()

      expect(HttpAgent).toHaveBeenCalled()
      expect(agent).toBeDefined()
    })
  })

  describe('createAuthClient', () => {
    it('should create auth client successfully', async () => {
      const mockAuthClient = {
        isAuthenticated: vi.fn().mockResolvedValue(true),
      }

      vi.mocked(AuthClient.create).mockResolvedValue(mockAuthClient as any)

      const client = await createAuthClient()

      expect(AuthClient.create).toHaveBeenCalled()
      expect(client).toBe(mockAuthClient)
    })

    it('should throw error if Internet Identity URL not configured', async () => {
      // Mock environment to not have Internet Identity URL
      const originalEnv = process.env.VITE_INTERNET_IDENTITY_URL
      delete process.env.VITE_INTERNET_IDENTITY_URL

      // Reload the module to get fresh config
      await vi.resetModules()
      const { createAuthClient: createAuthClientReloaded } = await import('../icp')

      await expect(createAuthClientReloaded()).rejects.toThrow('Internet Identity URL not configured')

      process.env.VITE_INTERNET_IDENTITY_URL = originalEnv
    })
  })

  describe('getIdentity', () => {
    it('should return identity if authenticated', async () => {
      const mockPrincipal = createMockPrincipal()
      const mockIdentity = {
        getPrincipal: vi.fn().mockResolvedValue(mockPrincipal),
      }

      // Mock auth client
      const mockAuthClient = {
        isAuthenticated: vi.fn().mockResolvedValue(true),
        getIdentity: vi.fn().mockReturnValue(mockIdentity),
      }

      vi.mocked(AuthClient.create).mockResolvedValue(mockAuthClient as any)

      await createAuthClient()
      const identity = await getIdentity()

      expect(identity).toBeDefined()
      expect(identity?.getPrincipal).toBeDefined()
    })

    it('should return null if not authenticated', async () => {
      const mockAuthClient = {
        isAuthenticated: vi.fn().mockResolvedValue(false),
      }

      vi.mocked(AuthClient.create).mockResolvedValue(mockAuthClient as any)

      await createAuthClient()
      const identity = await getIdentity()

      expect(identity).toBeNull()
    })
  })

  describe('createActor', () => {
    it('should create actor with identity', async () => {
      const mockPrincipal = createMockPrincipal()
      const mockIdentity = {
        getPrincipal: vi.fn().mockResolvedValue(mockPrincipal),
      }

      const mockAgent = {
        fetchRootKey: vi.fn().mockResolvedValue(undefined),
      } as any

      vi.mocked(HttpAgent).mockImplementation(() => mockAgent)
      vi.mocked(Actor.createActor).mockReturnValue({} as any)

      const actor = await createActor(
        () => ({} as any),
        Principal.fromText('test-canister-id'),
        mockIdentity
      )

      expect(actor).toBeDefined()
    })
  })
})

