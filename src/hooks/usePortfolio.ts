import { useState, useEffect } from "react"
import type { Portfolio } from "@/types"
import { createPortfolioActor } from "@/services/canisters"
import { logError } from "@/utils/logger"
import { useICP } from "./useICP"

const mockPortfolio: Portfolio = {
  totalValue: 12450.75,
  totalRewards: 0.0125,
  totalLended: 8000.0,
  assets: [
    { name: "Bitcoin", symbol: "BTC", amount: 0.15, value: 9000.5 },
    { name: "Ethereum", symbol: "ETH", amount: 1.0, value: 3000.25 },
    { name: "Solana", symbol: "SOL", amount: 10.0, value: 450.0 },
  ],
}

export function usePortfolio() {
  const [portfolio, setPortfolio] = useState<Portfolio | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const { principal, isConnected } = useICP()

  useEffect(() => {
    if (isConnected && principal) {
      loadPortfolio()
    } else {
      setPortfolio(null)
      setIsLoading(false)
    }
  }, [principal, isConnected])

  async function loadPortfolio() {
    if (!isConnected || !principal) {
      setPortfolio(null)
      setIsLoading(false)
      return
    }

    setIsLoading(true)
    setError(null)
    
    try {
      const canister = await createPortfolioActor()
      const canisterPortfolio = await canister.getPortfolio(principal)
      
      // Convert canister portfolio to frontend format
      const formattedPortfolio: Portfolio = {
        totalValue: canisterPortfolio.totalValue,
        totalRewards: Number(canisterPortfolio.totalRewards) / 1e8, // Convert from nat64
        totalLended: canisterPortfolio.totalLended,
        assets: canisterPortfolio.assets.map((asset) => ({
          name: asset.name,
          symbol: asset.symbol,
          amount: Number(asset.amount) / 1e8, // Convert from nat64
          value: asset.value,
        })),
      }
      
      setPortfolio(formattedPortfolio)
    } catch (error) {
      logError("Error loading portfolio", error as Error)
      setError("Failed to load portfolio from canister")
      // Don't use fallback mock data for portfolio - it should be empty if canister fails
      setPortfolio({
        totalValue: 0,
        totalRewards: 0,
        totalLended: 0,
        assets: [],
      })
    } finally {
      setIsLoading(false)
    }
  }

  return {
    portfolio,
    isLoading,
    error,
    refresh: loadPortfolio,
  }
}

