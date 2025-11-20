import { useState } from "react"
import { ArrowDownUp, ArrowRight, Info } from "lucide-react"
import { useSwap } from "@/hooks/useSwap"
import { SolanaInfo } from "@/components/SolanaInfo"
import { logError } from "@/utils/logger"

const TOKENS = [
  { symbol: "ckBTC", name: "Chain-Key Bitcoin", decimals: 8, icon: "₿" },
  { symbol: "ICP", name: "Internet Computer", decimals: 8, icon: "∞" },
  { symbol: "ckETH", name: "Chain-Key Ethereum", decimals: 18, icon: "Ξ" },
  { symbol: "SOL", name: "Solana", decimals: 9, icon: "◎" },
]

export default function SwapView() {
  const { pools, quote, isLoading, getQuote, executeSwap } = useSwap()
  const [fromToken, setFromToken] = useState("ckBTC")
  const [toToken, setToToken] = useState("ICP")
  const [fromAmount, setFromAmount] = useState("")
  const [isSwapping, setIsSwapping] = useState(false)
  const [selectedPool, setSelectedPool] = useState("ckBTC_ICP")

  function handleSwapTokens() {
    const temp = fromToken
    setFromToken(toToken)
    setToToken(temp)
    setFromAmount("")
  }

  async function handleAmountChange(amount: string) {
    setFromAmount(amount)
    
    if (amount && parseFloat(amount) > 0) {
      const fromTokenInfo = TOKENS.find((t) => t.symbol === fromToken)
      const decimals = fromTokenInfo?.decimals || 8
      const multiplier = BigInt(10 ** decimals)
      const amountBigInt = BigInt(Math.floor(parseFloat(amount) * Number(multiplier)))
      await getQuote(selectedPool, amountBigInt)
    } else {
      // setQuote(null)
    }
  }

  async function handleExecuteSwap() {
    if (!fromAmount || !quote) return

    setIsSwapping(true)
    try {
      const fromTokenInfo = TOKENS.find((t) => t.symbol === fromToken)
      const decimals = fromTokenInfo?.decimals || 8
      const multiplier = BigInt(10 ** decimals)
      const amountIn = BigInt(Math.floor(parseFloat(fromAmount) * Number(multiplier)))
      const minAmountOut = BigInt(Math.floor(Number(quote.amountOut) * 0.95)) // 5% slippage

      const result = await executeSwap(
        selectedPool,
        fromToken as any,
        amountIn,
        minAmountOut
      )

      if (result.success) {
        setFromAmount("")
        // Show success message
      }
    } catch (error) {
      logError("Swap failed", error as Error, { poolId: selectedPool, fromToken, amount: fromAmount })
    } finally {
      setIsSwapping(false)
    }
  }

  const fromTokenInfo = TOKENS.find((t) => t.symbol === fromToken)
  const toTokenInfo = TOKENS.find((t) => t.symbol === toToken)

  // Calculate output amount using correct decimals for the destination token
  const toTokenDecimals = toTokenInfo?.decimals || 8
  const outputAmount = quote ? Number(quote.amountOut) / (10 ** toTokenDecimals) : 0

  if (isLoading) {
    return (
      <div className="animate-fade-in flex items-center justify-center min-h-[400px]">
        <div className="text-gray-400">Loading swap pools...</div>
      </div>
    )
  }

  return (
    <div className="animate-fade-in max-w-2xl mx-auto">
      <h1 className="text-4xl font-extrabold text-white mb-4">Swap Tokens</h1>
      <h2 className="text-2xl font-light text-gray-300 mb-8">
        Trade ckBTC, ckETH, SOL, and ICP instantly
      </h2>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 lg:items-start">
        {/* Swap Form */}
        <div className="lg:col-span-2">
          <div className="bg-gray-800 rounded-xl shadow-lg p-6 space-y-4">
            {/* From Token */}
            <div>
              <label className="text-sm text-gray-400 mb-2 block">From</label>
              <div className="flex gap-2">
                <select
                  value={fromToken}
                  onChange={(e) => setFromToken(e.target.value)}
                  className="bg-gray-700 text-white px-4 py-3 rounded-lg border border-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
                >
                  {TOKENS.map((t) => (
                    <option key={t.symbol} value={t.symbol}>
                      {t.symbol}
                    </option>
                  ))}
                </select>
                <div className="flex-1 bg-gray-700 rounded-lg border border-gray-600 px-4 py-3 text-white focus-within:ring-2 focus-within:ring-blue-500">
                  <input
                    type="text"
                    placeholder="0.00"
                    value={fromAmount}
                    onChange={(e) => handleAmountChange(e.target.value)}
                    className="bg-transparent w-full outline-none text-right text-lg"
                  />
                </div>
              </div>
              {fromTokenInfo && (
                <p className="text-xs text-gray-500 mt-1 text-right">
                  {fromTokenInfo.name}
                </p>
              )}
            </div>

            {/* Swap Arrow */}
            <div className="flex justify-center -my-2">
              <button
                onClick={handleSwapTokens}
                className="bg-gray-700 hover:bg-gray-600 p-3 rounded-full transition-colors border-4 border-gray-900"
              >
                <ArrowDownUp className="h-5 w-5 text-white" />
              </button>
            </div>

            {/* To Token */}
            <div>
              <label className="text-sm text-gray-400 mb-2 block">To</label>
              <div className="flex gap-2">
                <select
                  value={toToken}
                  onChange={(e) => setToToken(e.target.value)}
                  className="bg-gray-700 text-white px-4 py-3 rounded-lg border border-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
                >
                  {TOKENS.filter((t) => t.symbol !== fromToken).map((t) => (
                    <option key={t.symbol} value={t.symbol}>
                      {t.symbol}
                    </option>
                  ))}
                </select>
                <div className="flex-1 bg-gray-700 rounded-lg border border-gray-600 px-4 py-3 text-white">
                  <div className="text-right text-lg">
                    {outputAmount.toFixed(toTokenInfo?.decimals || 8)}
                  </div>
                </div>
              </div>
              {toTokenInfo && (
                <p className="text-xs text-gray-500 mt-1 text-right">
                  {toTokenInfo.name}
                </p>
              )}
            </div>

            {/* Quote Details */}
            {quote && (
              <div className="bg-gray-700/50 rounded-lg p-4 space-y-2 text-sm">
                <div className="flex justify-between text-gray-300">
                  <span>Price Impact</span>
                  <span className={quote.priceImpact > 1 ? "text-yellow-400" : "text-green-400"}>
                    {quote.priceImpact.toFixed(2)}%
                  </span>
                </div>
                <div className="flex justify-between text-gray-300">
                  <span>Fee (0.3%)</span>
                  <span>{(Number(quote.fee) / (10 ** (toTokenInfo?.decimals || 8))).toFixed(8)}</span>
                </div>
                <div className="flex items-center gap-2 text-xs text-gray-400 pt-2 border-t border-gray-600">
                  <Info className="h-4 w-4" />
                  <span>Minimum output with 5% slippage tolerance</span>
                </div>
              </div>
            )}

            {/* Swap Button */}
            <button
              onClick={handleExecuteSwap}
              disabled={isSwapping || !fromAmount || !quote}
              className="w-full bg-blue-600 text-white py-4 rounded-lg font-semibold hover:bg-blue-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {isSwapping ? (
                <>
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                  Swapping...
                </>
              ) : (
                <>
                  <ArrowRight className="h-5 w-5" />
                  Swap
                </>
              )}
            </button>
          </div>

          {/* Pool Selection */}
          <div className="mt-4 bg-gray-800 rounded-xl shadow-lg p-4">
            <h3 className="text-sm font-semibold text-gray-300 mb-2">Available Pools</h3>
            <div className="space-y-2">
              {pools.map((pool) => (
                <button
                  key={pool.id}
                  onClick={() => setSelectedPool(pool.id)}
                  className={`w-full text-left p-3 rounded-lg border transition-colors ${
                    selectedPool === pool.id
                      ? "bg-blue-600 border-blue-500 text-white"
                      : "bg-gray-700 border-gray-600 text-gray-300 hover:bg-gray-600"
                  }`}
                >
                  <div className="flex justify-between items-center">
                    <span className="font-semibold">
                      {pool.tokenA} / {pool.tokenB}
                    </span>
                    <span className="text-xs">
                      ${pool.liquidity.toLocaleString()} liquidity
                    </span>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Info Panel */}
        <div className="lg:col-span-1 space-y-6">
          <div className="bg-gray-800 rounded-xl shadow-lg p-6">
            <h2 className="text-xl font-bold text-white mb-4">Swap Info</h2>
            
            <div className="space-y-4 text-sm">
              <div>
                <h3 className="text-gray-400 mb-2">How it works</h3>
                <ul className="space-y-1 text-gray-300">
                  <li>• Chain-Key tokens (ckBTC, ckETH) are 1:1 on ICP</li>
                  <li>• SOL is native Solana via SOL RPC canister</li>
                  <li>• Direct swaps via automated market maker (AMM)</li>
                  <li>• No bridges or custodians required</li>
                </ul>
              </div>

              <div className="border-t border-gray-700 pt-4">
                <h3 className="text-gray-400 mb-2">Key Benefits</h3>
                <ul className="space-y-1 text-gray-300">
                  <li>✓ Fast transactions</li>
                  <li>✓ Low fees (0.3%)</li>
                  <li>✓ Non-custodial</li>
                  <li>✓ Secure execution</li>
                </ul>
              </div>

              <div className="border-t border-gray-700 pt-4">
                <h3 className="text-gray-400 mb-2">Price Impact</h3>
                <p className="text-xs text-gray-300 leading-relaxed">
                  Large swaps may affect the pool price. Always check the impact before confirming.
                </p>
              </div>
            </div>
          </div>

          {/* Solana Info Panel */}
          <SolanaInfo />
        </div>
      </div>
    </div>
  )
}

