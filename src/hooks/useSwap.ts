import { useState, useEffect } from "react"
import type { ChainKeyToken, SwapPool, SwapQuote, SwapRecord } from "@/types"
import { createSwapActor } from "@/services/canisters"
import { logError } from "@/utils/logger"
import { useICP } from "./useICP"
import { retry, retryWithTimeout } from "@/utils/retry"
import { checkRateLimit } from "@/utils/rateLimiter"

const mockPools: SwapPool[] = [
  {
    id: "ckBTC_ICP",
    tokenA: "ckBTC",
    tokenB: "ICP",
    liquidity: 150000,
    volume24h: 25000,
  },
  {
    id: "ckETH_ICP",
    tokenA: "ckETH",
    tokenB: "ICP",
    liquidity: 32000,
    volume24h: 15000,
  },
  {
    id: "SOL_ICP",
    tokenA: "SOL",
    tokenB: "ICP",
    liquidity: 28000,
    volume24h: 12000,
  },
]

export function useSwap() {
  const [pools, setPools] = useState<SwapPool[]>([])
  const [quote, setQuote] = useState<SwapQuote | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [_error, setError] = useState<string | null>(null)
  const { principal, isConnected } = useICP()

  useEffect(() => {
    loadPools()
  }, [isConnected])

  async function loadPools() {
    setIsLoading(true)
    setError(null)
    
    try {
      const canister = await retry(
        () => createSwapActor(true),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      const canisterPools = await retryWithTimeout(
        () => canister.getPools(),
        10000, // 10 second timeout for query
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
      // Convert canister pools to frontend format
      // ChainKeyToken variants come as objects like { ckBTC: null }, { ckETH: null }, { ckSOL: null }, { ICP: null }
      const formattedPools: SwapPool[] = canisterPools.map((pool) => {
        // Extract token names from variant objects
        // Type assertion needed because TypeScript sees ChainKeyToken as string, but it's actually a variant object
        const tokenA = pool.tokenA as unknown as Record<string, unknown>
        const tokenB = pool.tokenB as unknown as Record<string, unknown>
        const tokenAName = "ckBTC" in tokenA ? "ckBTC" 
          : "ckETH" in tokenA ? "ckETH" 
          : "SOL" in tokenA ? "SOL" 
          : "ICP"
        const tokenBName = "ckBTC" in tokenB ? "ckBTC" 
          : "ckETH" in tokenB ? "ckETH" 
          : "SOL" in tokenB ? "SOL" 
          : "ICP"
        const poolId = `${tokenAName}_${tokenBName}`
        return {
          id: poolId,
          tokenA: tokenAName as ChainKeyToken,
          tokenB: tokenBName as ChainKeyToken,
          liquidity: Number(pool.reserveA) / 1e8 + Number(pool.reserveB) / 1e8,
          volume24h: 0, // Canister doesn't provide this yet
        }
      })
      
      setPools(formattedPools.length > 0 ? formattedPools : mockPools)
    } catch (error) {
      logError("Error loading pools", error as Error)
      setError("Failed to load pools from canister")
      setPools(mockPools)
    } finally {
      setIsLoading(false)
    }
  }

  async function getQuote(poolId: string, amountIn: bigint): Promise<SwapQuote | null> {
    if (!amountIn || amountIn <= 0) {
      setQuote(null)
      return null
    }

    try {
      const canister = await retry(
        () => createSwapActor(true),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      const result = await retryWithTimeout(
        () => canister.getQuote(poolId, amountIn),
        10000, // 10 second timeout for query
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
      if ("ok" in result && result.ok) {
        const quote: SwapQuote = {
          amountOut: result.ok.amountOut,
          priceImpact: result.ok.priceImpact,
          fee: result.ok.fee,
        }
        setQuote(quote)
        return quote
      } else {
        setQuote(null)
        return null
      }
    } catch (error) {
      logError("Error getting quote", error as Error, { poolId, amountIn: String(amountIn) })
      return null
    }
  }

  async function executeSwap(
    poolId: string,
    tokenIn: ChainKeyToken,
    amountIn: bigint,
    minAmountOut: bigint
  ): Promise<{ success: boolean; txIndex?: bigint }> {
    if (!isConnected || !principal) {
      logError("Swap attempted without authentication", new Error("User not authenticated"))
      return { success: false }
    }

    if (amountIn <= 0) {
      logError("Invalid swap amount", new Error(`Amount must be greater than 0, got ${amountIn}`))
      return { success: false }
    }

    try {
      // Frontend rate limiting
      checkRateLimit("swap", principal.toText())
      
      // swap is an update method, requires authentication
      const canister = await retry(
        () => createSwapActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      // Convert ChainKeyToken string to variant
      // The canister expects a variant object like { ckBTC: null }
      type ChainKeyTokenVariant = { ckBTC: null } | { ckETH: null } | { SOL: null } | { ICP: null }
      let tokenInVariant: ChainKeyTokenVariant
      if (tokenIn === "ckBTC") {
        tokenInVariant = { ckBTC: null }
      } else if (tokenIn === "ckETH") {
        tokenInVariant = { ckETH: null }
      } else if (tokenIn === "SOL") {
        tokenInVariant = { SOL: null }
      } else {
        tokenInVariant = { ICP: null }
      }
      
      const result = await retryWithTimeout(
        () => canister.swap(poolId, tokenInVariant as any, amountIn, minAmountOut),
        30000, // 30 second timeout for swap operations
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
      if ("ok" in result && result.ok) {
        await loadPools() // Refresh pools
        return { success: true, txIndex: BigInt(result.ok.txIndex) }
      } else if ("err" in result && result.err) {
        logError("Canister returned error", new Error(result.err), { poolId, tokenIn: String(tokenIn), amountIn: String(amountIn) })
        return { success: false }
      }
      
      return { success: false }
    } catch (error) {
      logError("Error executing swap", error as Error, { poolId, tokenIn: String(tokenIn), amountIn: String(amountIn) })
      return { success: false }
    }
  }

  async function getSwapHistory(): Promise<SwapRecord[]> {
    if (!isConnected || !principal) {
      return []
    }

    try {
      const canister = await retry(
        () => createSwapActor(true),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      const history = await retryWithTimeout(
        () => canister.getSwapHistory(principal),
        10000,
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
      return history.map((swap) => {
        // Type assertion needed because TypeScript sees ChainKeyToken as string, but it's actually a variant object
        const tokenIn = swap.tokenIn as unknown as Record<string, unknown>
        const tokenOut = swap.tokenOut as unknown as Record<string, unknown>
        const tokenInName = "ckBTC" in tokenIn ? "ckBTC" 
          : "ckETH" in tokenIn ? "ckETH" 
          : "SOL" in tokenIn ? "SOL" 
          : "ICP"
        const tokenOutName = "ckBTC" in tokenOut ? "ckBTC" 
          : "ckETH" in tokenOut ? "ckETH" 
          : "SOL" in tokenOut ? "SOL" 
          : "ICP"
        return {
          id: swap.id,
          tokenIn: tokenInName as ChainKeyToken,
          tokenOut: tokenOutName as ChainKeyToken,
          amountIn: swap.amountIn,
          amountOut: swap.amountOut,
          timestamp: swap.timestamp,
        }
      })
    } catch (error) {
      logError("Error getting swap history", error as Error)
      return []
    }
  }

  return {
    pools,
    quote,
    isLoading,
    getQuote,
    executeSwap,
    getSwapHistory,
    refresh: loadPools,
  }
}

