import { useState, useEffect } from "react"
import { Copy, RefreshCw, ExternalLink, Wallet, Info } from "lucide-react"
import { useSolana } from "@/hooks/useSolana"
import { useICP } from "@/hooks/useICP"
import { logError } from "@/utils/logger"

export function SolanaInfo() {
  const { address, balance, isLoading, error, getBalance, getRecentBlockhash, getSlot } = useSolana()
  const { isConnected } = useICP()
  const [blockhash, setBlockhash] = useState<string | null>(null)
  const [slot, setSlot] = useState<bigint | null>(null)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    loadBlockchainInfo()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function loadBlockchainInfo() {
    setIsRefreshing(true)
    try {
      const [hash, currentSlot] = await Promise.all([
        getRecentBlockhash(),
        getSlot()
      ])
      setBlockhash(hash)
      setSlot(currentSlot)
    } catch (error) {
      logError("Error loading blockchain info", error as Error)
    } finally {
      setIsRefreshing(false)
    }
  }

  async function handleRefresh() {
    await Promise.all([
      loadBlockchainInfo(),
      address ? getBalance() : Promise.resolve()
    ])
  }

  async function handleCopyAddress() {
    if (!address) return
    
    try {
      await navigator.clipboard.writeText(address)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (error) {
      logError("Failed to copy address", error as Error)
    }
  }

  function formatBalance(lamports: bigint | null): string {
    if (lamports === null) return "0.00"
    const sol = Number(lamports) / 1e9
    return sol.toFixed(4)
  }

  function truncateAddress(addr: string | null): string {
    if (!addr) return "Not available"
    if (addr.length <= 12) return addr
    return `${addr.slice(0, 6)}...${addr.slice(-6)}`
  }

  function truncateBlockhash(hash: string | null): string {
    if (!hash) return "Not available"
    if (hash.length <= 16) return hash
    return `${hash.slice(0, 8)}...${hash.slice(-8)}`
  }

  // Filter out technical Candid errors that users won't understand
  function shouldShowError(errorMessage: string | null): boolean {
    if (!errorMessage) return false
    
    const technicalErrors = [
      "Invalid opt text argument",
      "Invalid opt",
      "Candid decode error",
      "Type mismatch"
    ]
    
    return !technicalErrors.some(techError => 
      errorMessage.toLowerCase().includes(techError.toLowerCase())
    )
  }

  // Get user-friendly error message or null if it's a technical error
  function getUserFriendlyError(errorMessage: string | null): string | null {
    if (!errorMessage) return null
    
    if (!shouldShowError(errorMessage)) {
      return null // Hide technical errors
    }
    
    return errorMessage
  }

  return (
    <div className="bg-gray-800 rounded-xl shadow-lg p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-bold text-white flex items-center gap-2">
          <Wallet className="h-5 w-5 text-purple-400" />
          Solana Info
        </h2>
        <button
          onClick={handleRefresh}
          disabled={isRefreshing || isLoading}
          className="p-2 text-gray-400 hover:text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          title="Refresh"
        >
          <RefreshCw className={`h-4 w-4 ${isRefreshing ? "animate-spin" : ""}`} />
        </button>
      </div>

      {getUserFriendlyError(error) && (
        <div className="mb-4 p-3 bg-red-900/20 border border-red-800 rounded-lg text-red-300 text-sm">
          {getUserFriendlyError(error)}
        </div>
      )}

      {/* Show helpful message if connected but no Solana address */}
      {isConnected && !address && !isLoading && (
        <div className="mb-4 p-3 bg-blue-900/20 border border-blue-800 rounded-lg">
          <div className="flex items-start gap-2">
            <Info className="h-4 w-4 text-blue-400 mt-0.5 flex-shrink-0" />
            <div className="text-blue-300 text-sm">
              <p className="font-medium mb-1">Solana features require Internet Identity</p>
              <p className="text-xs text-blue-400/80">
                To interact with Solana, please connect via Internet Identity using the "Identity" button in the header.
                Bitcoin wallet connection alone is not sufficient for Solana operations.
              </p>
            </div>
          </div>
        </div>
      )}

      <div className="space-y-4">
        {/* Address */}
        <div>
          <label className="text-xs text-gray-400 mb-1 block">Your Solana Address</label>
          <div className="flex items-center gap-2">
            <div className="flex-1 bg-gray-700 rounded-lg px-3 py-2 text-sm font-mono text-gray-300 truncate">
              {isLoading ? "Loading..." : truncateAddress(address)}
            </div>
            {address && (
              <button
                onClick={handleCopyAddress}
                className="p-2 bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors text-gray-300 hover:text-white"
                title="Copy address"
              >
                <Copy className={`h-4 w-4 ${copied ? "text-green-400" : ""}`} />
              </button>
            )}
          </div>
          {address && (
            <a
              href={`https://solscan.io/account/${address}`}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-1 text-xs text-purple-400 hover:text-purple-300 flex items-center gap-1"
            >
              View on Solscan <ExternalLink className="h-3 w-3" />
            </a>
          )}
        </div>

        {/* Balance */}
        <div>
          <label className="text-xs text-gray-400 mb-1 block">SOL Balance</label>
          <div className="bg-gray-700 rounded-lg px-3 py-2">
            <div className="text-lg font-semibold text-white">
              {isLoading ? "..." : formatBalance(balance)} SOL
            </div>
            {balance !== null && (
              <div className="text-xs text-gray-400 mt-1">
                {balance.toLocaleString()} lamports
              </div>
            )}
          </div>
        </div>

        {/* Blockhash */}
        <div>
          <label className="text-xs text-gray-400 mb-1 block">Recent Blockhash</label>
          <div className="bg-gray-700 rounded-lg px-3 py-2">
            <div className="text-sm font-mono text-gray-300 break-all">
              {isRefreshing ? "Loading..." : truncateBlockhash(blockhash)}
            </div>
          </div>
        </div>

        {/* Slot */}
        <div>
          <label className="text-xs text-gray-400 mb-1 block">Current Slot</label>
          <div className="bg-gray-700 rounded-lg px-3 py-2">
            <div className="text-sm font-mono text-gray-300">
              {isRefreshing ? "Loading..." : slot !== null ? slot.toLocaleString() : "Not available"}
            </div>
          </div>
        </div>

        {/* Status Info */}
        <div className="pt-4 border-t border-gray-700">
          <div className="flex items-center gap-2 text-xs text-gray-400">
            <div className={`w-2 h-2 rounded-full ${address ? "bg-green-400" : "bg-gray-500"}`} />
            <span>{address ? "Connected to Solana" : "Not connected"}</span>
          </div>
        </div>
      </div>
    </div>
  )
}
