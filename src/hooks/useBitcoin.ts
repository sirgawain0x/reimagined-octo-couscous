/**
 * React hooks for Bitcoin queries via Validation Cloud
 */

import { useState, useEffect, useCallback } from "react"
import { getValidationCloudClient, isValidationCloudConfigured } from "@/services/validationcloud"
import { logError, logInfo } from "@/utils/logger"

interface UseBitcoinBalanceResult {
  balance: number | null
  loading: boolean
  error: Error | null
  refetch: () => Promise<void>
}

interface UseBitcoinBlockHeightResult {
  height: number | null
  loading: boolean
  error: Error | null
  refetch: () => Promise<void>
}

interface UseBitcoinAddressValidationResult {
  isValid: boolean | null
  loading: boolean
  error: Error | null
  details: any | null
}

/**
 * Hook to fetch Bitcoin balance for an address
 */
export function useBitcoinBalance(
  address: string | null,
  minConfirmations?: number
): UseBitcoinBalanceResult {
  const [balance, setBalance] = useState<number | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchBalance = useCallback(async () => {
    if (!address) {
      setBalance(null)
      return
    }

    if (!isValidationCloudConfigured()) {
      setError(new Error("Validation Cloud API key not configured"))
      return
    }

    setLoading(true)
    setError(null)

    try {
      // Note: Standard Bitcoin RPC getbalance requires a wallet connection.
      // For address balance queries, use Blockbook or Esplora indexer REST APIs
      // which are available through Validation Cloud but require different endpoints.
      // 
      // For now, this hook is a placeholder. To get address balances:
      // 1. Use Blockbook REST API: GET /api/v2/address/{address}
      // 2. Use Esplora REST API: GET /address/{address}
      // 3. Or query UTXOs via ICP Bitcoin API from canisters
      
      logInfo("Bitcoin balance query", { 
        address, 
        note: "Use Blockbook/Esplora REST APIs or ICP Bitcoin API for address balances" 
      })
      
      setError(new Error(
        "Address balance queries require Blockbook/Esplora REST APIs. " +
        "Use ICP Bitcoin API from canisters for UTXO-based balance queries, " +
        "or implement Blockbook/Esplora REST API calls directly."
      ))
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      logError("Error fetching Bitcoin balance", error)
      setError(error)
    } finally {
      setLoading(false)
    }
  }, [address, minConfirmations])

  useEffect(() => {
    fetchBalance()
  }, [fetchBalance])

  return {
    balance,
    loading,
    error,
    refetch: fetchBalance,
  }
}

/**
 * Hook to fetch current Bitcoin block height
 */
export function useBitcoinBlockHeight(): UseBitcoinBlockHeightResult {
  const [height, setHeight] = useState<number | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchHeight = useCallback(async () => {
    if (!isValidationCloudConfigured()) {
      setError(new Error("Validation Cloud API key not configured"))
      return
    }

    setLoading(true)
    setError(null)

    try {
      const client = getValidationCloudClient()
      const blockHeight = await client.getBlockHeight()
      setHeight(blockHeight)
      logInfo("Fetched Bitcoin block height", { height: blockHeight })
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      logError("Error fetching Bitcoin block height", error)
      setError(error)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchHeight()

    // Optionally refresh every 60 seconds
    const interval = setInterval(fetchHeight, 60000)
    return () => clearInterval(interval)
  }, [fetchHeight])

  return {
    height,
    loading,
    error,
    refetch: fetchHeight,
  }
}

/**
 * Hook to validate a Bitcoin address
 */
export function useBitcoinAddressValidation(
  address: string | null
): UseBitcoinAddressValidationResult {
  const [isValid, setIsValid] = useState<boolean | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)
  const [details, setDetails] = useState<any | null>(null)

  useEffect(() => {
    if (!address) {
      setIsValid(null)
      setDetails(null)
      return
    }

    if (!isValidationCloudConfigured()) {
      setError(new Error("Validation Cloud API key not configured"))
      return
    }

    setLoading(true)
    setError(null)

    getValidationCloudClient()
      .validateAddress(address)
      .then((result) => {
        setIsValid(result.isvalid)
        setDetails(result)
        logInfo("Validated Bitcoin address", { address, isValid: result.isvalid })
      })
      .catch((err) => {
        const error = err instanceof Error ? err : new Error(String(err))
        logError("Error validating Bitcoin address", error)
        setError(error)
        setIsValid(false)
      })
      .finally(() => {
        setLoading(false)
      })
  }, [address])

  return {
    isValid,
    loading,
    error,
    details,
  }
}

/**
 * Hook to fetch blockchain information
 */
export function useBitcoinBlockchainInfo() {
  const [info, setInfo] = useState<any | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchInfo = useCallback(async () => {
    if (!isValidationCloudConfigured()) {
      setError(new Error("Validation Cloud API key not configured"))
      return
    }

    setLoading(true)
    setError(null)

    try {
      const client = getValidationCloudClient()
      const blockchainInfo = await client.getBlockchainInfo()
      setInfo(blockchainInfo)
      logInfo("Fetched Bitcoin blockchain info", blockchainInfo)
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      logError("Error fetching Bitcoin blockchain info", error)
      setError(error)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchInfo()
  }, [fetchInfo])

  return {
    info,
    loading,
    error,
    refetch: fetchInfo,
  }
}

/**
 * Hook to fetch transaction details
 */
export function useBitcoinTransaction(txid: string | null) {
  const [transaction, setTransaction] = useState<any | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchTransaction = useCallback(async () => {
    if (!txid) {
      setTransaction(null)
      return
    }

    if (!isValidationCloudConfigured()) {
      setError(new Error("Validation Cloud API key not configured"))
      return
    }

    setLoading(true)
    setError(null)

    try {
      const client = getValidationCloudClient()
      const tx = await client.getTransaction(txid, true)
      setTransaction(tx)
      logInfo("Fetched Bitcoin transaction", { txid })
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      logError("Error fetching Bitcoin transaction", error)
      setError(error)
    } finally {
      setLoading(false)
    }
  }, [txid])

  useEffect(() => {
    fetchTransaction()
  }, [fetchTransaction])

  return {
    transaction,
    loading,
    error,
    refetch: fetchTransaction,
  }
}

