import { vi } from 'vitest'

// Export the functions that tests expect
export const getBitcoinBalance = vi.fn(async (_address: string, _network: string) => {
  return { balance: 0 }
})

export const getBitcoinUtxos = vi.fn(async (_address: string, _network: string) => {
  return []
})

export const sendBitcoinTransaction = vi.fn(async (_hex: string, _network: string) => {
  return { txid: 'tx-test' }
})

// Export the actual exports from the real module
export const getValidationCloudClient = vi.fn(() => ({
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
}))

export const isValidationCloudConfigured = vi.fn(() => true)

export class ValidationCloudClient {
  call = vi.fn()
  getBlockchainInfo = vi.fn()
  getBlockHeight = vi.fn()
  getBlockCount = vi.fn()
  getBestBlockHash = vi.fn()
  validateAddress = vi.fn()
  getTransaction = vi.fn()
  getRawTransaction = vi.fn()
  sendRawTransaction = vi.fn()
  decodeRawTransaction = vi.fn()
  getTxOut = vi.fn()
  estimateSmartFee = vi.fn()
  getMempoolInfo = vi.fn()
  getDifficulty = vi.fn()
}

