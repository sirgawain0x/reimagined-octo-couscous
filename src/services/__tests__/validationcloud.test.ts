import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  getBitcoinBalance,
  getBitcoinUtxos,
  sendBitcoinTransaction,
} from '../validationcloud'

// Mock fetch
global.fetch = vi.fn()

describe('ValidationCloud service', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('getBitcoinBalance', () => {
    it('should fetch Bitcoin balance successfully', async () => {
      const mockBalance = 1000000
      vi.mocked(fetch).mockResolvedValue({
        ok: true,
        json: async () => ({ result: mockBalance }),
      } as Response)

      const balance = await getBitcoinBalance('test-address', 'regtest')

      expect(fetch).toHaveBeenCalled()
      expect(balance).toBe(mockBalance)
    })

    it('should handle API errors', async () => {
      vi.mocked(fetch).mockResolvedValue({
        ok: false,
        status: 500,
        statusText: 'Internal Server Error',
      } as Response)

      await expect(getBitcoinBalance('test-address', 'regtest')).rejects.toThrow()
    })
  })

  describe('getBitcoinUtxos', () => {
    it('should fetch UTXOs successfully', async () => {
      const mockUtxos = [
        {
          txid: 'test-tx-id',
          vout: 0,
          value: 100000,
          height: 100,
        },
      ]
      vi.mocked(fetch).mockResolvedValue({
        ok: true,
        json: async () => ({ result: mockUtxos }),
      } as Response)

      const utxos = await getBitcoinUtxos('test-address', 'regtest')

      expect(fetch).toHaveBeenCalled()
      expect(utxos).toEqual(mockUtxos)
    })

    it('should handle network errors', async () => {
      vi.mocked(fetch).mockRejectedValue(new Error('Network error'))

      await expect(getBitcoinUtxos('test-address', 'regtest')).rejects.toThrow('Network error')
    })
  })

  describe('sendBitcoinTransaction', () => {
    it('should send transaction successfully', async () => {
      const mockTxid = 'test-tx-id'
      vi.mocked(fetch).mockResolvedValue({
        ok: true,
        json: async () => ({ result: mockTxid }),
      } as Response)

      const txid = await sendBitcoinTransaction('hex-tx-data', 'regtest')

      expect(fetch).toHaveBeenCalled()
      expect(txid).toBe(mockTxid)
    })

    it('should handle transaction errors', async () => {
      vi.mocked(fetch).mockResolvedValue({
        ok: false,
        json: async () => ({ error: 'Invalid transaction' }),
      } as Response)

      await expect(sendBitcoinTransaction('invalid-tx', 'regtest')).rejects.toThrow()
    })
  })
})

