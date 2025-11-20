# Validation Cloud Integration

This document describes the Validation Cloud Bitcoin API integration in the application.

## Overview

Validation Cloud provides Bitcoin RPC API access for enhanced Bitcoin queries from the frontend. This complements ICP's Bitcoin API, which is used for canister-side operations.

## Features

- **Bitcoin RPC Methods**: Full access to standard Bitcoin RPC methods
- **Blockchain Queries**: Get block height, blockchain info, transaction details
- **Address Validation**: Validate Bitcoin addresses before transactions
- **Network Support**: Both Bitcoin mainnet and testnet
- **Indexer Support**: Blockbook and Esplora indexer APIs available

## Setup

### 1. Get API Key

Sign up at [Validation Cloud](https://validationcloud.io/) and get your API key.

### 2. Configure Environment Variables

Add to your `.env` file:

```env
VITE_VALIDATION_CLOUD_API_KEY=your_api_key_here
VITE_BITCOIN_NETWORK=testnet  # or 'mainnet' for production
```

### 3. Usage

The Validation Cloud client is available via:

```typescript
import { getValidationCloudClient } from '@/services/validationcloud'
```

## API Reference

### ValidationCloudClient

The main client class for making Bitcoin RPC calls.

#### Methods

- `getBlockchainInfo()` - Get blockchain information
- `getBlockHeight()` - Get current block height
- `getBlockCount()` - Get block count
- `getBestBlockHash()` - Get best block hash
- `validateAddress(address: string)` - Validate a Bitcoin address
- `getTransaction(txid: string, verbose?: boolean)` - Get transaction details
- `getRawTransaction(txid: string)` - Get raw transaction hex
- `sendRawTransaction(hex: string)` - Send raw transaction
- `decodeRawTransaction(hex: string)` - Decode raw transaction
- `getTxOut(txid: string, vout: number, includeMempool?: boolean)` - Get transaction output
- `estimateSmartFee(blocks?: number)` - Estimate smart fee
- `getMempoolInfo()` - Get mempool information
- `getDifficulty()` - Get current difficulty
- `call<T>(method: string, params: any[])` - Generic RPC call

## React Hooks

Custom hooks are available for common Bitcoin queries:

### useBitcoinBlockHeight

Get current Bitcoin block height with automatic refresh:

```typescript
import { useBitcoinBlockHeight } from '@/hooks/useBitcoin'

function MyComponent() {
  const { height, loading, error, refetch } = useBitcoinBlockHeight()
  
  return (
    <div>
      {loading ? 'Loading...' : `Current Block: ${height}`}
    </div>
  )
}
```

### useBitcoinAddressValidation

Validate a Bitcoin address:

```typescript
import { useBitcoinAddressValidation } from '@/hooks/useBitcoin'

function AddressInput() {
  const [address, setAddress] = useState('')
  const { isValid, loading, details } = useBitcoinAddressValidation(address)
  
  return (
    <div>
      <input 
        value={address} 
        onChange={(e) => setAddress(e.target.value)}
      />
      {loading && <span>Validating...</span>}
      {!loading && isValid !== null && (
        <span>{isValid ? '✓ Valid' : '✗ Invalid'}</span>
      )}
    </div>
  )
}
```

### useBitcoinBlockchainInfo

Get blockchain information:

```typescript
import { useBitcoinBlockchainInfo } from '@/hooks/useBitcoin'

function BlockchainStatus() {
  const { info, loading, error } = useBitcoinBlockchainInfo()
  
  if (loading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message}</div>
  
  return (
    <div>
      <p>Chain: {info?.chain}</p>
      <p>Blocks: {info?.blocks}</p>
      <p>Difficulty: {info?.difficulty}</p>
    </div>
  )
}
```

### useBitcoinTransaction

Get transaction details:

```typescript
import { useBitcoinTransaction } from '@/hooks/useBitcoin'

function TransactionView({ txid }: { txid: string }) {
  const { transaction, loading, error } = useBitcoinTransaction(txid)
  
  if (loading) return <div>Loading transaction...</div>
  if (error) return <div>Error: {error.message}</div>
  
  return (
    <div>
      <h3>Transaction: {transaction?.txid}</h3>
      <p>Size: {transaction?.size} bytes</p>
      <p>Fee: {transaction?.fee} satoshis</p>
    </div>
  )
}
```

## Use Cases

### 1. Deposit Address Monitoring

Monitor deposit addresses for incoming transactions:

```typescript
import { getValidationCloudClient } from '@/services/validationcloud'

async function checkDeposit(address: string) {
  const client = getValidationCloudClient()
  
  // Get recent transactions (would need to implement address history)
  // This is a simplified example - actual implementation would use
  // Blockbook or Esplora indexer APIs for address history
  const info = await client.getBlockchainInfo()
  console.log('Current block height:', info.blocks)
}
```

### 2. Address Validation Before Withdrawal

Validate addresses before allowing withdrawals:

```typescript
import { getValidationCloudClient } from '@/services/validationcloud'

async function validateWithdrawalAddress(address: string): Promise<boolean> {
  try {
    const client = getValidationCloudClient()
    const result = await client.validateAddress(address)
    return result.isvalid
  } catch (error) {
    console.error('Address validation failed:', error)
    return false
  }
}
```

### 3. Transaction Status Check

Check transaction status and confirmations:

```typescript
import { getValidationCloudClient } from '@/services/validationcloud'

async function checkTransactionStatus(txid: string) {
  const client = getValidationCloudClient()
  
  try {
    const tx = await client.getTransaction(txid, true)
    const blockHeight = await client.getBlockHeight()
    
    if (tx.confirmations) {
      return {
        confirmed: true,
        confirmations: tx.confirmations,
        blockHeight: tx.blockheight,
      }
    }
    
    return { confirmed: false, confirmations: 0 }
  } catch (error) {
    // Transaction might not be in blockchain yet
    return { confirmed: false, confirmations: 0 }
  }
}
```

## Error Handling

The Validation Cloud client throws errors for:
- Missing API key
- Invalid network configuration
- RPC errors from Validation Cloud API
- Network errors

Always wrap API calls in try-catch:

```typescript
try {
  const client = getValidationCloudClient()
  const info = await client.getBlockchainInfo()
} catch (error) {
  if (error instanceof Error) {
    console.error('Validation Cloud error:', error.message)
  }
}
```

## Compute Units

All Validation Cloud methods consume Compute Units. Most methods cost 10 Compute Units per call. See [Validation Cloud documentation](https://docs.validationcloud.io/v1/about/billing) for details.

## Best Practices

1. **Use React Hooks**: Prefer using the provided React hooks for automatic state management and error handling
2. **Cache Results**: Don't fetch the same data repeatedly - use React hooks with proper dependency arrays
3. **Handle Errors**: Always handle errors gracefully - Validation Cloud may be unavailable
4. **Rate Limiting**: Be mindful of API rate limits - don't poll excessively
5. **Network Selection**: Use `testnet` for development, `mainnet` only for production

## Integration with ICP Bitcoin API

Validation Cloud complements (does not replace) ICP's Bitcoin API:

- **ICP Bitcoin API**: Use for canister-side operations (UTXO queries, transaction broadcasting)
- **Validation Cloud**: Use for frontend queries, monitoring, and enhanced data access

## Resources

- [Validation Cloud Documentation](https://docs.validationcloud.io/)
- [Bitcoin RPC Documentation](https://developer.bitcoin.org/reference/rpc/)
- [Blockbook API](https://github.com/trezor/blockbook/blob/master/docs/api.md)
- [Esplora API](https://github.com/Blockstream/esplora/blob/master/API.md)

