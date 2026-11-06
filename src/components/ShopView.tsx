import { ArrowRight } from "lucide-react"
import { storefront } from "@/config/storefront"

function ShopView() {
  return (
    <div className="animate-fade-in">
      <h1 className="text-4xl font-extrabold text-white mb-4">Shop Stores</h1>
      <h2 className="text-2xl font-light text-yellow-400 mb-8">We may earn a commission from these links. Shopper rewards are paused.</h2>

      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        {storefront.map((store) => (
          <div
            key={store.name}
            className="bg-gray-800 rounded-xl shadow-lg overflow-hidden transform transition-all duration-300 hover:scale-105 hover:shadow-blue-500/30"
          >
            <div className="p-5">
              <h3 className="text-xl font-bold text-white mb-2">{store.name}</h3>
              <a
                href={store.url}
                target="_blank"
                rel="sponsored noopener noreferrer"
                className="w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold flex items-center justify-center gap-2 hover:bg-blue-500 transition-colors"
              >
                Shop Now <ArrowRight className="h-4 w-4" />
              </a>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

export default ShopView

