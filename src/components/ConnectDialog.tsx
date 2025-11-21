import { useState, useEffect } from "react"
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
  const [error, setError] = useState<string | null>(null)

  // Clear error when dialog opens
  useEffect(() => {
    if (isOpen) {
      setError(null)
    }
  }, [isOpen])

  async function handleWalletSelect(provider: string) {
    setLoading(provider)
    setError(null)
    try {
      logInfo(`Connecting to ${provider} wallet`)
      
      const principal = await loginWithBitcoinWallet(provider)
      
      if (principal) {
        // Update the global identity in icp service
        await setBitcoinIdentity(principal)
        
        // Small delay to ensure identity is fully set before notifying parent
        await new Promise(resolve => setTimeout(resolve, 50))
        
        // Notify parent component
        onConnect(principal)
        onClose()
      } else {
        throw new Error(`Failed to connect to ${provider} wallet`)
      }
    } catch (error) {
      logError(`Error connecting to ${provider}`, error as Error)
      // Show the actual error message from the wallet connection
      const errorMessage = error instanceof Error 
        ? error.message 
        : `Failed to connect to ${provider} wallet. Please make sure the wallet extension is installed and unlocked.`
      setError(errorMessage)
    } finally {
      setLoading(null)
    }
  }

  function handleClose() {
    setError(null)
    onClose()
  }

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && handleClose()}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Connect Bitcoin Wallet</DialogTitle>
          <DialogDescription>
            Select your Bitcoin wallet to sign in:
          </DialogDescription>
        </DialogHeader>
        
        {error && (
          <div className="rounded-lg bg-destructive/10 border border-destructive/20 p-3 text-sm text-destructive">
            {error}
          </div>
        )}
        
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
