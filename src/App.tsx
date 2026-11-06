import Header from "@/components/Header"
import Footer from "@/components/Footer"
import ShopView from "@/components/ShopView"

export default function App() {
  return (
    <div className="min-h-screen bg-gray-900 text-white font-sans">
      <Header />
      <main className="container mx-auto max-w-7xl p-6 lg:p-8">
        <ShopView />
      </main>
      <Footer />
    </div>
  )
}
