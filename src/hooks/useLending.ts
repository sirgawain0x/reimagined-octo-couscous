import { useState, useEffect } from "react"
import type { LendingAsset, LendingDeposit, BorrowInfo } from "@/types"
import { createLendingActor } from "@/services/canisters"
import { logError } from "@/utils/logger"
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

// Mock deposits (unused but kept for reference)
/*
const mockDeposits: LendingDeposit[] = [
  { asset: "BTC", amount: 0.1, apy: 4.2 },
  { asset: "ETH", amount: 0.5, apy: 5.1 },
]
*/

export function useLending() {
  const [assets, setAssets] = useState<LendingAsset[]>([])
  const [deposits, setDeposits] = useState<LendingDeposit[]>([])
  const [borrows, setBorrows] = useState<BorrowInfo[]>([])
  const [availableLiquidity, setAvailableLiquidity] = useState<Record<string, number>>({})
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
      
      // Load available liquidity for each asset
      const liquidityMap: Record<string, number> = {}
      for (const asset of formattedAssets) {
        try {
          const liquidity = await retryWithTimeout(
            () => canister.getAvailableLiquidity(asset.id),
            10000,
            { maxRetries: 3, initialDelayMs: 1000 }
          )
          liquidityMap[asset.id] = Number(liquidity) / 1e8
        } catch (err) {
          liquidityMap[asset.id] = 0
        }
      }
      setAvailableLiquidity(liquidityMap)

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

        // Load user borrows if connected
        try {
          const userBorrows = await retryWithTimeout(
            () => canister.getUserBorrows(principal),
            10000,
            { maxRetries: 3, initialDelayMs: 1000 }
          )
          const formattedBorrows: BorrowInfo[] = userBorrows.map((borrow) => ({
            id: borrow.id,
            asset: borrow.asset,
            borrowedAmount: borrow.borrowedAmount,
            collateralAmount: borrow.collateralAmount,
            collateralAsset: borrow.collateralAsset,
            interestRate: borrow.interestRate,
            ltv: borrow.ltv,
          }))
          setBorrows(formattedBorrows)
        } catch (err) {
          // User might not have borrows yet, which is fine
          setBorrows([])
        }
      } else {
        setDeposits([])
        setBorrows([])
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      const errorName = error instanceof Error ? error.name : ""
      
      // Check for canister ID configuration errors (validation errors)
      if (errorMessage.includes("canister ID not configured") || 
          errorMessage.includes("appears to be a placeholder") ||
          errorMessage.includes("has invalid format")) {
        logError("Lending canister ID configuration error", error as Error)
        // Display the full error message which includes helpful instructions
        setError(errorMessage)
        // Use fallback data
        setAssets(mockLendingAssets)
        setDeposits([])
      } 
      // Check if error is due to network mismatch or missing canister (TrustError)
      else if (errorName === "TrustError" || errorMessage.includes("node signatures") || errorMessage.includes("TrustError")) {
        logError("Network mismatch or canister not found", error as Error)
        setError("Lending canister not found or network mismatch. Make sure VITE_ICP_NETWORK matches where your canisters are deployed (local vs ic).")
        // Use fallback data
        setAssets(mockLendingAssets)
        setDeposits([])
      } 
      // Check for canister not found errors from the IC
      else if (errorMessage.includes("canister_not_found") || 
               errorMessage.includes("not found") ||
               errorMessage.includes("Canister") && errorMessage.includes("not found")) {
        logError("Lending canister not found", error as Error)
        setError("Lending canister not found. The canister ID may be incorrect or the canister may not be deployed. Run 'dfx canister id lending_canister' to get the correct ID and update VITE_CANISTER_ID_LENDING in your .env file.")
        // Use fallback data
        setAssets(mockLendingAssets)
        setDeposits([])
      } 
      // Generic error handling
      else {
        logError("Error loading lending data", error as Error)
        setError(`Failed to load lending data: ${errorMessage}`)
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

  async function borrow(
    asset: string,
    amount: number,
    collateralAsset: string,
    collateralAmount: number
  ): Promise<boolean> {
    if (!isConnected || !principal) {
      logError("Borrow attempted without authentication", new Error("User not authenticated"))
      return false
    }

    if (amount <= 0) {
      logError("Invalid borrow amount", new Error(`Amount must be greater than 0, got ${amount}`))
      return false
    }

    if (collateralAmount <= 0) {
      logError("Invalid collateral amount", new Error(`Collateral amount must be greater than 0, got ${collateralAmount}`))
      return false
    }

    if (!["BTC", "ETH", "SOL"].includes(asset.toUpperCase())) {
      logError("Invalid asset", new Error(`Asset must be BTC, ETH, or SOL, got ${asset}`))
      return false
    }

    if (!["BTC", "ETH", "SOL"].includes(collateralAsset.toUpperCase())) {
      logError("Invalid collateral asset", new Error(`Collateral asset must be BTC, ETH, or SOL, got ${collateralAsset}`))
      return false
    }

    try {
      // Frontend rate limiting
      checkRateLimit("lending", principal.toText())
      
      // borrow is an update method, requires authentication
      const canister = await retry(
        () => createLendingActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      // Convert amounts to nat64 (multiply by 1e8 for satoshi-like precision)
      const amountNat64 = BigInt(Math.floor(amount * 1e8))
      const collateralAmountNat64 = BigInt(Math.floor(collateralAmount * 1e8))
      
      const result = await retryWithTimeout(
        () => canister.borrow(asset.toLowerCase(), amountNat64, collateralAsset.toLowerCase(), collateralAmountNat64),
        30000, // 30 second timeout for update operations
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
      if ("ok" in result) {
        await loadData() // Refresh data
        return true
      } else if ("err" in result) {
        logError("Canister returned error", new Error(result.err), { asset, amount, collateralAsset, collateralAmount })
        return false
      }
      
      return false
    } catch (error) {
      logError("Error borrowing", error as Error, { asset, amount, collateralAsset, collateralAmount })
      return false
    }
  }

  async function repay(borrowId: bigint, amount: number): Promise<boolean> {
    if (!isConnected || !principal) {
      logError("Repay attempted without authentication", new Error("User not authenticated"))
      return false
    }

    if (amount <= 0) {
      logError("Invalid repay amount", new Error(`Amount must be greater than 0, got ${amount}`))
      return false
    }

    try {
      // Frontend rate limiting
      checkRateLimit("lending", principal.toText())
      
      // repay is an update method, requires authentication
      const canister = await retry(
        () => createLendingActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      // Convert amount to nat64
      const amountNat64 = BigInt(Math.floor(amount * 1e8))
      
      const result = await retryWithTimeout(
        () => canister.repay(borrowId, amountNat64),
        30000, // 30 second timeout for update operations
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
      if ("ok" in result) {
        await loadData() // Refresh data
        return true
      } else if ("err" in result) {
        logError("Canister returned error", new Error(result.err), { borrowId, amount })
        return false
      }
      
      return false
    } catch (error) {
      logError("Error repaying", error as Error, { borrowId, amount })
      return false
    }
  }

  return {
    assets,
    deposits,
    borrows,
    availableLiquidity,
    isLoading,
    error,
    deposit,
    withdraw,
    borrow,
    repay,
    refetch: loadData,
  }
}


