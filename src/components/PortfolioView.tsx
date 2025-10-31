import { usePortfolio } from "@/hooks/usePortfolio"
import { useLending } from "@/hooks/useLending"

function PortfolioView() {
  const { portfolio, isLoading: portfolioLoading } = usePortfolio()
  const { assets: lendingAssets } = useLending()

  function formatCurrency(val: number): string {
    return `$${val.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  if (portfolioLoading || !portfolio) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="text-gray-400">Loading portfolio...</div>
      </div>
    )
  }

  return (
    <div className="animate-fade-in">
      <h1 className="text-4xl font-extrabold text-white mb-8">Your Portfolio</h1>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-gray-800 rounded-xl shadow-lg p-6">
          <h2 className="text-sm font-medium text-gray-400 mb-2">Total Value</h2>
          <p className="text-4xl font-bold text-white">{formatCurrency(portfolio.totalValue)}</p>
        </div>
        <div className="bg-gray-800 rounded-xl shadow-lg p-6">
          <h2 className="text-sm font-medium text-gray-400 mb-2">Total Lended</h2>
          <p className="text-4xl font-bold text-green-400">{formatCurrency(portfolio.totalLended)}</p>
        </div>
        <div className="bg-gray-800 rounded-xl shadow-lg p-6">
          <h2 className="text-sm font-medium text-gray-400 mb-2">Total BTC Rewards</h2>
          <p className="text-4xl font-bold text-yellow-400">
            {portfolio.totalRewards} <span className="text-2xl">BTC</span>
          </p>
        </div>
      </div>

      {/* Asset Breakdown */}
      <div>
        <h2 className="text-2xl font-bold text-white mb-6">Your Assets</h2>
        <div className="bg-gray-800 rounded-xl shadow-lg overflow-hidden">
          <table className="w-full text-left">
            <thead className="bg-gray-700/50">
              <tr>
                <th className="p-4 text-sm font-semibold text-gray-400 uppercase">Asset</th>
                <th className="p-4 text-sm font-semibold text-gray-400 uppercase">Amount</th>
                <th className="p-4 text-sm font-semibold text-gray-400 uppercase">Value (USD)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-700">
              {portfolio.assets.map((asset) => {
                const iconUrl = lendingAssets.find((a) => a.symbol === asset.symbol)?.icon
                return (
                  <tr key={asset.symbol}>
                    <td className="p-4 flex items-center gap-3">
                      <img
                        src={iconUrl || "https://placehold.co/32x32/1e293b/ffffff?text=?"}
                        alt=""
                        className="h-8 w-8 rounded-full"
                      />
                      <div>
                        <span className="font-medium text-white">{asset.name}</span>
                        <span className="block text-xs text-gray-400">{asset.symbol}</span>
                      </div>
                    </td>
                    <td className="p-4 font-medium text-white">{asset.amount}</td>
                    <td className="p-4 font-medium text-white">{formatCurrency(asset.value)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

export default PortfolioView

