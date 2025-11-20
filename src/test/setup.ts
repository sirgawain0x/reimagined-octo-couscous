/**
 * Test setup file for Vitest
 * Configures mocks and test utilities for ICP canister testing
 */

import { vi } from 'vitest'
import { Principal } from '@dfinity/principal'

// Mock ICP agent and identity
vi.mock('@/services/icp', () => ({
  getIdentity: vi.fn(),
  createActor: vi.fn(),
  connect: vi.fn(),
  disconnect: vi.fn(),
}))

// Mock window.ic for Internet Identity
Object.defineProperty(window, 'ic', {
  value: {
    plug: {
      requestConnect: vi.fn(),
      isConnected: vi.fn(),
      disconnect: vi.fn(),
      createActor: vi.fn(),
    },
    infinity: {
      connect: vi.fn(),
      disconnect: vi.fn(),
    },
  },
  writable: true,
  configurable: true,
})

// Mock global fetch for Bitcoin API calls
global.fetch = vi.fn()

// Helper to create a mock principal
export function createMockPrincipal(hex?: string): Principal {
  if (hex) {
    return Principal.fromHex(hex)
  }
  // Generate a random principal for testing
  const randomBytes = new Uint8Array(29)
  crypto.getRandomValues(randomBytes)
  return Principal.fromUint8Array(randomBytes)
}

// Helper to create a mock identity
export function createMockIdentity(principal?: Principal) {
  const mockPrincipal = principal || createMockPrincipal()
  return {
    getPrincipal: () => Promise.resolve(mockPrincipal),
    sign: vi.fn(),
    transformRequest: vi.fn(),
  }
}

// Clean up after each test
afterEach(() => {
  vi.clearAllMocks()
})


