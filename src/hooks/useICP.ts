import { useState, useEffect, useCallback } from "react"
import { Principal } from "@dfinity/principal"
import { login, logout, getIdentity } from "@/services/icp"
import { logError } from "@/utils/logger"

export type AuthMethod = "internet-identity" | "bitcoin"

interface UseICPReturn {
  isConnected: boolean
  principal: Principal | null
  isLoading: boolean
  connect: (method?: AuthMethod) => Promise<void>
  disconnect: () => Promise<void>
}

export function useICP(): UseICPReturn {
  const [isConnected, setIsConnected] = useState(false)
  const [principal, setPrincipal] = useState<Principal | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    checkConnection()
  }, [])

  async function checkConnection() {
    try {
      const identity = await getIdentity()
      if (identity) {
        setPrincipal(identity)
        setIsConnected(true)
      }
    } catch (error) {
      logError("Error checking connection", error as Error)
    } finally {
      setIsLoading(false)
    }
  }

  const connect = useCallback(async (method: AuthMethod = "internet-identity") => {
    setIsLoading(true)
    try {
      if (method === "bitcoin") {
        // For Bitcoin, the connection is already established in ConnectDialog
        // Just refresh the connection state by checking for identity
        const identity = await getIdentity()
        if (identity) {
          setPrincipal(identity)
          setIsConnected(true)
        }
      } else {
        const principal = await login()
        if (principal) {
          setPrincipal(principal)
          setIsConnected(true)
        }
      }
    } catch (error) {
      logError("Error connecting", error as Error)
    } finally {
      setIsLoading(false)
    }
  }, [])

  const disconnect = useCallback(async () => {
    await logout()
    setPrincipal(null)
    setIsConnected(false)
  }, [])

  return {
    isConnected,
    principal,
    isLoading,
    connect,
    disconnect,
  }
}

