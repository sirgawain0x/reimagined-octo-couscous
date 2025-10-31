import { useState, useEffect, useCallback } from "react"
import type { Store } from "@/types"
import { createRewardsActor, requireAuth } from "@/services/canisters"
import { logError, logWarn } from "@/utils/logger"
import { Principal } from "@dfinity/principal"
import { useICP } from "./useICP"

// Fallback stores if canister is not available
const fallbackStores: Store[] = [
  { id: 1, name: "Amazon", reward: 5, logo: "https://placehold.co/100x100/1e293b/ffffff?text=AMZN" },
  { id: 2, name: "Walmart", reward: 3.5, logo: "https://placehold.co/100x100/1e293b/ffffff?text=WMT" },
  { id: 3, name: "Nike", reward: 8, logo: "https://placehold.co/100x100/1e293b/ffffff?text=NIKE" },
  { id: 4, name: "eBay", reward: 2, logo: "https://placehold.co/100x100/1e293b/ffffff?text=EBAY" },
]

export function useRewards() {
  const [stores, setStores] = useState<Store[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const { principal, isConnected } = useICP()

  useEffect(() => {
    loadStores()
  }, [])

  async function loadStores() {
    setIsLoading(true)
    setError(null)
    
    try {
      const canister = await createRewardsActor()
      const canisterStores = await canister.getStores()
      
      // Convert canister store format to frontend format
      const formattedStores: Store[] = canisterStores.map((store) => ({
        id: store.id,
        name: store.name,
        reward: store.reward,
        logo: store.logo || `https://placehold.co/100x100/1e293b/ffffff?text=${store.name.substring(0, 4).toUpperCase()}`,
        url: store.url || undefined,
      }))
      
      setStores(formattedStores.length > 0 ? formattedStores : fallbackStores)
    } catch (error) {
      logError("Error loading stores", error as Error, { useFallback: true })
      // Use fallback stores if canister call fails
      setStores(fallbackStores)
      setError("Failed to load stores from canister. Using default data.")
    } finally {
      setIsLoading(false)
    }
  }

  async function trackPurchase(storeId: number, amount: number): Promise<{ success: boolean; reward: number; error?: string }> {
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
      const canister = await createRewardsActor()
      
      // Convert amount to nat64 (satoshi-like precision: multiply by 1e8)
      const amountNat64 = BigInt(Math.floor(amount * 1e8))
      
      const result = await canister.trackPurchase(storeId, amountNat64)
      
      // Handle Result variant from canister
      if ("ok" in result) {
        const reward = Number(result.ok.rewardEarned) / 1e8 // Convert back from nat64
        return { success: true, reward }
      } else if ("err" in result) {
        logError("Canister returned error", new Error(result.err), { storeId, amount })
        return { success: false, reward: 0, error: result.err }
      }
      
      return { success: false, reward: 0, error: "Unexpected response from canister" }
    } catch (error) {
      logError("Error tracking purchase", error as Error, { storeId, amount })
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

