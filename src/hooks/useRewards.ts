import { useState, useEffect } from "react"
import type { Store } from "@/types"
import { createRewardsActor } from "@/services/canisters"
import { logError, logWarn } from "@/utils/logger"
import { useICP } from "./useICP"
import { retry, retryWithTimeout } from "@/utils/retry"
import { checkRateLimit } from "@/utils/rateLimiter"
import { AFFILIATE_LINKS } from "@/config/env"

// Fallback stores if canister is not available
const fallbackStores: Store[] = [
  { id: 1, name: "Amazon", reward: 5, logo: "https://placehold.co/100x100/1e293b/ffffff?text=AMZN", url: AFFILIATE_LINKS.amazon },
  { id: 2, name: "Walmart", reward: 3.5, logo: "https://placehold.co/100x100/1e293b/ffffff?text=WMT", url: AFFILIATE_LINKS.walmart },
  { id: 3, name: "Nike", reward: 8, logo: "https://placehold.co/100x100/1e293b/ffffff?text=NIKE" },
  { id: 4, name: "eBay", reward: 2, logo: "https://placehold.co/100x100/1e293b/ffffff?text=EBAY", url: AFFILIATE_LINKS.ebay },
]

export function useRewards() {
  const [stores, setStores] = useState<Store[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const { principal, isConnected, isLoading: isAuthLoading } = useICP()

  useEffect(() => {
    // Wait for auth check to complete before loading stores
    // This prevents errors when trying to create actors before agent is initialized
    if (!isAuthLoading) {
      loadStores()
    }
  }, [isAuthLoading])

  async function loadStores() {
    setIsLoading(true)
    setError(null)
    
    try {
      // getStores is a query method, so we can use anonymous agent if not authenticated
      // Use retry with timeout for query operations (shorter timeout for queries)
      const canister = await retry(
        () => createRewardsActor(true),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      const canisterStores = await retryWithTimeout(
        () => canister.getStores(),
        10000, // 10 second timeout for query
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
      // Convert canister store format to frontend format
      const formattedStores: Store[] = canisterStores.map((store) => ({
        id: store.id,
        name: store.name,
        reward: store.reward,
        logo: store.logo || `https://placehold.co/100x100/1e293b/ffffff?text=${store.name.substring(0, 4).toUpperCase()}`,
        url: store.url || undefined,
      }))
      
      setStores(formattedStores.length > 0 ? formattedStores : fallbackStores)
    } catch (error: any) {
      const errorMessage = error?.message || String(error)
      const errorName = error?.name || ""
      const errorBody = error?.body || String(error)
      
      // Check if error is due to certificate verification (canister doesn't exist)
      if (errorName === "ProtocolError" || 
          errorMessage.includes("certificate verification") || 
          errorMessage.includes("Invalid delegation") ||
          errorMessage.includes("canister signature") ||
          errorBody.includes("certificate verification") ||
          errorBody.includes("Invalid delegation")) {
        // Canister doesn't exist - silently use fallback
        if (import.meta.env.DEV && import.meta.env.VITE_DEBUG_CANISTERS === "true") {
          logWarn("Rewards canister not deployed. Using fallback stores.", { error: errorMessage })
        }
        setError(null) // Clear error - fallback is intentional
      } else if (errorMessage.includes("contains no Wasm module") ||
                 errorMessage.includes("Wasm module not found") ||
                 errorMessage.includes("IC0537") ||
                 String(error).includes("contains no Wasm module") ||
                 String(error).includes("IC0537")) {
        // Canister not deployed (no Wasm module)
        if (import.meta.env.DEV && import.meta.env.VITE_DEBUG_CANISTERS === "true") {
          logWarn("Rewards canister not deployed. Using fallback stores.", { error: errorMessage })
        }
        setError(null) // Clear error - fallback is intentional
      } else if (errorName === "TrustError" || errorMessage.includes("node signatures") || errorMessage.includes("TrustError")) {
        // Network mismatch
        if (import.meta.env.DEV && import.meta.env.VITE_DEBUG_CANISTERS === "true") {
          logWarn("Network mismatch. Using fallback stores.", { error: errorMessage })
        }
        setError(null)
      } else if (errorMessage.includes("Invalid canister ID") || errorMessage.includes("placeholder") || errorMessage.includes("not found") || errorMessage.includes("canister_not_found")) {
        // Invalid canister ID
        if (import.meta.env.DEV && import.meta.env.VITE_DEBUG_CANISTERS === "true") {
          logWarn("Canister not deployed. Using fallback stores.", { error: errorMessage })
        }
        setError(null) // Clear error - fallback is intentional
      } else {
        // Other errors - log but still use fallback
        logError("Error loading stores", error as Error, { useFallback: true })
        setError("Failed to load stores from canister. Using default data.")
      }
      // Always use fallback stores if canister call fails
      setStores(fallbackStores)
    } finally {
      setIsLoading(false)
    }
  }

  async function trackPurchase(storeId: number, amount: number): Promise<{ success: boolean; reward: number; error?: string }> {
    // Validate in order: connection, amount, storeId (to match test expectations)
    if (!isConnected || !principal) {
      return { success: false, reward: 0, error: "Must be connected to track purchases" }
    }

    if (amount <= 0) {
      return { success: false, reward: 0, error: "Purchase amount must be greater than zero" }
    }

    if (!Number.isInteger(storeId) || storeId <= 0) {
      return { success: false, reward: 0, error: "Invalid store ID" }
    }

    try {
      // Frontend rate limiting (optional but recommended)
      checkRateLimit("rewards", principal.toText())
      
      // trackPurchase is an update method, requires authentication
      // Use retry with longer timeout for update operations
      const canister = await retry(
        () => createRewardsActor(false),
        { maxRetries: 3, initialDelayMs: 500 }
      )
      
      // Convert amount to nat64 (satoshi-like precision: multiply by 1e8)
      const amountNat64 = BigInt(Math.floor(amount * 1e8))
      
      const result = await retryWithTimeout(
        () => canister.trackPurchase(storeId, amountNat64),
        30000, // 30 second timeout for update operations
        { maxRetries: 3, initialDelayMs: 1000 }
      )
      
      // Handle Result variant from canister
      if ("ok" in result && result.ok) {
        const reward = Number(result.ok.rewardEarned) / 1e8 // Convert back from nat64
        return { success: true, reward }
      } else if ("err" in result && result.err) {
        logError("Canister returned error", new Error(result.err), { storeId: String(storeId), amount: String(amount) })
        return { success: false, reward: 0, error: result.err }
      }
      
      return { success: false, reward: 0, error: "Unexpected response from canister" }
    } catch (error) {
      logError("Error tracking purchase", error as Error, { storeId: String(storeId), amount: String(amount) })
      return { success: false, reward: 0, error: (error as Error).message || "Failed to track purchase" }
    }
  }

  return {
    stores,
    isLoading,
    error,
    trackPurchase,
    refetch: loadStores,
  }
}

