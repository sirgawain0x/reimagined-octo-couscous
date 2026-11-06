import { AuthClient } from "@dfinity/auth-client"
import { HttpAgent, Actor, AnonymousIdentity } from "@dfinity/agent"
import { Principal } from "@dfinity/principal"
import { ICP_CONFIG, host, isLocalNetwork } from "@/config/env"
import { logWarn } from "@/utils/logger"

let authClient: AuthClient | null = null
let agent: HttpAgent | null = null
let anonymousAgent: HttpAgent | null = null

export function getAgent(): HttpAgent | null {
  return agent
}

export async function getAnonymousAgent(): Promise<HttpAgent> {
  if (!anonymousAgent) {
    const candidate = new HttpAgent({ identity: new AnonymousIdentity(), host })
    if (isLocalNetwork) await candidate.fetchRootKey()
    anonymousAgent = candidate
  }
  return anonymousAgent
}

export async function createAuthClient(): Promise<AuthClient | null> {
  if (!ICP_CONFIG.internetIdentityUrl) {
    return null
  }
  
  // Validate Internet Identity URL format before creating client
  // This prevents errors from invalid canister IDs in the URL
  const url = ICP_CONFIG.internetIdentityUrl
  if (url.includes("canisterId=")) {
    const match = url.match(/canisterId=([a-z0-9-]+)/i)
    if (match && match[1]) {
      const canisterId = match[1]
      // List of known invalid/placeholder canister IDs
      const invalidIds = ["rdmx6-jaaaa-aaaah-qcaiq-cai", "777", "lp777"]
      // Check for placeholder, invalid canister IDs, or IDs that are too short
      const isInvalid = invalidIds.some(invalid => canisterId.includes(invalid)) || 
                       canisterId.length < 27 ||
                       !canisterId.match(/^[a-z0-9-]{27,}$/i)
      
      if (isInvalid) {
        // Return null instead of throwing - Internet Identity is optional
        return null
      }
    }
  }
  
  if (!authClient) {
    try {
      authClient = await AuthClient.create()
    } catch (error) {
      logWarn("Internet Identity is unavailable", { error: String(error) })
      return null
    }
  }
  return authClient
}

export async function getIdentity(): Promise<Principal | null> {
  const client = await createAuthClient()
  if (!client || !(await client.isAuthenticated())) {
    agent = null
    return null
  }
  const identity = client.getIdentity()
  const principal = identity.getPrincipal()
  if (principal.isAnonymous()) {
    agent = null
    return null
  }
  const candidate = new HttpAgent({ identity, host })
  if (isLocalNetwork) await candidate.fetchRootKey()
  agent = candidate
  return principal
}

export async function login(): Promise<Principal | null> {
  const client = await createAuthClient()
  const identityProvider = ICP_CONFIG.internetIdentityUrl
  if (!client || !identityProvider) return null

  return new Promise((resolve, reject) => {
    Promise.resolve(client.login({
      identityProvider,
      onSuccess: () => getIdentity().then(resolve, reject),
      onError: () => resolve(null),
    })).catch(reject)
  })
}

export async function logout(): Promise<void> {
  agent = null
  await authClient?.logout()
  authClient = null
}

export async function createActor<T>(canisterId: string, interfaceFactory: any, allowAnonymous = false): Promise<T> {
  // Use authenticated agent if available
  if (agent) {
    return Actor.createActor<T>(interfaceFactory, {
      agent,
      canisterId,
    })
  }

  // For query methods, allow anonymous agent if explicitly allowed
  if (allowAnonymous) {
    const anonAgent = await getAnonymousAgent()
    return Actor.createActor<T>(interfaceFactory, {
      agent: anonAgent,
      canisterId,
    })
  }

  throw new Error("Agent not initialized. Please login first.")
}
