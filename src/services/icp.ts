import { AuthClient } from "@dfinity/auth-client"
import { HttpAgent, Actor } from "@dfinity/agent"
import { Principal } from "@dfinity/principal"
import { ICP_CONFIG, host, isLocalNetwork } from "@/config/env"
import { logError, logWarn } from "@/utils/logger"

let authClient: AuthClient | null = null
let agent: HttpAgent | null = null
let siwbIdentity: any = null

export function getAgent(): HttpAgent | null {
  return agent
}

export async function createAuthClient(): Promise<AuthClient> {
  if (!authClient) {
    authClient = await AuthClient.create()
  }
  return authClient
}

export async function login(): Promise<Principal | null> {
  if (!ICP_CONFIG.internetIdentityUrl) {
    logError("Internet Identity URL not configured", new Error("Please deploy Internet Identity locally or set VITE_INTERNET_IDENTITY_URL in your .env file. See INTERNET_IDENTITY_SETUP.md for instructions."))
    return null
  }

  const authClient = await createAuthClient()

  return new Promise((resolve) => {
    authClient.login({
      identityProvider: ICP_CONFIG.internetIdentityUrl!,
      onSuccess: async () => {
        const identity = authClient!.getIdentity()
        agent = new HttpAgent({
          identity,
          host,
        })

        if (isLocalNetwork) {
          await agent.fetchRootKey()
        }

        resolve(identity.getPrincipal())
      },
      onError: (error) => {
        // UserInterrupt is not an error - it means the user canceled the login
        if (error !== "UserInterrupt") {
          logError("Login error", new Error(String(error)))
        }
        resolve(null)
      },
    })
  })
}

export async function loginWithBitcoin(): Promise<Principal | null> {
  // This function is kept for backward compatibility
  // Actual Bitcoin wallet login is handled via loginWithBitcoinWallet with provider selection
  logWarn("loginWithBitcoin: Use loginWithBitcoinWallet with provider selection instead")
  return null
}

export async function loginWithBitcoinWallet(provider: string): Promise<Principal | null> {
  try {
    // Dynamically import the SIWB identity package
    const siwbModule = await import("ic-use-siwb-identity")
    
    // The package should export a function or hook to connect wallets
    // Based on common patterns, we expect it to provide a way to connect
    let identity: any = null
    
    if (siwbModule.useSiwbIdentity) {
      // If it's a hook factory, we'll need to handle it differently
      // For now, try to find a connect function
      const connectFn = (siwbModule as any).connect || (siwbModule as any).loginWithBitcoin
      
      if (connectFn && typeof connectFn === "function") {
        identity = await connectFn(provider)
      } else {
        // Try using the hook pattern - create an instance
        // This is a workaround since hooks can't be called in regular functions
        logWarn("SIWB package structure differs from expected. Using alternative connection method.")
        
        // Fallback: try to access provider-specific methods
        const providerMap: Record<string, string> = {
          "wizz": "wizz",
          "unisat": "unisat", 
          "BitcoinProvider": "xverse"
        }
        
        const walletType = providerMap[provider] || provider.toLowerCase()
        
        // Try to connect using wallet-specific method
        if ((siwbModule as any)[walletType]) {
          identity = await (siwbModule as any)[walletType]()
        } else {
          throw new Error(`Unsupported wallet provider: ${provider}`)
        }
      }
    } else if ((siwbModule as any).connect) {
      // Direct connect function
      identity = await (siwbModule as any).connect(provider)
    } else {
      // Try common wallet provider patterns
      const walletMap: Record<string, () => Promise<any>> = {
        wizz: async () => {
          if (typeof window !== "undefined" && (window as any).wizz) {
            return await (window as any).wizz.request("connect")
          }
          throw new Error("Wizz wallet not found. Please install the Wizz wallet extension.")
        },
        unisat: async () => {
          if (typeof window !== "undefined" && (window as any).unisat) {
            const accounts = await (window as any).unisat.requestAccounts()
            if (accounts && accounts.length > 0) {
              return accounts[0]
            }
            throw new Error("No accounts found in Unisat wallet.")
          }
          throw new Error("Unisat wallet not found. Please install the Unisat wallet extension.")
        },
        xverse: async () => {
          if (typeof window !== "undefined" && (window as any).XverseProviders?.BitcoinProvider) {
            const provider = new (window as any).XverseProviders.BitcoinProvider()
            const response = await provider.requestAccounts()
            return response?.accounts?.[0]
          }
          throw new Error("Xverse wallet not found. Please install the Xverse wallet extension.")
        }
      }
      
      const walletKey = provider.toLowerCase().replace("bitcoinprovider", "xverse")
      const connectFn = walletMap[walletKey]
      
      if (!connectFn) {
        throw new Error(`Unsupported wallet provider: ${provider}`)
      }
      
      const walletAccount = await connectFn()
      
      // Convert wallet account to ICP identity
      // This requires the SIWB package to handle the conversion
      // For now, we'll store the wallet info and let the SIWB package handle identity creation
      if (siwbModule.createIdentityFromWallet) {
        identity = await siwbModule.createIdentityFromWallet(walletAccount, provider)
      } else {
        // Fallback: create a minimal identity structure
        logWarn("SIWB package missing identity conversion. Wallet connected but identity may not work.")
        identity = { provider, account: walletAccount }
      }
    }
    
    if (identity && identity.getPrincipal) {
      // Store the identity globally
      siwbIdentity = identity
      
      // Create agent with the identity
      agent = new HttpAgent({
        identity,
        host,
      })

      if (isLocalNetwork) {
        await agent.fetchRootKey()
      }

      return identity.getPrincipal()
    }
    
    return null
  } catch (error) {
    logError("Error connecting Bitcoin wallet", error as Error)
    throw error
  }
}

export async function setBitcoinIdentity(principal: Principal): Promise<void> {
  // This function is called after successful wallet connection
  // The identity should already be stored in siwbIdentity during loginWithBitcoinWallet
  if (!siwbIdentity) {
    logWarn("Bitcoin identity not stored. Connection may not persist.")
    return
  }
  
  // Agent should already be created in loginWithBitcoinWallet
  // Just verify it exists
  if (!agent) {
    agent = new HttpAgent({
      identity: siwbIdentity,
      host,
    })

    if (isLocalNetwork) {
      await agent.fetchRootKey()
    }
  }
}

export async function logout(): Promise<void> {
  if (authClient) {
    await authClient.logout()
    authClient = null
  }
  
  if (siwbIdentity) {
    try {
      await siwbIdentity.logout()
    } catch (error) {
      logError("Error logging out from Bitcoin wallet", error as Error)
    }
    siwbIdentity = null
  }
  
  agent = null
}

export async function getIdentity(): Promise<Principal | null> {
  // Check Internet Identity first
  const authClient = await createAuthClient()
  const iiIdentity = authClient.getIdentity()

  if (iiIdentity) {
    const principal = iiIdentity.getPrincipal()
    // Check if this is the anonymous principal using the official API
    if (principal.isAnonymous()) {
      // Don't return anonymous principal - treat as not authenticated
      return null
    }

    if (!agent) {
      agent = new HttpAgent({
        identity: iiIdentity,
        host,
      })

      if (isLocalNetwork) {
        await agent.fetchRootKey()
      }
    }
    return principal
  }

  // Check Bitcoin wallet identity
  if (siwbIdentity) {
    try {
      const identity = await siwbIdentity.getIdentity()
      if (identity) {
        if (!agent) {
          agent = new HttpAgent({
            identity,
            host,
          })

          if (isLocalNetwork) {
            await agent.fetchRootKey()
          }
        }
        return identity.getPrincipal()
      }
    } catch (error) {
      logError("Error getting Bitcoin wallet identity", error as Error)
    }
  }

  return null
}

export function createActor<T>(canisterId: string, interfaceFactory: any): T {
  if (!agent) {
    throw new Error("Agent not initialized. Please login first.")
  }

  return Actor.createActor<T>(interfaceFactory, {
    agent,
    canisterId,
  })
}
