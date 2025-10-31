import { useState, useEffect } from "react"
import type { Portfolio } from "@/types"

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

  useEffect(() => {
    loadPortfolio()
  }, [])

  async function loadPortfolio() {
    setIsLoading(true)
    try {
      // TODO: Replace with actual canister call
      // const canister = createActor<PortfolioCanister>(ICP_CONFIG.canisterIds.portfolio, idlFactory)
      // const portfolio = await canister.getPortfolio(principal)
      // setPortfolio(portfolio)

      // Mock data for now
      await new Promise((resolve) => setTimeout(resolve, 500))
      setPortfolio(mockPortfolio)
    } catch (error) {
      console.error("Error loading portfolio:", error)
    } finally {
      setIsLoading(false)
    }
  }

  return {
    portfolio,
    isLoading,
    refresh: loadPortfolio,
  }
}

