import { describe, it, expect, vi, beforeEach } from 'vitest'

// Unmock validationcloud for these tests
vi.unmock('@/services/validationcloud')

// Mock fetch
global.fetch = vi.fn()

describe('ValidationCloud service', () => {
  beforeEach(async () => {
    vi.clearAllMocks()
  })

  describe('ValidationCloudClient', () => {
    it('should make RPC calls successfully', async () => {
      // Import fresh to get unmocked class
      vi.resetModules()
      const { ValidationCloudClient } = await import('../validationcloud')
      
      const mockResult = { blocks: 100 }
      vi.mocked(fetch).mockResolvedValue({
        ok: true,
        json: async () => ({
          jsonrpc: '1.0',
          id: 1,
          result: mockResult,
        }),
      } as Response)

      const client = new ValidationCloudClient({
        apiKey: 'test-key',
        network: 'testnet',
      })

      const result = await client.getBlockchainInfo()

      expect(fetch).toHaveBeenCalled()
      expect(result).toEqual(mockResult)
    })

    it('should handle API errors', async () => {
      // Import fresh to get unmocked class
      vi.resetModules()
      const { ValidationCloudClient } = await import('../validationcloud')
      
      vi.mocked(fetch).mockResolvedValue({
        ok: true,
        json: async () => ({
          jsonrpc: '1.0',
          id: 1,
          error: {
            code: -1,
            message: 'RPC error',
          },
        }),
      } as Response)

      const client = new ValidationCloudClient({
        apiKey: 'test-key',
        network: 'testnet',
      })

      await expect(client.getBlockchainInfo()).rejects.toThrow('RPC error')
    })

    it('should handle HTTP errors', async () => {
      // Import fresh to get unmocked class
      vi.resetModules()
      const { ValidationCloudClient } = await import('../validationcloud')
      
      vi.mocked(fetch).mockResolvedValue({
        ok: false,
        status: 500,
        statusText: 'Internal Server Error',
      } as Response)

      const client = new ValidationCloudClient({
        apiKey: 'test-key',
        network: 'testnet',
      })

      await expect(client.getBlockchainInfo()).rejects.toThrow('Internal Server Error')
    })
  })
})

