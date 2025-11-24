import { useState, useRef, useEffect } from "react"
import { ShoppingBag, Landmark, LayoutDashboard, Wallet, Bitcoin, CheckCircle, ArrowLeftRight, LogOut, Copy, ChevronDown, CreditCard, RefreshCw } from "lucide-react"
import type { View } from "@/types"
import type { AuthMethod } from "@/hooks/useICP"
import type { Principal } from "@dfinity/principal"
import ConnectDialog from "./ConnectDialog"
import { useTokenBalances } from "@/hooks/useTokenBalances"

interface HeaderProps {
  currentView: View
  onNavigate: (view: View) => void
  isConnected: boolean
  onConnect: (method?: AuthMethod) => Promise<void>
  onBitcoinConnect?: (principal: Principal) => void
  onDisconnect: () => Promise<void>
  principal: Principal | null
}

function Header({ currentView, onNavigate, isConnected, onConnect, onBitcoinConnect, onDisconnect, principal }: HeaderProps) {
  const [connectDialogOpen, setConnectDialogOpen] = useState(false)
  const [dropdownOpen, setDropdownOpen] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)
  const { ckBTC, ckETH, ICP, SOL, isLoading: balancesLoading, refresh: refreshBalances } = useTokenBalances()
  
  const navItems = [
    { id: "shop" as View, name: "Shop & Earn", icon: ShoppingBag },
    { id: "lend" as View, name: "Lend", icon: Landmark },
    { id: "borrow" as View, name: "Borrow", icon: CreditCard },
    { id: "portfolio" as View, name: "Portfolio", icon: LayoutDashboard },
    { id: "swap" as View, name: "Swap", icon: ArrowLeftRight },
  ]

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setDropdownOpen(false)
      }
    }

    if (dropdownOpen) {
      document.addEventListener("mousedown", handleClickOutside)
    }

    return () => {
      document.removeEventListener("mousedown", handleClickOutside)
    }
  }, [dropdownOpen])

  function formatPrincipal(principal: Principal | null): string {
    if (!principal) return "Not connected"
    const principalText = principal.toText()
    return `${principalText.slice(0, 5)}...${principalText.slice(-3)}`
  }

  function formatBalance(amount: bigint | null, decimals: number = 8): string {
    if (amount === null) return "0.00"
    const divisor = BigInt(10 ** decimals)
    const whole = amount / divisor
    const fractional = amount % divisor
    const fractionalStr = fractional.toString().padStart(decimals, "0").slice(0, 4)
    return `${whole}.${fractionalStr}`
  }

  async function handleCopyPrincipal() {
    if (principal) {
      await navigator.clipboard.writeText(principal.toText())
      // You could add a toast notification here
      alert("Principal copied to clipboard!")
    }
  }

  async function handleDisconnect() {
    await onDisconnect()
    setDropdownOpen(false)
  }

  async function handleConnectClick() {
    // Show dialog for Bitcoin wallet selection
    setConnectDialogOpen(true)
  }

  async function handleInternetIdentityClick() {
    await onConnect("internet-identity")
  }

  function handleBitcoinConnect(principal: Principal) {
    // The ConnectDialog handles the Bitcoin wallet connection
    // This callback directly updates the connection state with the principal we already have
    if (principal && onBitcoinConnect) {
      onBitcoinConnect(principal)
    } else if (principal) {
      // Fallback: if onBitcoinConnect not provided, use the regular connect method
      onConnect("bitcoin")
    }
  }

  return (
    <header className="border-b border-gray-700 bg-gray-900/80 backdrop-blur-sm sticky top-0 z-10">
      <nav className="container mx-auto max-w-7xl px-6 lg:px-8 py-4 flex justify-between items-center">
        <div className="flex items-center gap-2">
          <Bitcoin className="text-yellow-400 h-8 w-8" />
          <span className="text-2xl font-bold text-white">BitRewards</span>
        </div>

        <div className="hidden md:flex items-center gap-6">
          {navItems.map((item) => (
            <button
              key={item.id}
              onClick={() => onNavigate(item.id)}
              className={`flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                currentView === item.id
                  ? "bg-blue-600 text-white"
                  : "text-gray-300 hover:bg-gray-700 hover:text-white"
              }`}
            >
              <item.icon className="h-5 w-5" />
              {item.name}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-3">
          {isConnected ? (
            <div className="relative" ref={dropdownRef}>
              <button
                onClick={() => setDropdownOpen(!dropdownOpen)}
                className="flex items-center gap-2 bg-green-600 text-white px-4 py-2 rounded-lg font-medium shadow-md hover:bg-green-500 transition-colors"
              >
                <CheckCircle className="h-5 w-5" />
                Connected
                <ChevronDown className="h-4 w-4" />
              </button>
              
              {dropdownOpen && (
                <div className="absolute right-0 mt-2 w-80 bg-gray-800 border border-gray-700 rounded-lg shadow-xl z-50">
                  <div className="p-4 border-b border-gray-700">
                    <p className="text-xs text-gray-400 mb-1">Connected as</p>
                    <div className="flex items-center gap-2">
                      <code className="text-sm text-gray-300 font-mono flex-1 truncate">
                        {formatPrincipal(principal)}
                      </code>
                      <button
                        onClick={handleCopyPrincipal}
                        className="p-1 hover:bg-gray-700 rounded transition-colors"
                        title="Copy principal"
                      >
                        <Copy className="h-4 w-4 text-gray-400" />
                      </button>
                    </div>
                  </div>

                  {/* Token Balances */}
                  <div className="p-4 border-b border-gray-700">
                    <div className="flex items-center justify-between mb-3">
                      <p className="text-xs text-gray-400 font-semibold uppercase">Token Balances</p>
                      <button
                        onClick={refreshBalances}
                        disabled={balancesLoading}
                        className="p-1 hover:bg-gray-700 rounded transition-colors disabled:opacity-50"
                        title="Refresh balances"
                      >
                        <RefreshCw className={`h-3 w-3 text-gray-400 ${balancesLoading ? "animate-spin" : ""}`} />
                      </button>
                    </div>
                    <div className="space-y-2">
                      <div className="flex items-center justify-between text-sm">
                        <span className="text-gray-400">ckBTC</span>
                        <span className="text-white font-mono">
                          {balancesLoading ? "..." : formatBalance(ckBTC, 8)}
                        </span>
                      </div>
                      <div className="flex items-center justify-between text-sm">
                        <span className="text-gray-400">ckETH</span>
                        <span className="text-white font-mono">
                          {balancesLoading ? "..." : formatBalance(ckETH, 18)}
                        </span>
                      </div>
                      <div className="flex items-center justify-between text-sm">
                        <span className="text-gray-400">ICP</span>
                        <span className="text-white font-mono">
                          {balancesLoading ? "..." : formatBalance(ICP, 8)}
                        </span>
                      </div>
                      <div className="flex items-center justify-between text-sm">
                        <span className="text-gray-400">SOL</span>
                        <span className="text-white font-mono">
                          {balancesLoading ? "..." : formatBalance(SOL, 9)}
                        </span>
                      </div>
                    </div>
                  </div>
                  
                  <div className="p-2">
                    <button
                      onClick={handleDisconnect}
                      className="w-full flex items-center gap-2 px-3 py-2 text-red-400 hover:bg-red-900/20 rounded transition-colors"
                    >
                      <LogOut className="h-4 w-4" />
                      Disconnect
                    </button>
                  </div>
                </div>
              )}
            </div>
          ) : (
            <>
              <button
                onClick={handleInternetIdentityClick}
                className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-500 transition-colors shadow-lg"
              >
                <div className="flex items-center justify-center w-5 h-5 rounded-full bg-blue-400">
                  <span className="text-white text-xs font-bold">II</span>
                </div>
                Identity
              </button>
              
              <button
                onClick={handleConnectClick}
                className="flex items-center gap-2 bg-yellow-500 text-white px-4 py-2 rounded-lg font-medium hover:bg-yellow-400 transition-colors shadow-lg"
              >
                <Wallet className="h-5 w-5" />
                Connect
              </button>
              
              <ConnectDialog
                isOpen={connectDialogOpen}
                onClose={() => setConnectDialogOpen(false)}
                onConnect={handleBitcoinConnect}
              />
            </>
          )}
        </div>
      </nav>
      {/* Mobile Nav */}
      <div className="md:hidden flex justify-center gap-4 p-4 border-t border-gray-700">
        {navItems.map((item) => (
          <button
            key={item.id}
            onClick={() => onNavigate(item.id)}
            className={`flex flex-col items-center gap-1 px-3 py-2 rounded-md text-xs font-medium transition-colors ${
              currentView === item.id ? "text-blue-400" : "text-gray-400 hover:text-white"
            }`}
          >
            <item.icon className="h-5 w-5" />
            {item.name}
          </button>
        ))}
      </div>
    </header>
  )
}

export default Header

