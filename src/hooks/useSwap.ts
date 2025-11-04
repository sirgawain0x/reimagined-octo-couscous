import { useState, useEffect } from "react"
import type { ChainKeyToken, SwapPool, SwapQuote, SwapRecord } from "@/types"
import { createSwapActor, requireAuth } from "@/services/canisters"
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
  const [error, setError] = useState<string | null>(null)
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
      const formattedPools: SwapPool[] = canisterPools.map((pool, index) => {
        // Extract token names from variant objects
        const tokenAName = "ckBTC" in pool.tokenA ? "ckBTC" 
          : "ckETH" in pool.tokenA ? "ckETH" 
          : "SOL" in pool.tokenA ? "SOL" 
          : "ICP"
        const tokenBName = "ckBTC" in pool.tokenB ? "ckBTC" 
          : "ckETH" in pool.tokenB ? "ckETH" 
          : "SOL" in pool.tokenB ? "SOL" 
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
      
      if ("ok" in result) {
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
      logError("Error getting quote", error as Error, { poolId, amountIn })
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
      let tokenInVariant: any
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
        () => canister.swap(poolId, tokenInVariant, amountIn, minAmountOut),
        30000, // 30 second timeout for swap operations
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
      if ("ok" in result) {
        await loadPools() // Refresh pools
        return { success: true, txIndex: BigInt(result.ok.txIndex) }
      } else if ("err" in result) {
        logError("Canister returned error", new Error(result.err), { poolId, tokenIn, amountIn })
        return { success: false }
      }
      
      return { success: false }
    } catch (error) {
      logError("Error executing swap", error as Error, { poolId, tokenIn, amountIn })
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
        const tokenInName = "ckBTC" in swap.tokenIn ? "ckBTC" 
          : "ckETH" in swap.tokenIn ? "ckETH" 
          : "SOL" in swap.tokenIn ? "SOL" 
          : "ICP"
        const tokenOutName = "ckBTC" in swap.tokenOut ? "ckBTC" 
          : "ckETH" in swap.tokenOut ? "ckETH" 
          : "SOL" in swap.tokenOut ? "SOL" 
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

