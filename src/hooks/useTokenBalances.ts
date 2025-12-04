import { useState, useEffect } from "react"
import { createSwapActor } from "@/services/canisters"
import { logError } from "@/utils/logger"
import { useICP } from "./useICP"
import { retry, retryWithTimeout } from "@/utils/retry"

export interface TokenBalances {
  ckBTC: bigint | null
  ckETH: bigint | null
  ICP: bigint | null
  SOL: bigint | null
  isLoading: boolean
  error: string | null
  refresh: () => Promise<void>
}

export function useTokenBalances(): TokenBalances {
  const [ckBTC, setCkBTC] = useState<bigint | null>(null)
  const [ckETH, setCkETH] = useState<bigint | null>(null)
  const [ICP, setICP] = useState<bigint | null>(null)
  const [SOL, setSOL] = useState<bigint | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const { principal, isConnected } = useICP()

  async function loadBalances() {
    if (!isConnected || !principal) {
      setCkBTC(null)
      setCkETH(null)
      setICP(null)
      setSOL(null)
      setIsLoading(false)
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      const canister = await retry(
        () => createSwapActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )

      // Fetch all balances in parallel
      const [ckbtcResult, ckethResult, icpResult, solResult] = await Promise.allSettled([
        retryWithTimeout(
          () => canister.getCKBTCBalance(principal),
          10000,
          { maxRetries: 2, initialDelayMs: 500 }
        ),
        retryWithTimeout(
          () => canister.getCKETHBalance(principal),
          10000,
          { maxRetries: 2, initialDelayMs: 500 }
        ),
        retryWithTimeout(
          () => canister.getICPBalance(principal),
          10000,
          { maxRetries: 2, initialDelayMs: 500 }
        ),
        retryWithTimeout(
          () => canister.getUserSOLBalance(),
          10000,
          { maxRetries: 2, initialDelayMs: 500 }
        ),
      ])

      // Process ckBTC
      if (ckbtcResult.status === "fulfilled") {
        const result = ckbtcResult.value as { ok: bigint; err?: string } | { ok?: bigint; err: string }
        if ("ok" in result && result.ok !== undefined) {
          setCkBTC(result.ok)
        }
      }

      // Process ckETH
      if (ckethResult.status === "fulfilled") {
        const result = ckethResult.value as { ok: bigint; err?: string } | { ok?: bigint; err: string }
        if ("ok" in result && result.ok !== undefined) {
          setCkETH(result.ok)
        }
      }

      // Process ICP
      if (icpResult.status === "fulfilled") {
        const result = icpResult.value as { ok: bigint; err?: string } | { ok?: bigint; err: string }
        if ("ok" in result && result.ok !== undefined) {
          setICP(result.ok)
        }
      }

      // Process SOL
      if (solResult.status === "fulfilled") {
        const result = solResult.value as { ok: bigint; err?: string } | { ok?: bigint; err: string }
        if ("ok" in result && result.ok !== undefined) {
          setSOL(result.ok)
        }
      }
    } catch (error) {
      logError("Error loading token balances", error as Error)
      setError("Failed to load balances")
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    if (isConnected && principal) {
      loadBalances()
    } else {
      setCkBTC(null)
      setCkETH(null)
      setICP(null)
      setSOL(null)
    }
  }, [isConnected, principal])

  return {
    ckBTC,
    ckETH,
    ICP,
    SOL,
    isLoading,
    error,
    refresh: loadBalances,
  }
}

