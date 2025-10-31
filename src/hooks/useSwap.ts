import { useState, useEffect } from "react"
import type { ChainKeyToken, SwapPool, SwapQuote, SwapRecord } from "@/types"
import { createSwapActor, requireAuth } from "@/services/canisters"
import { logError } from "@/utils/logger"
import { useICP } from "./useICP"

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
]

export function useSwap() {
  const [pools, setPools] = useState<SwapPool[]>([])
  const [quote, setQuote] = useState<SwapQuote | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const { principal, isConnected } = useICP()

  useEffect(() => {
    loadPools()
  }, [])

  async function loadPools() {
    setIsLoading(true)
    setError(null)
    
    try {
      const canister = await createSwapActor()
      const canisterPools = await canister.getPools()
      
      // Convert canister pools to frontend format
      const formattedPools: SwapPool[] = canisterPools.map((pool, index) => {
        // Extract token names from variant objects
        const tokenAName = "ckBTC" in pool.tokenA ? "ckBTC" : "ckETH" in pool.tokenA ? "ckETH" : "ICP"
        const tokenBName = "ckBTC" in pool.tokenB ? "ckBTC" : "ckETH" in pool.tokenB ? "ckETH" : "ICP"
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
      setPools(mockPools) // Fallback to mock data
    } finally {
      setIsLoading(false)
    }
  }

  async function getQuote(poolId: string, amountIn: bigint): Promise<SwapQuote | null> {
    if (amountIn <= 0) {
      logError("Invalid quote amount", new Error(`Amount must be greater than 0, got ${amountIn}`))
      return null
    }

    try {
      const canister = await createSwapActor()
      const result = await canister.getQuote(poolId, amountIn)
      
      if ("ok" in result) {
        const quote: SwapQuote = {
          amountOut: result.ok.amountOut,
          priceImpact: result.ok.priceImpact,
          fee: result.ok.fee,
        }
        setQuote(quote)
        return quote
      } else if ("err" in result) {
        logError("Canister returned error", new Error(result.err), { poolId, amountIn })
        return null
      }
      
      return null
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
      const canister = await createSwapActor()
      
      // Convert ChainKeyToken string to variant
      let tokenInVariant: any
      if (tokenIn === "ckBTC") {
        tokenInVariant = { ckBTC: null }
      } else if (tokenIn === "ckETH") {
        tokenInVariant = { ckETH: null }
      } else {
        tokenInVariant = { ICP: null }
      }
      
      const result = await canister.swap(poolId, tokenInVariant, amountIn, minAmountOut)
      
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
      const canister = await createSwapActor()
      const history = await canister.getSwapHistory(principal)
      
      return history.map((swap) => {
        const tokenInName = "ckBTC" in swap.tokenIn ? "ckBTC" : "ckETH" in swap.tokenIn ? "ckETH" : "ICP"
        const tokenOutName = "ckBTC" in swap.tokenOut ? "ckBTC" : "ckETH" in swap.tokenOut ? "ckETH" : "ICP"
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
      logError("Error loading swap history", error as Error)
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

