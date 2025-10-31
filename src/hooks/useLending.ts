import { useState, useEffect } from "react"
import type { LendingAsset, LendingDeposit } from "@/types"

const mockLendingAssets: LendingAsset[] = [
  {
    id: "btc",
    name: "Bitcoin",
    symbol: "BTC",
    apy: 4.2,
    icon: "https://placehold.co/40x40/f7931a/ffffff?text=BTC",
  },
  {
    id: "eth",
    name: "Ethereum",
    symbol: "ETH",
    apy: 5.1,
    icon: "https://placehold.co/40x40/627eea/ffffff?text=ETH",
  },
  {
    id: "sol",
    name: "Solana",
    symbol: "SOL",
    apy: 6.5,
    icon: "https://placehold.co/40x40/14f195/000000?text=SOL",
  },
]

const mockDeposits: LendingDeposit[] = [
  { asset: "BTC", amount: 0.1, apy: 4.2 },
  { asset: "ETH", amount: 0.5, apy: 5.1 },
]

export function useLending() {
  const [assets, setAssets] = useState<LendingAsset[]>([])
  const [deposits, setDeposits] = useState<LendingDeposit[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    loadData()
  }, [])

  async function loadData() {
    setIsLoading(true)
    try {
      // TODO: Replace with actual canister calls
      // const canister = createActor<LendingCanister>(ICP_CONFIG.canisterIds.lending, idlFactory)
      // const [assets, deposits] = await Promise.all([
      //   canister.getLendingAssets(),
      //   canister.getUserDeposits(principal),
      // ])

      // Mock data for now
      await new Promise((resolve) => setTimeout(resolve, 500))
      setAssets(mockLendingAssets)
      setDeposits(mockDeposits)
    } catch (error) {
      console.error("Error loading lending data:", error)
    } finally {
      setIsLoading(false)
    }
  }

  async function deposit(asset: string, amount: number): Promise<boolean> {
    try {
      // TODO: Replace with actual canister call
      // const canister = createActor<LendingCanister>(ICP_CONFIG.canisterIds.lending, idlFactory)
      // const result = await canister.deposit(asset, amount)
      // if (result.success) {
      //   await loadData()
      // }
      // return result.success

      // Mock response
      await new Promise((resolve) => setTimeout(resolve, 1000))
      setDeposits((prev) => [...prev, { asset, amount, apy: assets.find((a) => a.symbol === asset)?.apy || 0 }])
      return true
    } catch (error) {
      console.error("Error depositing:", error)
      return false
    }
  }

  async function withdraw(asset: string, amount: number): Promise<boolean> {
    try {
      // TODO: Replace with actual canister call
      // const canister = createActor<LendingCanister>(ICP_CONFIG.canisterIds.lending, idlFactory)
      // const result = await canister.withdraw(asset, amount)
      // if (result.success) {
      //   await loadData()
      // }
      // return result.success

      // Mock response
      await new Promise((resolve) => setTimeout(resolve, 1000))
      setDeposits((prev) => prev.filter((d) => !(d.asset === asset && d.amount === amount)))
      return true
    } catch (error) {
      console.error("Error withdrawing:", error)
      return false
    }
  }

  return {
    assets,
    deposits,
    isLoading,
    deposit,
    withdraw,
  }
}

