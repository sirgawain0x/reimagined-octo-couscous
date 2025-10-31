import { useState } from "react"
import { Bitcoin, Loader2 } from "lucide-react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { loginWithBitcoinWallet, setBitcoinIdentity } from "@/services/icp"
import { logError, logInfo } from "@/utils/logger"
import type { Principal } from "@dfinity/principal"

interface ConnectDialogProps {
  isOpen: boolean
  onClose: () => void
  onConnect: (principal: Principal) => void
}

function ConnectDialog({ isOpen, onClose, onConnect }: ConnectDialogProps) {
  const [loading, setLoading] = useState<string | null>(null)

  async function handleWalletSelect(provider: string) {
    setLoading(provider)
    try {
      logInfo(`Connecting to ${provider} wallet`)
      
      const principal = await loginWithBitcoinWallet(provider)
      
      if (principal) {
        // Update the global identity in icp service
        await setBitcoinIdentity(principal)
        
        // Notify parent component
        onConnect(principal)
        onClose()
      } else {
        throw new Error(`Failed to connect to ${provider} wallet`)
      }
    } catch (error) {
      logError(`Error connecting to ${provider}`, error as Error)
      alert(`Failed to connect to ${provider} wallet. Please make sure the wallet extension is installed and unlocked.`)
    } finally {
      setLoading(null)
    }
  }

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Connect Bitcoin Wallet</DialogTitle>
          <DialogDescription>
            Select your Bitcoin wallet to sign in:
          </DialogDescription>
        </DialogHeader>
        
        <div className="space-y-3 py-4">
          <Button
            onClick={() => handleWalletSelect("wizz")}
            disabled={loading !== null}
            className="w-full"
            variant="outline"
            size="lg"
          >
            {loading === "wizz" ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : null}
            Wizz Wallet
          </Button>

          <Button
            onClick={() => handleWalletSelect("unisat")}
            disabled={loading !== null}
            className="w-full"
            variant="outline"
            size="lg"
          >
            {loading === "unisat" ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : null}
            Unisat Wallet
          </Button>

          <Button
            onClick={() => handleWalletSelect("BitcoinProvider")}
            disabled={loading !== null}
            className="w-full"
            variant="outline"
            size="lg"
          >
            {loading === "BitcoinProvider" ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <Bitcoin className="mr-2 h-5 w-5" />
            )}
            Xverse Wallet
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}

export default ConnectDialog
