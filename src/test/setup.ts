/**
 * Test setup file for Vitest
 * Configures mocks and test utilities for ICP canister testing
 */

import { vi, afterEach } from 'vitest'
import { Principal } from '@dfinity/principal'

// Note: @/services/icp is NOT mocked globally
// Individual test files should mock it if needed, or test the real implementation

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

// Mock ValidationCloud service
vi.mock('@/services/validationcloud', () => ({
  getBitcoinBalance: vi.fn(async () => ({ balance: 0 })),
  getBitcoinUtxos: vi.fn(async () => []),
  sendBitcoinTransaction: vi.fn(async () => ({ txid: 'tx-test' })),
  getValidationCloudClient: vi.fn(() => ({
    call: vi.fn(),
    getBlockchainInfo: vi.fn(),
    getBlockHeight: vi.fn(),
    getBlockCount: vi.fn(),
    getBestBlockHash: vi.fn(),
    validateAddress: vi.fn(),
    getTransaction: vi.fn(),
    getRawTransaction: vi.fn(),
    sendRawTransaction: vi.fn(),
    decodeRawTransaction: vi.fn(),
    getTxOut: vi.fn(),
    estimateSmartFee: vi.fn(),
    getMempoolInfo: vi.fn(),
    getDifficulty: vi.fn(),
  })),
  isValidationCloudConfigured: vi.fn(() => true),
  ValidationCloudClient: vi.fn(),
}))

// Set default environment variables for tests
process.env.VITE_CANISTER_ID_REWARDS = process.env.VITE_CANISTER_ID_REWARDS || 'rrkah-fqaaa-aaaaa-aaaaq-cai'
process.env.VITE_CANISTER_ID_PORTFOLIO = process.env.VITE_CANISTER_ID_PORTFOLIO || 'rrkah-fqaaa-aaaaa-aaaaq-cai'
process.env.VITE_CANISTER_ID_SWAP = process.env.VITE_CANISTER_ID_SWAP || 'rrkah-fqaaa-aaaaa-aaaaq-cai'
process.env.VITE_CANISTER_ID_LENDING = process.env.VITE_CANISTER_ID_LENDING || 'rrkah-fqaaa-aaaaa-aaaaq-cai'

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


