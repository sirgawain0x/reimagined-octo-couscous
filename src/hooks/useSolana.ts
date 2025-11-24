import { useState, useEffect } from "react"
import { createSwapActor } from "@/services/canisters"
import { logError } from "@/utils/logger"
import { useICP } from "./useICP"
import { retry, retryWithTimeout } from "@/utils/retry"

export interface UseSolanaResult {
  address: string | null
  balance: bigint | null
  swapBalance: bigint | null
  isLoading: boolean
  error: string | null
  getAddress: () => Promise<void>
  getBalance: (address?: string) => Promise<void>
  getSwapBalance: () => Promise<void>
  sendSOL: (toAddress: string, amountLamports: bigint) => Promise<{ success: boolean; signature?: string }>
  getRecentBlockhash: () => Promise<string | null>
  getSlot: () => Promise<bigint | null>
}

export function useSolana(): UseSolanaResult {
  const [address, setAddress] = useState<string | null>(null)
  const [balance, setBalance] = useState<bigint | null>(null)
  const [swapBalance, setSwapBalance] = useState<bigint | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const { principal, isConnected } = useICP()

  async function getAddress() {
    if (!isConnected || !principal) {
      setError("Not connected")
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      const canister = await retry(
        () => createSwapActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )

      const result = await retryWithTimeout(
        () => canister.getSolanaAddress(undefined),
        30000,
        { maxRetries: 3, initialDelayMs: 1000 }
      ) as { ok: string; err?: string } | { ok?: string; err: string }

      if ("ok" in result && result.ok) {
        setAddress(result.ok)
      } else if ("err" in result && result.err) {
        // Filter out technical Candid errors that users won't understand
        const isTechnicalError = result.err.toLowerCase().includes("invalid opt") ||
                                 result.err.toLowerCase().includes("candid decode") ||
                                 result.err.toLowerCase().includes("type mismatch")
        
        if (isTechnicalError) {
          // Don't set error for technical issues - they're confusing to users
          // Still log for debugging
          logError("Technical error getting Solana address (hidden from user)", new Error(result.err))
        } else {
          setError(result.err)
          logError("Failed to get Solana address", new Error(result.err))
        }
      }
    } catch (error) {
      const err = error as Error
      // Filter out technical Candid errors
      const isTechnicalError = err.message.toLowerCase().includes("invalid opt") ||
                               err.message.toLowerCase().includes("candid decode") ||
                               err.message.toLowerCase().includes("type mismatch")
      
      if (!isTechnicalError) {
        setError(err.message)
      }
      logError("Error getting Solana address", err)
    } finally {
      setIsLoading(false)
    }
  }

  async function getBalance(addressToCheck?: string) {
    const targetAddress = addressToCheck || address
    if (!targetAddress) {
      setError("No address available")
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      const canister = await retry(
        () => createSwapActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )

      const result = await retryWithTimeout(
        () => canister.getSOLBalance(targetAddress),
        30000,
        { maxRetries: 3, initialDelayMs: 1000 }
      ) as { ok: bigint; err?: string } | { ok?: bigint; err: string }

      if ("ok" in result && result.ok !== undefined) {
        setBalance(result.ok)
      } else if ("err" in result && result.err) {
        // Filter out technical Candid errors
        const isTechnicalError = result.err.toLowerCase().includes("invalid opt") ||
                                 result.err.toLowerCase().includes("candid decode") ||
                                 result.err.toLowerCase().includes("type mismatch")
        
        if (!isTechnicalError) {
          setError(result.err)
          logError("Failed to get SOL balance", new Error(result.err))
        } else {
          logError("Technical error getting SOL balance (hidden from user)", new Error(result.err))
        }
      }
    } catch (error) {
      const err = error as Error
      const isTechnicalError = err.message.toLowerCase().includes("invalid opt") ||
                               err.message.toLowerCase().includes("candid decode") ||
                               err.message.toLowerCase().includes("type mismatch")
      
      if (!isTechnicalError) {
        setError(err.message)
      }
      logError("Error getting SOL balance", err)
    } finally {
      setIsLoading(false)
    }
  }

  async function getSwapBalance() {
    if (!isConnected || !principal) {
      setError("Not connected")
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      const canister = await retry(
        () => createSwapActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )

      const result = await retryWithTimeout(
        () => canister.getUserSOLBalance(),
        30000,
        { maxRetries: 3, initialDelayMs: 1000 }
      ) as { ok: bigint; err?: string } | { ok?: bigint; err: string }

      if ("ok" in result && result.ok !== undefined) {
        setSwapBalance(result.ok)
      } else if ("err" in result && result.err) {
        // Filter out technical Candid errors
        const isTechnicalError = result.err.toLowerCase().includes("invalid opt") ||
                                 result.err.toLowerCase().includes("candid decode") ||
                                 result.err.toLowerCase().includes("type mismatch")
        
        if (!isTechnicalError) {
          setError(result.err)
          logError("Failed to get SOL swap balance", new Error(result.err))
        } else {
          logError("Technical error getting SOL swap balance (hidden from user)", new Error(result.err))
        }
      }
    } catch (error) {
      const err = error as Error
      const isTechnicalError = err.message.toLowerCase().includes("invalid opt") ||
                               err.message.toLowerCase().includes("candid decode") ||
                               err.message.toLowerCase().includes("type mismatch")
      
      if (!isTechnicalError) {
        setError(err.message)
      }
      logError("Error getting SOL swap balance", err)
    } finally {
      setIsLoading(false)
    }
  }

  async function sendSOL(
    toAddress: string,
    amountLamports: bigint
  ): Promise<{ success: boolean; signature?: string }> {
    if (!isConnected || !principal) {
      logError("Send SOL attempted without authentication", new Error("User not authenticated"))
      return { success: false }
    }

    if (amountLamports <= 0) {
      logError("Invalid SOL amount", new Error(`Amount must be greater than 0, got ${amountLamports}`))
      return { success: false }
    }

    try {
      const canister = await retry(
        () => createSwapActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )

      const result = await retryWithTimeout(
        () => canister.sendSOL(toAddress, amountLamports, undefined),
        60000, // 60 second timeout for transaction sending
        { maxRetries: 3, initialDelayMs: 1000 }
      ) as { ok: string; err?: string } | { ok?: string; err: string }

      if ("ok" in result && result.ok) {
        return { success: true, signature: result.ok }
      } else if ("err" in result && result.err) {
        logError("Canister returned error", new Error(result.err), { toAddress, amountLamports })
        return { success: false }
      }

      return { success: false }
    } catch (error) {
      logError("Error sending SOL", error as Error, { toAddress, amountLamports })
      return { success: false }
    }
  }

  async function getRecentBlockhash(): Promise<string | null> {
    try {
      const canister = await retry(
        () => createSwapActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )

      const result = await retryWithTimeout(
        () => canister.getRecentBlockhash(),
        30000,
        { maxRetries: 3, initialDelayMs: 1000 }
      ) as { ok: string; err?: string } | { ok?: string; err: string }

      if ("ok" in result && result.ok) {
        return result.ok
      } else if ("err" in result && result.err) {
        logError("Failed to get recent blockhash", new Error(result.err))
        return null
      }

      return null
    } catch (error) {
      logError("Error getting recent blockhash", error as Error)
      return null
    }
  }

  async function getSlot(): Promise<bigint | null> {
    try {
      const canister = await retry(
        () => createSwapActor(true),
        { maxRetries: 3, initialDelayMs: 500 }
      )

      const result = await retryWithTimeout(
        () => canister.getSolanaSlot(),
        30000,
        { maxRetries: 3, initialDelayMs: 1000 }
      ) as { ok: bigint; err?: string } | { ok?: bigint; err: string }

      if ("ok" in result && result.ok !== undefined) {
        return result.ok
      } else if ("err" in result && result.err) {
        logError("Failed to get Solana slot", new Error(result.err))
        return null
      }

      return null
    } catch (error) {
      logError("Error getting Solana slot", error as Error)
      return null
    }
  }

  // Auto-fetch address when connected
  useEffect(() => {
    if (isConnected && principal && !address) {
      getAddress()
    }
  }, [isConnected, principal])

  // Auto-fetch balance when address is available
  useEffect(() => {
    if (address && !balance) {
      getBalance()
    }
  }, [address])

  return {
    address,
    balance,
    swapBalance,
    isLoading,
    error,
    getAddress,
    getBalance,
    getSwapBalance,
    sendSOL,
    getRecentBlockhash,
    getSlot,
  }
}

