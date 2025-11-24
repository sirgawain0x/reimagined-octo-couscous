import { Lock } from "lucide-react"
import { usePortfolio } from "@/hooks/usePortfolio"
import { useLending } from "@/hooks/useLending"
import { useICP } from "@/hooks/useICP"
import { useTokenBalances } from "@/hooks/useTokenBalances"

function PortfolioView() {
  const { portfolio, isLoading: portfolioLoading } = usePortfolio()
  const { assets: lendingAssets } = useLending()
  const { isConnected } = useICP()
  const { ckBTC, ckETH, ICP, SOL, isLoading: balancesLoading } = useTokenBalances()

  function formatCurrency(val: number): string {
    return `$${val.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  function formatBalance(amount: bigint | null, decimals: number = 8): string {
    if (amount === null) return "0.00"
    const divisor = BigInt(10 ** decimals)
    const whole = amount / divisor
    const fractional = amount % divisor
    const fractionalStr = fractional.toString().padStart(decimals, "0").slice(0, 4)
    return `${whole}.${fractionalStr}`
  }

  // Get all token balances (from swap canister)
  const tokenBalances = [
    { name: "Chain-Key Bitcoin", symbol: "ckBTC", amount: formatBalance(ckBTC, 8), balance: ckBTC },
    { name: "Chain-Key Ethereum", symbol: "ckETH", amount: formatBalance(ckETH, 18), balance: ckETH },
    { name: "Internet Computer", symbol: "ICP", amount: formatBalance(ICP, 8), balance: ICP },
    { name: "Solana", symbol: "SOL", amount: formatBalance(SOL, 9), balance: SOL },
  ].filter(token => token.balance !== null && token.balance > 0n)

  if (portfolioLoading) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="text-gray-400">Loading portfolio...</div>
      </div>
    )
  }

  if (!isConnected) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="bg-gray-800 rounded-xl shadow-lg p-8 max-w-md text-center">
          <div className="flex justify-center mb-4">
            <div className="bg-blue-500/20 p-4 rounded-full">
              <Lock className="h-12 w-12 text-blue-400" />
            </div>
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">Connect Your Wallet</h2>
          <p className="text-gray-400 mb-4">
            Please connect your Internet Identity or Bitcoin wallet to view your portfolio and track your assets.
          </p>
          <p className="text-sm text-gray-500">
            Use the connection buttons in the header to sign in.
          </p>
        </div>
      </div>
    )
  }

  if (!portfolio) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="text-gray-400">No portfolio data available</div>
      </div>
    )
  }

  return (
    <div className="animate-fade-in">
      <h1 className="text-4xl font-extrabold text-white mb-8">Your Portfolio</h1>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div className="bg-gray-800 rounded-xl shadow-lg p-6">
          <h2 className="text-sm font-medium text-gray-400 mb-2">Total Value</h2>
          <p className="text-4xl font-bold text-white">{formatCurrency(portfolio.totalValue)}</p>
        </div>
        <div className="bg-gray-800 rounded-xl shadow-lg p-6">
          <h2 className="text-sm font-medium text-gray-400 mb-2">Total Lended</h2>
          <p className="text-4xl font-bold text-green-400">{formatCurrency(portfolio.totalLended)}</p>
        </div>
        <div className="bg-gray-800 rounded-xl shadow-lg p-6">
          <h2 className="text-sm font-medium text-gray-400 mb-2">Total Borrowed</h2>
          <p className="text-4xl font-bold text-red-400">{formatCurrency(portfolio.totalBorrowed)}</p>
        </div>
        <div className="bg-gray-800 rounded-xl shadow-lg p-6">
          <h2 className="text-sm font-medium text-gray-400 mb-2">Total BTC Rewards</h2>
          <p className="text-4xl font-bold text-yellow-400">
            {portfolio.totalRewards} <span className="text-2xl">BTC</span>
          </p>
        </div>
      </div>

      {/* Token Balances from Swap Canister */}
      {tokenBalances.length > 0 && (
        <div className="mb-8">
          <h2 className="text-2xl font-bold text-white mb-6">Token Balances</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {tokenBalances.map((token) => {
              const iconUrl = lendingAssets.find((a) => a.symbol === token.symbol)?.icon
              return (
                <div key={token.symbol} className="bg-gray-800 rounded-xl shadow-lg p-4">
                  <div className="flex items-center gap-3 mb-2">
                    <img
                      src={iconUrl || "https://placehold.co/32x32/1e293b/ffffff?text=?"}
                      alt=""
                      className="h-8 w-8 rounded-full"
                    />
                    <div>
                      <span className="font-medium text-white text-sm">{token.name}</span>
                      <span className="block text-xs text-gray-400">{token.symbol}</span>
                    </div>
                  </div>
                  <p className="text-2xl font-bold text-white">
                    {balancesLoading ? "..." : token.amount}
                  </p>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Asset Breakdown (from Lending Canister) */}
      <div>
        <h2 className="text-2xl font-bold text-white mb-6">Lending Assets</h2>
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
              {portfolio.assets.length > 0 ? (
                portfolio.assets.map((asset) => {
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
                })
              ) : (
                <tr>
                  <td colSpan={3} className="p-4 text-center text-gray-400">
                    No lending assets found
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

export default PortfolioView

