/**
 * Validation Cloud Bitcoin RPC API Client
 * 
 * Provides access to Bitcoin mainnet/testnet via Validation Cloud's RPC API.
 * Supports all standard Bitcoin RPC methods plus Blockbook and Esplora indexers.
 * 
 * @see https://docs.validationcloud.io/v1/
 */

interface ValidationCloudConfig {
  apiKey: string
  network: 'mainnet' | 'testnet'
}

interface BitcoinRPCRequest {
  jsonrpc: '1.0'
  id: string | number
  method: string
  params: any[]
}

interface BitcoinRPCResponse<T = any> {
  jsonrpc: '1.0'
  id: string | number
  result?: T
  error?: {
    code: number
    message: string
  }
}

interface BlockchainInfo {
  chain: string
  blocks: number
  headers: number
  bestblockhash: string
  difficulty: number
  mediantime: number
  verificationprogress: number
  chainwork: string
  pruned: boolean
}

interface AddressValidation {
  isvalid: boolean
  address: string
  scriptPubKey?: string
  isscript?: boolean
  iswitness?: boolean
}

interface Transaction {
  txid: string
  hash: string
  version: number
  size: number
  vsize: number
  weight: number
  locktime: number
  vin: any[]
  vout: any[]
  hex: string
}

export class ValidationCloudClient {
  private baseUrl: string

  constructor(config: ValidationCloudConfig) {
    // Store config values directly in baseUrl construction
    this.baseUrl = `https://${config.network}.bitcoin.validationcloud.io/v1/${config.apiKey}`
  }

  /**
   * Make a generic Bitcoin RPC call
   */
  async call<T>(method: string, params: any[] = []): Promise<T> {
    const request: BitcoinRPCRequest = {
      jsonrpc: '1.0',
      id: 1,
      method,
      params,
    }

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
    })

    if (!response.ok) {
      throw new Error(`Validation Cloud API error: ${response.statusText}`)
    }

    const data: BitcoinRPCResponse<T> = await response.json()

    if (data.error) {
      throw new Error(`Validation Cloud RPC error: ${data.error.message} (code: ${data.error.code})`)
    }

    if (data.result === undefined) {
      throw new Error(`Validation Cloud RPC error: No result returned`)
    }

    return data.result as T
  }

  /**
   * Get blockchain information
   */
  async getBlockchainInfo(): Promise<BlockchainInfo> {
    return this.call<BlockchainInfo>('getblockchaininfo', [])
  }

  /**
   * Get current block height
   */
  async getBlockHeight(): Promise<number> {
    const info = await this.getBlockchainInfo()
    return info.blocks
  }

  /**
   * Get block count
   */
  async getBlockCount(): Promise<number> {
    return this.call<number>('getblockcount', [])
  }

  /**
   * Get best block hash
   */
  async getBestBlockHash(): Promise<string> {
    return this.call<string>('getbestblockhash', [])
  }

  /**
   * Validate a Bitcoin address
   */
  async validateAddress(address: string): Promise<AddressValidation> {
    return this.call<AddressValidation>('validateaddress', [address])
  }

  /**
   * Get raw transaction (decoded)
   */
  async getTransaction(txid: string, verbose: boolean = true): Promise<Transaction> {
    return this.call<Transaction>('getrawtransaction', [txid, verbose])
  }

  /**
   * Get raw transaction hex
   */
  async getRawTransaction(txid: string): Promise<string> {
    return this.call<string>('getrawtransaction', [txid, false])
  }

  /**
   * Send raw transaction
   */
  async sendRawTransaction(hex: string): Promise<string> {
    return this.call<string>('sendrawtransaction', [hex])
  }

  /**
   * Decode raw transaction
   */
  async decodeRawTransaction(hex: string): Promise<any> {
    return this.call('decoderawtransaction', [hex])
  }

  /**
   * Get transaction output
   */
  async getTxOut(txid: string, vout: number, includeMempool: boolean = true): Promise<any> {
    return this.call('gettxout', [txid, vout, includeMempool])
  }

  /**
   * Estimate smart fee
   */
  async estimateSmartFee(blocks: number = 6): Promise<{ feerate: number; blocks: number }> {
    return this.call<{ feerate: number; blocks: number }>('estimatesmartfee', [blocks])
  }

  /**
   * Get mempool info
   */
  async getMempoolInfo(): Promise<any> {
    return this.call('getmempoolinfo', [])
  }

  /**
   * Get difficulty
   */
  async getDifficulty(): Promise<number> {
    return this.call<number>('getdifficulty', [])
  }
}

// Singleton instance
let clientInstance: ValidationCloudClient | null = null

/**
 * Get or create the Validation Cloud client instance
 */
export function getValidationCloudClient(): ValidationCloudClient {
  if (!clientInstance) {
    const apiKey = import.meta.env.VITE_VALIDATION_CLOUD_API_KEY
    const network = (import.meta.env.VITE_BITCOIN_NETWORK || 'testnet') as 'mainnet' | 'testnet'

    if (!apiKey) {
      throw new Error(
        'VITE_VALIDATION_CLOUD_API_KEY environment variable is required. ' +
        'Get your API key from https://validationcloud.io/'
      )
    }

    if (!['mainnet', 'testnet'].includes(network)) {
      throw new Error(`VITE_BITCOIN_NETWORK must be either 'mainnet' or 'testnet', got: ${network}`)
    }

    clientInstance = new ValidationCloudClient({ apiKey, network })
  }

  return clientInstance
}

/**
 * Check if Validation Cloud is configured
 */
export function isValidationCloudConfigured(): boolean {
  return !!import.meta.env.VITE_VALIDATION_CLOUD_API_KEY
}

