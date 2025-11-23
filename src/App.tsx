import { useState, Suspense, lazy } from "react"
import type { Principal } from "@dfinity/principal"
import { useICP } from "@/hooks/useICP"
import Header from "@/components/Header"
import Footer from "@/components/Footer"
import type { View } from "@/types"

// Lazy load view components for code splitting
const ShopView = lazy(() => import("@/components/ShopView"))
const LendView = lazy(() => import("@/components/LendView"))
const BorrowView = lazy(() => import("@/components/BorrowView"))
const PortfolioView = lazy(() => import("@/components/PortfolioView"))
const SwapView = lazy(() => import("@/components/SwapView"))

// Loading fallback component
function ViewLoader() {
  return (
    <div className="flex items-center justify-center min-h-[400px]">
      <div className="text-center">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-white mb-4"></div>
        <p className="text-gray-400">Loading...</p>
      </div>
    </div>
  )
}

function App() {
  const [view, setView] = useState<View>("shop")
  const { isConnected, connect, disconnect, principal, setConnected } = useICP()

  async function handleConnectWallet() {
    await connect()
  }

  function handleBitcoinConnect(principal: Principal) {
    // Directly set the connection state when Bitcoin wallet connects
    setConnected(principal)
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white font-sans">
      <Header 
        currentView={view} 
        onNavigate={setView} 
        isConnected={isConnected} 
        onConnect={handleConnectWallet}
        onBitcoinConnect={handleBitcoinConnect}
        onDisconnect={disconnect}
        principal={principal}
      />
      <main className="container mx-auto max-w-7xl p-6 lg:p-8">
        <Suspense fallback={<ViewLoader />}>
          {view === "shop" && <ShopView />}
          {view === "lend" && <LendView />}
          {view === "borrow" && <BorrowView />}
          {view === "portfolio" && <PortfolioView />}
          {view === "swap" && <SwapView />}
        </Suspense>
      </main>
      <Footer />
    </div>
  )
}

export default App

