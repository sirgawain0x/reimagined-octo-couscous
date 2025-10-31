import { useState } from "react"
import { Modal, ModalContent, ModalHeader, ModalBody, Button, Spinner } from "@nextui-org/react"
import { Bitcoin } from "lucide-react"
import { loginWithBitcoinWallet, setBitcoinIdentity } from "@/services/icp"
import { logError, logInfo } from "@/utils/logger"
import type { Principal } from "@dfinity/principal"

interface ConnectDialogProps {
  isOpen: boolean
  onClose: () => void
  onConnect: (principal: Principal) => void
}

function ConnectDialog({ isOpen, onClose, onConnect }: ConnectDialogProps) {
  const [loading, setLoading] = useState(false)

  async function handleWalletSelect(provider: string) {
    setLoading(true)
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
      setLoading(false)
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} size="sm" className="z-50">
      <ModalContent>
        <ModalHeader className="text-xl font-bold">Connect Bitcoin Wallet</ModalHeader>
        <ModalBody className="pb-6">
          <p className="text-gray-400 text-sm mb-4">
            Select your Bitcoin wallet to sign in:
          </p>
          
          <div className="space-y-3">
            <Button
              onPress={() => handleWalletSelect("wizz")}
              isDisabled={loading}
              className="w-full"
              variant="bordered"
              size="lg"
            >
              Wizz Wallet
            </Button>

            <Button
              onPress={() => handleWalletSelect("unisat")}
              isDisabled={loading}
              className="w-full"
              variant="bordered"
              size="lg"
            >
              Unisat Wallet
            </Button>

            <Button
              onPress={() => handleWalletSelect("BitcoinProvider")}
              isDisabled={loading}
              className="w-full"
              variant="bordered"
              size="lg"
            >
              <Bitcoin className="w-5 h-5 mr-2" />
              Xverse Wallet
            </Button>
          </div>

          {loading && (
            <div className="absolute inset-0 flex items-center justify-center bg-black/50 rounded-lg">
              <Spinner size="lg" />
            </div>
          )}
        </ModalBody>
      </ModalContent>
    </Modal>
  )
}

export default ConnectDialog
