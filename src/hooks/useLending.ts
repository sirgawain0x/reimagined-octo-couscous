import { useState, useEffect } from "react"
import type { LendingAsset, LendingDeposit } from "@/types"
import { createLendingActor, requireAuth } from "@/services/canisters"
import { logError } from "@/utils/logger"
import { Principal } from "@dfinity/principal"
import { useICP } from "./useICP"
import { retry, retryWithTimeout } from "@/utils/retry"
import { checkRateLimit } from "@/utils/rateLimiter"

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
  }, [principal, isConnected])

  async function loadData() {
    setIsLoading(true)
    setError(null)
    
    try {
      // getLendingAssets is a query method, so we can use anonymous agent if not authenticated
      const canister = await retry(
        () => createLendingActor(true),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      const canisterAssets = await retryWithTimeout(
        () => canister.getLendingAssets(),
        10000, // 10 second timeout for query
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
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
          const userDeposits = await retryWithTimeout(
            () => canister.getUserDeposits(principal),
            10000,
            { maxRetries: 3, initialDelayMs: 1000 }
          )
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
      const errorMessage = error instanceof Error ? error.message : String(error)
      const errorName = error instanceof Error ? error.name : ""
      
      // Check if error is due to network mismatch or missing canister (TrustError)
      if (errorName === "TrustError" || errorMessage.includes("node signatures") || errorMessage.includes("TrustError")) {
        logError("Network mismatch or canister not found", error as Error)
        setError("Lending canister not found or network mismatch. Make sure VITE_ICP_NETWORK matches where your canisters are deployed (local vs ic).")
        // Use fallback data
        setAssets(mockLendingAssets)
        setDeposits([])
      } else if (errorMessage.includes("placeholder") || errorMessage.includes("Invalid canister ID")) {
        logError("Lending canister not deployed", error as Error)
        setError("Lending canister is not deployed. Please deploy it or configure a valid canister ID.")
        // Use fallback data
        setAssets(mockLendingAssets)
        setDeposits([])
      } else if (errorMessage.includes("canister_not_found") || errorMessage.includes("not found")) {
        logError("Lending canister not found", error as Error)
        setError("Lending canister not found. Please deploy the lending_canister or check your canister ID configuration.")
        // Use fallback data
        setAssets(mockLendingAssets)
        setDeposits([])
      } else {
        logError("Error loading lending data", error as Error)
        setError("Failed to load lending data from canister")
        // Use fallback data if canister fails
        setAssets(mockLendingAssets)
        setDeposits([])
      }
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
      // Frontend rate limiting
      checkRateLimit("lending", principal.toText())
      
      // deposit is an update method, requires authentication
      const canister = await retry(
        () => createLendingActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      // Convert amount to nat64 (multiply by 1e8 for satoshi-like precision)
      const amountNat64 = BigInt(Math.floor(amount * 1e8))
      
      const result = await retryWithTimeout(
        () => canister.deposit(asset.toLowerCase(), amountNat64),
        30000, // 30 second timeout for update operations
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
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
      // Frontend rate limiting
      checkRateLimit("lending", principal.toText())
      
      // withdraw is an update method, requires authentication
      const canister = await retry(
        () => createLendingActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      // Convert amount to nat64
      const amountNat64 = BigInt(Math.floor(amount * 1e8))
      
      // For BTC, require recipient address
      const address = recipientAddress || (asset.toUpperCase() === "BTC" ? "" : "mock_address")
      
      if (asset.toUpperCase() === "BTC" && !recipientAddress) {
        logError("Bitcoin withdrawal requires recipient address", new Error("No recipient address provided"))
        return false
      }
      
      const result = await retryWithTimeout(
        () => canister.withdraw(asset.toLowerCase(), amountNat64, address),
        60000, // 60 second timeout for withdrawal (longer due to Bitcoin processing)
        { maxRetries: 3, initialDelayMs: 2000 }
      )
      
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


