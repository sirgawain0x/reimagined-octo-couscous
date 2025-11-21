import { useState, useEffect, useCallback } from "react"
import { Principal } from "@dfinity/principal"
import { login, logout, getIdentity } from "@/services/icp"
import { logError, logWarn } from "@/utils/logger"

export type AuthMethod = "internet-identity" | "bitcoin"

interface UseICPReturn {
  isConnected: boolean
  principal: Principal | null
  isLoading: boolean
  connect: (method?: AuthMethod) => Promise<void>
  setConnected: (principal: Principal | null) => void
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
      } else {
        setPrincipal(null)
        setIsConnected(false)
      }
    } catch (error) {
      logError("Error checking connection", error as Error)
      setPrincipal(null)
      setIsConnected(false)
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
        // Add a small delay to ensure siwbIdentity is set
        await new Promise(resolve => setTimeout(resolve, 100))
        const identity = await getIdentity()
        if (identity) {
          setPrincipal(identity)
          setIsConnected(true)
        } else {
          // If identity not found, reset state
          setPrincipal(null)
          setIsConnected(false)
        }
      } else {
        const principal = await login()
        if (principal) {
          setPrincipal(principal)
          setIsConnected(true)
        } else {
          // Internet Identity login failed - this is expected if II is not configured
          // Don't log as error, just silently fail (user can use Bitcoin wallet instead)
          logWarn("Internet Identity login unavailable. Please use Bitcoin wallet authentication.")
          setPrincipal(null)
          setIsConnected(false)
        }
      }
    } catch (error) {
      logError("Error connecting", error as Error)
      setPrincipal(null)
      setIsConnected(false)
    } finally {
      setIsLoading(false)
    }
  }, [])

  const setConnected = useCallback((principal: Principal | null) => {
    if (principal) {
      setPrincipal(principal)
      setIsConnected(true)
    } else {
      setPrincipal(null)
      setIsConnected(false)
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
    setConnected,
    disconnect,
  }
}

