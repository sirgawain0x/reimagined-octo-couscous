import { useState } from "react"
import { Lock } from "lucide-react"
import { useLending } from "@/hooks/useLending"
import { useICP } from "@/hooks/useICP"
import { logError } from "@/utils/logger"

function LendView() {
  const { assets, deposits, isLoading, deposit } = useLending()
  const { isConnected } = useICP()
  const [lendAmount, setLendAmount] = useState<Record<string, string>>({})
  const [isProcessing, setIsProcessing] = useState<string | null>(null)

  function handleAmountChange(assetId: string, amount: string) {
    setLendAmount((prev) => ({ ...prev, [assetId]: amount }))
  }

  async function handleLend(asset: { id: string; symbol: string }) {
    const amount = lendAmount[asset.id]
    if (!amount || parseFloat(amount) <= 0) {
      logError("Invalid amount", new Error(`Amount must be greater than 0, got ${amount}`))
      return
    }

    setIsProcessing(asset.id)
    try {
      const success = await deposit(asset.symbol, parseFloat(amount))
      if (success) {
        setLendAmount((prev) => ({ ...prev, [asset.id]: "" }))
      }
    } catch (error) {
      logError("Error lending", error as Error, { asset: asset.symbol, amount })
    } finally {
      setIsProcessing(null)
    }
  }

  if (isLoading) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="text-gray-400">Loading lending assets...</div>
      </div>
    )
  }

  if (!isConnected) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="bg-gray-800 rounded-xl shadow-lg p-8 max-w-md text-center">
          <div className="flex justify-center mb-4">
            <div className="bg-yellow-500/20 p-4 rounded-full">
              <Lock className="h-12 w-12 text-yellow-400" />
            </div>
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">Connect Your Wallet</h2>
          <p className="text-gray-400 mb-4">
            Please connect your Internet Identity or Bitcoin wallet to start lending and earning interest.
          </p>
          <p className="text-sm text-gray-500">
            Use the connection buttons in the header to sign in.
          </p>
        </div>
      </div>
    )
  }

  const totalLended = deposits.reduce((sum, d) => {
    const asset = assets.find((a) => a.symbol === d.asset)
    // Mock value calculation - in real app would use actual prices
    const mockPrice = asset?.symbol === "BTC" ? 60000 : asset?.symbol === "ETH" ? 3000 : 45
    return sum + d.amount * mockPrice
  }, 0)

  return (
    <div className="animate-fade-in grid grid-cols-1 lg:grid-cols-3 gap-8">
      {/* Lending Column */}
      <div className="lg:col-span-2">
        <h1 className="text-4xl font-extrabold text-white mb-4">Lend & Earn Interest</h1>
        <h2 className="text-2xl font-light text-gray-300 mb-8">Put your crypto to work.</h2>

        <div className="space-y-6">
          {assets.map((asset) => (
            <div
              key={asset.id}
              className="bg-gray-800 rounded-xl shadow-lg p-6 flex flex-col sm:flex-row items-center justify-between gap-4"
            >
              <div className="flex items-center gap-4">
                <img src={asset.icon} alt={`${asset.name} icon`} className="h-12 w-12 rounded-full" />
                <div>
                  <h3 className="text-2xl font-bold text-white">{asset.name}</h3>
                  <p className="text-sm text-gray-400">{asset.symbol}</p>
                </div>
              </div>
              <div className="text-center sm:text-left">
                <span className="text-xs text-gray-400">Current APY</span>
                <p className="text-3xl font-bold text-green-400">{asset.apy}%</p>
              </div>
              <div className="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
                <input
                  type="number"
                  placeholder={`Amount ${asset.symbol}`}
                  value={lendAmount[asset.id] || ""}
                  onChange={(e) => handleAmountChange(asset.id, e.target.value)}
                  className="bg-gray-700 text-white px-4 py-3 rounded-lg border border-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full sm:w-40"
                  disabled={isProcessing === asset.id}
                />
                <button
                  onClick={() => handleLend(asset)}
                  disabled={isProcessing === asset.id}
                  className="bg-green-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-green-500 transition-colors w-full sm:w-auto disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isProcessing === asset.id ? "Processing..." : "Lend"}
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Summary Column */}
      <div className="lg:col-span-1">
        <div className="bg-gray-800 rounded-xl shadow-lg p-6 sticky top-28">
          <h2 className="text-2xl font-bold text-white mb-6">Your Deposits</h2>
          <div className="space-y-4">
            {deposits.map((deposit) => (
              <div key={deposit.asset} className="flex justify-between items-center">
                <span className="text-gray-400 text-lg">
                  Lending ({deposit.asset})
                </span>
                <span className="text-white font-semibold text-lg">
                  {deposit.amount} {deposit.asset}
                </span>
              </div>
            ))}
            {deposits.length === 0 && (
              <div className="text-gray-500 text-sm">No deposits yet</div>
            )}
            <div className="border-t border-gray-600 my-4"></div>
            <div className="flex justify-between items-center">
              <span className="text-gray-300 text-xl">Total Lended</span>
              <span className="text-green-400 font-bold text-xl">
                ${totalLended.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </span>
            </div>
          </div>
          <button className="mt-6 w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-500 transition-colors">
            Manage Deposits
          </button>
        </div>
      </div>
    </div>
  )
}

export default LendView

