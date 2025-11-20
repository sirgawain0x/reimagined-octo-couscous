import { useState } from "react"
import { useICP } from "@/hooks/useICP"
import Header from "@/components/Header"
import ShopView from "@/components/ShopView"
import LendView from "@/components/LendView"
import BorrowView from "@/components/BorrowView"
import PortfolioView from "@/components/PortfolioView"
import SwapView from "@/components/SwapView"
import Footer from "@/components/Footer"
import type { View } from "@/types"

function App() {
  const [view, setView] = useState<View>("shop")
  const { isConnected, connect, disconnect, principal } = useICP()

  async function handleConnectWallet() {
    await connect()
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white font-sans">
      <Header 
        currentView={view} 
        onNavigate={setView} 
        isConnected={isConnected} 
        onConnect={handleConnectWallet}
        onDisconnect={disconnect}
        principal={principal}
      />
      <main className="container mx-auto max-w-7xl p-6 lg:p-8">
        {view === "shop" && <ShopView />}
        {view === "lend" && <LendView />}
        {view === "borrow" && <BorrowView />}
        {view === "portfolio" && <PortfolioView />}
        {view === "swap" && <SwapView />}
      </main>
      <Footer />
    </div>
  )
}

export default App

