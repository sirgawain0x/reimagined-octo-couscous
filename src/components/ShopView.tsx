import { ArrowRight } from "lucide-react"
import { useRewards } from "@/hooks/useRewards"
import { logInfo } from "@/utils/logger"

function ShopView() {
  const { stores, isLoading } = useRewards()

  function handleShopNow(storeName: string) {
    logInfo("User initiated shopping", { storeName })
    // In a real app, this would open a tracked link and call trackPurchase when purchase completes
    // const { trackPurchase } = useRewards()
    // await trackPurchase(storeId, purchaseAmount)
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
                onClick={() => handleShopNow(store.name)}
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

