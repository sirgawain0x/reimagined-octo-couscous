import { describe, it, expect, vi, beforeEach } from 'vitest'
import { Principal, HttpAgent, AnonymousIdentity } from '@dfinity/agent'
import { AuthClient } from '@dfinity/auth-client'
import { createMockPrincipal } from '@/test/setup'

// Mock dependencies
vi.mock('@dfinity/auth-client')
vi.mock('@dfinity/agent')

// Note: @/config/env is mocked in src/test/setup.ts to ensure it's applied before any imports

import {
  getAgent,
  getAnonymousAgent,
  createAuthClient,
  login,
  logout,
  getIdentity,
  createActor,
} from '../icp'

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
      // Set up Internet Identity URL for this test
      const originalEnv = process.env.VITE_INTERNET_IDENTITY_URL
      process.env.VITE_INTERNET_IDENTITY_URL = 'http://localhost:4943?canisterId=rdmx6-jaaaa-aaaaa-aaaq-cai'

      await vi.resetModules()
      // Re-mock after reset
      vi.mocked(AuthClient.create).mockClear()
      
      const { createAuthClient: createAuthClientReloaded } = await import('../icp')

      const mockAuthClient = {
        isAuthenticated: vi.fn().mockResolvedValue(true),
        getIdentity: vi.fn(),
      }

      vi.mocked(AuthClient.create).mockResolvedValue(mockAuthClient as any)

      const client = await createAuthClientReloaded()

      expect(AuthClient.create).toHaveBeenCalled()
      expect(client).toBe(mockAuthClient)

      if (originalEnv !== undefined) {
        process.env.VITE_INTERNET_IDENTITY_URL = originalEnv
      } else {
        delete process.env.VITE_INTERNET_IDENTITY_URL
      }
      // Reset module after test to clear state
      await vi.resetModules()
    })

    it('should return null if Internet Identity URL not configured', async () => {
      // Mock config to not have Internet Identity URL
      await vi.resetModules()
      vi.doMock('@/config/env', () => ({
        ICP_CONFIG: {
          network: 'local',
          internetIdentityUrl: null,
          canisterIds: {
            icSiwbProvider: 'be2us-64aaa-aaaaa-qaabq-cai',
            rewards: '',
            lending: '',
            portfolio: '',
            swap: '',
          },
        },
        isLocalNetwork: true,
        host: 'http://localhost:4943',
      }))
      
      const { createAuthClient: createAuthClientReloaded } = await import('../icp')

      const client = await createAuthClientReloaded()
      expect(client).toBeNull()
      
      vi.doUnmock('@/config/env')
    })

    it('should return null if Internet Identity canister ID is invalid', async () => {
      // Mock config with invalid canister ID
      await vi.resetModules()
      vi.doMock('@/config/env', () => ({
        ICP_CONFIG: {
          network: 'local',
          internetIdentityUrl: 'http://localhost:4943?canisterId=rdmx6-jaaaa-aaaah-qcaiq-cai',
          canisterIds: {
            icSiwbProvider: 'be2us-64aaa-aaaaa-qaabq-cai',
            rewards: '',
            lending: '',
            portfolio: '',
            swap: '',
          },
        },
        isLocalNetwork: true,
        host: 'http://localhost:4943',
      }))
      
      const { createAuthClient: createAuthClientReloaded } = await import('../icp')

      const client = await createAuthClientReloaded()
      expect(client).toBeNull()
      
      vi.doUnmock('@/config/env')
    })
  })

  describe('getIdentity', () => {
    it('should return principal if authenticated', async () => {
      // Set up Internet Identity URL for this test
      const originalEnv = process.env.VITE_INTERNET_IDENTITY_URL
      process.env.VITE_INTERNET_IDENTITY_URL = 'http://localhost:4943?canisterId=rdmx6-jaaaa-aaaaa-aaaq-cai'

      await vi.resetModules()
      vi.mocked(AuthClient.create).mockClear()
      
      const mockPrincipal = createMockPrincipal()
      const mockIdentity = {
        getPrincipal: vi.fn().mockReturnValue(mockPrincipal),
      }

      // Mock auth client
      const mockAuthClient = {
        isAuthenticated: vi.fn().mockResolvedValue(true),
        getIdentity: vi.fn().mockReturnValue(mockIdentity),
      }

      vi.mocked(AuthClient.create).mockResolvedValue(mockAuthClient as any)

      const { createAuthClient: createAuthClientReloaded, getIdentity: getIdentityReloaded } = await import('../icp')

      // Initialize authClient first
      await createAuthClientReloaded()
      
      // Now getIdentity should use the initialized authClient
      const principal = await getIdentityReloaded()

      expect(principal).toBeDefined()
      expect(principal).toBe(mockPrincipal)

      if (originalEnv !== undefined) {
        process.env.VITE_INTERNET_IDENTITY_URL = originalEnv
      } else {
        delete process.env.VITE_INTERNET_IDENTITY_URL
      }
      await vi.resetModules()
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
      // Set up Internet Identity URL for this test
      const originalEnv = process.env.VITE_INTERNET_IDENTITY_URL
      process.env.VITE_INTERNET_IDENTITY_URL = 'http://localhost:4943?canisterId=rdmx6-jaaaa-aaaaa-aaaq-cai'

      // Reset modules to clear any cached authClient from previous tests
      await vi.resetModules()
      vi.mocked(AuthClient.create).mockClear()
      
      const mockPrincipal = createMockPrincipal()
      const mockIdentity = {
        getPrincipal: vi.fn().mockReturnValue(mockPrincipal),
      }

      const mockAgent = {
        fetchRootKey: vi.fn().mockResolvedValue(undefined),
      } as any

      // Import Actor properly
      const { Actor } = await import('@dfinity/agent')
      const createActorSpy = vi.spyOn(Actor, 'createActor').mockReturnValue({} as any)

      // Mock authClient to return identity, which will be used to set agent
      const mockAuthClient = {
        isAuthenticated: vi.fn().mockResolvedValue(true),
        getIdentity: vi.fn().mockReturnValue(mockIdentity),
        login: vi.fn((options) => {
          // Call onSuccess asynchronously using queueMicrotask
          queueMicrotask(async () => {
            await options.onSuccess()
          })
        }),
      }
      
      vi.mocked(HttpAgent).mockImplementation(() => mockAgent)
      // Ensure AuthClient.create returns our mock with login method
      vi.mocked(AuthClient.create).mockResolvedValue(mockAuthClient as any)
      
      // Re-import after reset to get fresh module instances
      const { login: loginReloaded, createActor: createActorReloaded, getAgent: getAgentReloaded } = await import('../icp')
      
      // Initialize agent by calling login() - this sets the module-level agent variable
      // The top-level config mock provides the Internet Identity URL
      // login() will call createAuthClient() internally, which should return our mocked authClient
      const loginResult = await loginReloaded() // This creates and sets the agent via new HttpAgent()
      
      // Verify login succeeded
      expect(loginResult).toBe(mockPrincipal)
      
      // Verify agent is set
      const agent = getAgentReloaded()
      expect(agent).toBeDefined()
      expect(agent).toBe(mockAgent)

      // Now agent should be set, so createActor should work
      const actor = await createActorReloaded(
        'test-canister-id',
        () => ({} as any),
        false
      )

      expect(createActorSpy).toHaveBeenCalled()
      expect(actor).toBeDefined()

      if (originalEnv !== undefined) {
        process.env.VITE_INTERNET_IDENTITY_URL = originalEnv
      } else {
        delete process.env.VITE_INTERNET_IDENTITY_URL
      }
      await vi.resetModules()
    })

    it('should create actor with anonymous identity when allowAnonymous is true', async () => {
      const mockAgent = {
        fetchRootKey: vi.fn().mockResolvedValue(undefined),
      } as any

      vi.mocked(HttpAgent).mockImplementation(() => mockAgent)
      
      // Import Actor properly
      const { Actor } = await import('@dfinity/agent')
      const createActorSpy = vi.spyOn(Actor, 'createActor').mockReturnValue({} as any)

      // Mock getAnonymousAgent
      const icpModule = await import('../icp')
      vi.spyOn(icpModule, 'getAnonymousAgent').mockResolvedValue(mockAgent)

      const actor = await createActor(
        'test-canister-id',
        () => ({} as any),
        true
      )

      expect(createActorSpy).toHaveBeenCalled()
      expect(actor).toBeDefined()
    })
  })

  describe('login', () => {
    it('should login successfully', async () => {
      // Set up Internet Identity URL for this test
      const originalEnv = process.env.VITE_INTERNET_IDENTITY_URL
      process.env.VITE_INTERNET_IDENTITY_URL = 'http://localhost:4943?canisterId=rdmx6-jaaaa-aaaaa-aaaq-cai'

      await vi.resetModules()
      vi.mocked(AuthClient.create).mockClear()
      
      const mockPrincipal = createMockPrincipal()
      const mockIdentity = {
        getPrincipal: vi.fn().mockReturnValue(mockPrincipal),
      }

      const mockAgent = {
        fetchRootKey: vi.fn().mockResolvedValue(undefined),
      } as any

      vi.mocked(HttpAgent).mockImplementation(() => mockAgent)

      const mockAuthClient = {
        isAuthenticated: vi.fn().mockResolvedValue(true),
        getIdentity: vi.fn().mockReturnValue(mockIdentity),
        login: vi.fn((options) => {
          // Simulate async onSuccess - schedule callback in next microtask
          // The actual authClient.login() doesn't return a Promise, it just calls callbacks
          // We use queueMicrotask to schedule onSuccess() to run, but don't return anything
          // The outer Promise resolves when onSuccess() calls resolve()
          queueMicrotask(async () => {
            await options.onSuccess()
          })
        }),
      }

      vi.mocked(AuthClient.create).mockResolvedValue(mockAuthClient as any)

      const { login: loginReloaded } = await import('../icp')

      const principal = await loginReloaded()

      expect(principal).toBe(mockPrincipal)

      if (originalEnv !== undefined) {
        process.env.VITE_INTERNET_IDENTITY_URL = originalEnv
      } else {
        delete process.env.VITE_INTERNET_IDENTITY_URL
      }
      await vi.resetModules()
    })

    it('should return null if Internet Identity URL not configured', async () => {
      // Mock config to not have Internet Identity URL
      await vi.resetModules()
      vi.doMock('@/config/env', () => ({
        ICP_CONFIG: {
          network: 'local',
          internetIdentityUrl: null,
          canisterIds: {
            icSiwbProvider: 'be2us-64aaa-aaaaa-qaabq-cai',
            rewards: '',
            lending: '',
            portfolio: '',
            swap: '',
          },
        },
        isLocalNetwork: true,
        host: 'http://localhost:4943',
      }))
      
      const { login: loginReloaded } = await import('../icp')

      const principal = await loginReloaded()

      expect(principal).toBeNull()
      
      vi.doUnmock('@/config/env')
    })
  })

  describe('logout', () => {
    it('should logout successfully', async () => {
      // Set up Internet Identity URL for this test
      const originalEnv = process.env.VITE_INTERNET_IDENTITY_URL
      process.env.VITE_INTERNET_IDENTITY_URL = 'http://localhost:4943?canisterId=rdmx6-jaaaa-aaaaa-aaaq-cai'

      await vi.resetModules()
      vi.mocked(AuthClient.create).mockClear()
      
      const mockAuthClient = {
        isAuthenticated: vi.fn().mockResolvedValue(true),
        logout: vi.fn().mockResolvedValue(undefined),
      }

      vi.mocked(AuthClient.create).mockResolvedValue(mockAuthClient as any)

      const { createAuthClient: createAuthClientReloaded, logout: logoutReloaded } = await import('../icp')
      
      // Initialize authClient first
      await createAuthClientReloaded()

      await logoutReloaded()

      expect(mockAuthClient.logout).toHaveBeenCalled()

      if (originalEnv !== undefined) {
        process.env.VITE_INTERNET_IDENTITY_URL = originalEnv
      } else {
        delete process.env.VITE_INTERNET_IDENTITY_URL
      }
      await vi.resetModules()
    })
  })
})

