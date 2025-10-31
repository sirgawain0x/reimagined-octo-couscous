import { useState, useEffect } from "react"
import type { LendingAsset, LendingDeposit } from "@/types"
import { createLendingActor, requireAuth } from "@/services/canisters"
import { logError } from "@/utils/logger"
import { Principal } from "@dfinity/principal"
import { useICP } from "./useICP"

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
  const [error, setError] = useState<string | null>(null)
  const { principal, isConnected } = useICP()

  useEffect(() => {
    loadData()
  }, [principal])

  async function loadData() {
    setIsLoading(true)
    setError(null)
    
    try {
      const canister = await createLendingActor()
      const canisterAssets = await canister.getLendingAssets()
      
      // Convert canister assets to frontend format
      const formattedAssets: LendingAsset[] = canisterAssets.map((asset) => ({
        id: asset.id,
        name: asset.name,
        symbol: asset.symbol,
        apy: asset.apy,
        icon: asset.symbol === "BTC" 
          ? "https://placehold.co/40x40/f7931a/ffffff?text=BTC"
          : asset.symbol === "ETH"
          ? "https://placehold.co/40x40/627eea/ffffff?text=ETH"
          : "https://placehold.co/40x40/14f195/000000?text=SOL",
      }))
      
      setAssets(formattedAssets.length > 0 ? formattedAssets : mockLendingAssets)
      
      // Load user deposits if connected
      if (isConnected && principal) {
        try {
          const userDeposits = await canister.getUserDeposits(principal)
          const formattedDeposits: LendingDeposit[] = userDeposits.map((deposit) => ({
            asset: deposit.asset,
            amount: Number(deposit.amount) / 1e8, // Convert from nat64
            apy: deposit.apy,
          }))
          setDeposits(formattedDeposits)
        } catch (err) {
          // User might not have deposits yet, which is fine
          setDeposits([])
        }
      } else {
        setDeposits([])
      }
    } catch (error) {
      logError("Error loading lending data", error as Error)
      setError("Failed to load lending data from canister")
      // Use fallback data if canister fails
      setAssets(mockLendingAssets)
      setDeposits([])
    } finally {
      setIsLoading(false)
    }
  }

  async function deposit(asset: string, amount: number): Promise<boolean> {
    if (!isConnected || !principal) {
      logError("Deposit attempted without authentication", new Error("User not authenticated"))
      return false
    }

    if (amount <= 0) {
      logError("Invalid deposit amount", new Error(`Amount must be greater than 0, got ${amount}`))
      return false
    }

    if (!["BTC", "ETH", "SOL"].includes(asset.toUpperCase())) {
      logError("Invalid asset", new Error(`Asset must be BTC, ETH, or SOL, got ${asset}`))
      return false
    }

    try {
      const canister = await createLendingActor()
      
      // Convert amount to nat64 (multiply by 1e8 for satoshi-like precision)
      const amountNat64 = BigInt(Math.floor(amount * 1e8))
      
      const result = await canister.deposit(asset.toLowerCase(), amountNat64)
      
      if ("ok" in result) {
        await loadData() // Refresh data
        return true
      } else if ("err" in result) {
        logError("Canister returned error", new Error(result.err), { asset, amount })
        return false
      }
      
      return false
    } catch (error) {
      logError("Error depositing", error as Error, { asset, amount })
      return false
    }
  }

  async function withdraw(asset: string, amount: number, recipientAddress?: string): Promise<boolean> {
    if (!isConnected || !principal) {
      logError("Withdrawal attempted without authentication", new Error("User not authenticated"))
      return false
    }

    if (amount <= 0) {
      logError("Invalid withdrawal amount", new Error(`Amount must be greater than 0, got ${amount}`))
      return false
    }

    if (!["BTC", "ETH", "SOL"].includes(asset.toUpperCase())) {
      logError("Invalid asset", new Error(`Asset must be BTC, ETH, or SOL, got ${asset}`))
      return false
    }

    try {
      const canister = await createLendingActor()
      
      // Convert amount to nat64
      const amountNat64 = BigInt(Math.floor(amount * 1e8))
      
      // For BTC, require recipient address
      const address = recipientAddress || (asset.toUpperCase() === "BTC" ? "" : "mock_address")
      
      if (asset.toUpperCase() === "BTC" && !recipientAddress) {
        logError("Bitcoin withdrawal requires recipient address", new Error("No recipient address provided"))
        return false
      }
      
      const result = await canister.withdraw(asset.toLowerCase(), amountNat64, address)
      
      if ("ok" in result) {
        await loadData() // Refresh data
        return true
      } else if ("err" in result) {
        logError("Canister returned error", new Error(result.err), { asset, amount })
        return false
      }
      
      return false
    } catch (error) {
      logError("Error withdrawing", error as Error, { asset, amount })
      return false
    }
  }

  return {
    assets,
    deposits,
    isLoading,
    error,
    deposit,
    withdraw,
    refetch: loadData,
  }
}


