import { useState } from "react"
import { Lock } from "lucide-react"
import { useLending } from "@/hooks/useLending"
import { useICP } from "@/hooks/useICP"
import { logError } from "@/utils/logger"

function BorrowView() {
  const { assets, deposits, borrows, availableLiquidity, isLoading, borrow, repay } = useLending()
  const { isConnected } = useICP()
  const [borrowAmount, setBorrowAmount] = useState<Record<string, string>>({})
  const [collateralAmount, setCollateralAmount] = useState<Record<string, string>>({})
  const [collateralAsset, setCollateralAsset] = useState<Record<string, string>>({})
  const [repayAmount, setRepayAmount] = useState<Record<string, string>>({})
  const [isProcessing, setIsProcessing] = useState<string | null>(null)
  const [isRepaying, setIsRepaying] = useState<bigint | null>(null)

  function handleBorrowAmountChange(assetId: string, amount: string) {
    setBorrowAmount((prev) => ({ ...prev, [assetId]: amount }))
  }

  function handleCollateralAmountChange(assetId: string, amount: string) {
    setCollateralAmount((prev) => ({ ...prev, [assetId]: amount }))
  }

  function handleCollateralAssetChange(assetId: string, asset: string) {
    setCollateralAsset((prev) => ({ ...prev, [assetId]: asset }))
  }

  function handleRepayAmountChange(borrowId: bigint, amount: string) {
    setRepayAmount((prev) => ({ ...prev, [borrowId.toString()]: amount }))
  }

  async function handleBorrow(asset: { id: string; symbol: string }) {
    const amount = borrowAmount[asset.id]
    const collateral = collateralAmount[asset.id]
    const collateralAssetSymbol = collateralAsset[asset.id] || asset.symbol

    if (!amount || parseFloat(amount) <= 0) {
      logError("Invalid amount", new Error(`Amount must be greater than 0, got ${amount}`))
      return
    }

    if (!collateral || parseFloat(collateral) <= 0) {
      logError("Invalid collateral amount", new Error(`Collateral amount must be greater than 0, got ${collateral}`))
      return
    }

    setIsProcessing(asset.id)
    try {
      const success = await borrow(
        asset.symbol,
        parseFloat(amount),
        collateralAssetSymbol,
        parseFloat(collateral)
      )
      if (success) {
        setBorrowAmount((prev) => ({ ...prev, [asset.id]: "" }))
        setCollateralAmount((prev) => ({ ...prev, [asset.id]: "" }))
      }
    } catch (error) {
      logError("Error borrowing", error as Error, { asset: asset.symbol, amount })
    } finally {
      setIsProcessing(null)
    }
  }

  async function handleRepay(borrowId: bigint) {
    const amount = repayAmount[borrowId.toString()]
    if (!amount || parseFloat(amount) <= 0) {
      logError("Invalid amount", new Error(`Amount must be greater than 0, got ${amount}`))
      return
    }

    setIsRepaying(borrowId)
    try {
      const success = await repay(borrowId, parseFloat(amount))
      if (success) {
        setRepayAmount((prev) => ({ ...prev, [borrowId.toString()]: "" }))
      }
    } catch (error) {
      logError("Error repaying", error as Error, { borrowId })
    } finally {
      setIsRepaying(null)
    }
  }

  function getAvailableCollateral(assetSymbol: string): number {
    const deposit = deposits.find((d) => d.asset === assetSymbol.toUpperCase())
    return deposit ? deposit.amount : 0
  }

  function calculateBorrowAPY(asset: { apy: number }): number {
    // Borrowing rate is 1.5x the lending APY
    return asset.apy * 1.5
  }

  if (isLoading) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="text-gray-400">Loading borrowing assets...</div>
      </div>
    )
  }

  if (!isConnected) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="bg-gray-800 rounded-xl shadow-lg p-8 max-w-md text-center">
          <div className="flex justify-center mb-4">
            <div className="bg-red-500/20 p-4 rounded-full">
              <Lock className="h-12 w-12 text-red-400" />
            </div>
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">Connect Your Wallet</h2>
          <p className="text-gray-400 mb-4">
            Please connect your Internet Identity or Bitcoin wallet to borrow against your collateral.
          </p>
          <p className="text-sm text-gray-500">
            Use the connection buttons in the header to sign in.
          </p>
        </div>
      </div>
    )
  }

  const totalBorrowed = borrows.reduce((sum, b) => {
    const asset = assets.find((a) => a.symbol === b.asset.toUpperCase())
    // Mock value calculation - in real app would use actual prices
    const mockPrice = asset?.symbol === "BTC" ? 60000 : asset?.symbol === "ETH" ? 3000 : 45
    return sum + Number(b.borrowedAmount) / 1e8 * mockPrice
  }, 0)

  return (
    <div className="animate-fade-in grid grid-cols-1 lg:grid-cols-3 gap-8">
      {/* Borrowing Column */}
      <div className="lg:col-span-2">
        <h1 className="text-4xl font-extrabold text-white mb-4">Borrow Against Collateral</h1>
        <h2 className="text-2xl font-light text-gray-300 mb-8">Use your deposits as collateral to borrow.</h2>

        <div className="space-y-6">
          {assets.map((asset) => {
            const available = availableLiquidity[asset.id] || 0
            const borrowAPY = calculateBorrowAPY(asset)
            
            return (
              <div
                key={asset.id}
                className="bg-gray-800 rounded-xl shadow-lg p-6 flex flex-col gap-4"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <img src={asset.icon} alt={`${asset.name} icon`} className="h-12 w-12 rounded-full" />
                    <div>
                      <h3 className="text-2xl font-bold text-white">{asset.name}</h3>
                      <p className="text-sm text-gray-400">{asset.symbol}</p>
                    </div>
                  </div>
                  <div className="text-center">
                    <span className="text-xs text-gray-400">Borrow APY</span>
                    <p className="text-3xl font-bold text-red-400">{borrowAPY.toFixed(1)}%</p>
                  </div>
                  <div className="text-center">
                    <span className="text-xs text-gray-400">Available</span>
                    <p className="text-lg font-semibold text-gray-300">{available.toFixed(4)} {asset.symbol}</p>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Collateral Asset</label>
                    <select
                      value={collateralAsset[asset.id] || asset.symbol}
                      onChange={(e) => handleCollateralAssetChange(asset.id, e.target.value)}
                      className="bg-gray-700 text-white px-4 py-3 rounded-lg border border-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full"
                      disabled={isProcessing === asset.id}
                    >
                      {assets.map((a) => (
                        <option key={a.id} value={a.symbol}>
                          {a.symbol}
                        </option>
                      ))}
                    </select>
                    <p className="text-xs text-gray-500 mt-1">
                      Available: {getAvailableCollateral(collateralAsset[asset.id] || asset.symbol).toFixed(4)}
                    </p>
                  </div>

                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Collateral Amount</label>
                    <input
                      type="number"
                      placeholder="Amount"
                      value={collateralAmount[asset.id] || ""}
                      onChange={(e) => handleCollateralAmountChange(asset.id, e.target.value)}
                      className="bg-gray-700 text-white px-4 py-3 rounded-lg border border-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full"
                      disabled={isProcessing === asset.id}
                    />
                  </div>

                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Borrow Amount ({asset.symbol})</label>
                    <input
                      type="number"
                      placeholder="Amount"
                      value={borrowAmount[asset.id] || ""}
                      onChange={(e) => handleBorrowAmountChange(asset.id, e.target.value)}
                      className="bg-gray-700 text-white px-4 py-3 rounded-lg border border-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full"
                      disabled={isProcessing === asset.id}
                    />
                    <p className="text-xs text-gray-500 mt-1">Max LTV: 75%</p>
                  </div>
                </div>

                <button
                  onClick={() => handleBorrow(asset)}
                  disabled={isProcessing === asset.id || available === 0}
                  className="bg-red-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-red-500 transition-colors w-full disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isProcessing === asset.id ? "Processing..." : "Borrow"}
                </button>
              </div>
            )
          })}
        </div>

        {/* Active Borrows Section */}
        {borrows.length > 0 && (
          <div className="mt-8">
            <h2 className="text-2xl font-bold text-white mb-4">Your Active Borrows</h2>
            <div className="space-y-4">
              {borrows.map((borrow) => {
                const borrowedAmount = Number(borrow.borrowedAmount) / 1e8
                
                return (
                  <div
                    key={borrow.id.toString()}
                    className="bg-gray-800 rounded-xl shadow-lg p-6"
                  >
                    <div className="flex items-center justify-between mb-4">
                      <div>
                        <h3 className="text-xl font-bold text-white">
                          {borrow.asset} Borrow
                        </h3>
                        <p className="text-sm text-gray-400">
                          Collateral: {Number(borrow.collateralAmount) / 1e8} {borrow.collateralAsset}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-2xl font-bold text-white">{borrowedAmount.toFixed(4)} {borrow.asset}</p>
                        <p className="text-sm text-gray-400">LTV: {(borrow.ltv * 100).toFixed(2)}%</p>
                        <p className="text-sm text-red-400">APY: {borrow.interestRate.toFixed(1)}%</p>
                      </div>
                    </div>

                    <div className="flex gap-4">
                      <input
                        type="number"
                        placeholder="Repay amount"
                        value={repayAmount[borrow.id.toString()] || ""}
                        onChange={(e) => handleRepayAmountChange(borrow.id, e.target.value)}
                        className="bg-gray-700 text-white px-4 py-3 rounded-lg border border-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 flex-1"
                        disabled={isRepaying === borrow.id}
                        max={borrowedAmount}
                      />
                      <button
                        onClick={() => handleRepay(borrow.id)}
                        disabled={isRepaying === borrow.id}
                        className="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        {isRepaying === borrow.id ? "Processing..." : "Repay"}
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )}
      </div>

      {/* Summary Column */}
      <div className="lg:col-span-1">
        <div className="bg-gray-800 rounded-xl shadow-lg p-6 sticky top-28">
          <h2 className="text-2xl font-bold text-white mb-6">Borrowing Summary</h2>
          <div className="space-y-4">
            {borrows.map((borrow) => {
              const borrowedAmount = Number(borrow.borrowedAmount) / 1e8
              return (
                <div key={borrow.id.toString()} className="flex justify-between items-center">
                  <span className="text-gray-400 text-lg">
                    {borrow.asset}
                  </span>
                  <span className="text-white font-semibold text-lg">
                    {borrowedAmount.toFixed(4)}
                  </span>
                </div>
              )
            })}
            {borrows.length === 0 && (
              <div className="text-gray-500 text-sm">No active borrows</div>
            )}
            <div className="border-t border-gray-600 my-4"></div>
            <div className="flex justify-between items-center">
              <span className="text-gray-300 text-xl">Total Borrowed</span>
              <span className="text-red-400 font-bold text-xl">
                ${totalBorrowed.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </span>
            </div>
          </div>
          <div className="mt-6 p-4 bg-yellow-900/20 border border-yellow-700 rounded-lg">
            <p className="text-xs text-yellow-400">
              ⚠️ Remember: You must maintain sufficient collateral. If your LTV exceeds 85%, your position may be liquidated.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default BorrowView

