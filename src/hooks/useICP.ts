import { useEffect, useState } from "react"
import type { Principal } from "@dfinity/principal"
import { getIdentity, login, logout } from "@/services/icp"

export function useICP() {
  const [principal, setPrincipal] = useState<Principal | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    let active = true
    getIdentity().then(identity => {
      if (active) setPrincipal(identity)
    }).catch(() => {
      if (active) setError("Could not restore your session. Please sign in again.")
    }).finally(() => {
      if (active) setIsLoading(false)
    })
    return () => { active = false }
  }, [])

  async function connect() {
    setIsLoading(true)
    setError("")
    try {
      const identity = await login()
      setPrincipal(identity)
      if (!identity) setError("Sign-in did not finish. You can still browse the shop.")
    } catch {
      setError("Internet Identity is unavailable. Try again later.")
    } finally {
      setIsLoading(false)
    }
  }

  async function disconnect() {
    setIsLoading(true)
    setError("")
    try {
      await logout()
      setPrincipal(null)
    } catch {
      setError("Sign-out failed. Please try again.")
    } finally {
      setIsLoading(false)
    }
  }

  return { principal, isConnected: Boolean(principal), isLoading, error, connect, disconnect }
}
