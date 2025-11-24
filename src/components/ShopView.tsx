import { ArrowRight } from "lucide-react"
import { useRewards } from "@/hooks/useRewards"
import { useICP } from "@/hooks/useICP"
import { logInfo } from "@/utils/logger"
import type { Store } from "@/types"

function ShopView() {
  const { stores, isLoading } = useRewards()
  const { principal } = useICP()

  function handleShopNow(store: Store) {
    logInfo("User initiated shopping", { storeName: store.name, storeId: store.id })
    
    if (store.url) {
      let finalUrl = store.url
      
      // Append ascsubtag if user is authenticated and it's an Amazon link (or generic logic)
      // The blueprint specifically mentions Amazon but this pattern works for many affiliate programs
      if (principal) {
        const separator = finalUrl.includes("?") ? "&" : "?"
        finalUrl = `${finalUrl}${separator}ascsubtag=${principal.toText()}`
        logInfo("Appended user principal to affiliate link", { principal: principal.toText() })
      } else {
        logInfo("User not authenticated, using generic affiliate link")
      }

      // Open affiliate link in new tab
      window.open(finalUrl, "_blank", "noopener,noreferrer")
    } else {
      // Fallback: log warning if no URL is available
      logInfo("Store URL not available", { storeName: store.name })
    }
    
    // In a real app, this would also call trackPurchase when purchase completes
    // const { trackPurchase } = useRewards()
    // await trackPurchase(store.id, purchaseAmount)
  }

  if (isLoading) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="text-gray-400">Loading stores...</div>
      </div>
    )
  }

  return (
    <div className="animate-fade-in">
      <h1 className="text-4xl font-extrabold text-white mb-4">Shop Stores</h1>
      <h2 className="text-2xl font-light text-yellow-400 mb-8">Earn Bitcoin rewards on every purchase.</h2>

      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        {stores.map((store) => (
          <div
            key={store.id}
            className="bg-gray-800 rounded-xl shadow-lg overflow-hidden transform transition-all duration-300 hover:scale-105 hover:shadow-blue-500/30"
          >
            <div className="h-40 flex items-center justify-center bg-gray-700">
              <img src={store.logo} alt={`${store.name} logo`} className="h-20 w-20 object-contain rounded-full" />
            </div>
            <div className="p-5">
              <h3 className="text-xl font-bold text-white mb-2">{store.name}</h3>
              <p className="text-lg font-semibold text-yellow-400 mb-4">Up to {store.reward}% BTC Back</p>
              <button
                onClick={() => handleShopNow(store)}
                className="w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold flex items-center justify-center gap-2 hover:bg-blue-500 transition-colors"
              >
                Shop Now <ArrowRight className="h-4 w-4" />
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

export default ShopView

