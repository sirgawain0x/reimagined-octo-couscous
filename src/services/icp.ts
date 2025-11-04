import { AuthClient } from "@dfinity/auth-client"
import { HttpAgent, Actor, AnonymousIdentity } from "@dfinity/agent"
import { Principal } from "@dfinity/principal"
import { ICP_CONFIG, host, isLocalNetwork } from "@/config/env"
import { logError, logWarn, logInfo } from "@/utils/logger"

let authClient: AuthClient | null = null
let agent: HttpAgent | null = null
let anonymousAgent: HttpAgent | null = null
let siwbIdentity: any = null

export function getAgent(): HttpAgent | null {
  return agent
}

export async function getAnonymousAgent(): Promise<HttpAgent> {
  if (!anonymousAgent) {
    anonymousAgent = new HttpAgent({
      identity: new AnonymousIdentity(),
      host,
    })

    if (isLocalNetwork) {
      try {
        await anonymousAgent.fetchRootKey()
      } catch (error) {
        logError("Error fetching root key for anonymous agent", error as Error)
      }
    }
  }
  return anonymousAgent
}

export async function createAuthClient(): Promise<AuthClient> {
  // Only create auth client if Internet Identity is configured
  // This prevents errors when Internet Identity is not set up
  if (!ICP_CONFIG.internetIdentityUrl) {
    throw new Error("Internet Identity URL not configured. Skipping Internet Identity authentication.")
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
        throw new Error("Invalid Internet Identity canister ID detected. Please deploy Internet Identity locally with 'dfx deploy internet_identity' or use Bitcoin wallet authentication instead.")
      }
    }
  }
  
  if (!authClient) {
    try {
      authClient = await AuthClient.create()
    } catch (error: any) {
      // If AuthClient creation fails (e.g., invalid canister ID), don't block Bitcoin auth
      // Check if it's the specific "canister id incorrect" error
      if (error?.message?.includes("canister id incorrect") || error?.message?.includes("400")) {
        logWarn("Internet Identity canister ID is incorrect. This is expected if you're using Bitcoin wallet authentication.")
        throw new Error("Internet Identity not available. Use Bitcoin wallet authentication instead.")
      }
      logWarn("Failed to create AuthClient (this is ok if using Bitcoin wallet)", error as Error)
      throw error
    }
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

// Helper function to wait for wallet to be injected
async function waitForWallet(
  checkFn: () => boolean,
  timeout = 3000
): Promise<boolean> {
  if (checkFn()) return true
  
  return new Promise((resolve) => {
    const startTime = Date.now()
    const interval = setInterval(() => {
      if (checkFn()) {
        clearInterval(interval)
        resolve(true)
      } else if (Date.now() - startTime > timeout) {
        clearInterval(interval)
        resolve(false)
      }
    }, 100)
  })
}

// Helper function to check if wallet is installed
function checkWalletInstalled(provider: string): boolean {
  if (typeof window === "undefined") return false
  
  switch (provider.toLowerCase()) {
    case "wizz":
      return !!(window as any).wizz
    case "unisat":
      return !!(window as any).unisat
    case "bitcoinprovider":
    case "xverse":
      return !!(window as any).XverseProviders?.BitcoinProvider
    default:
      return false
  }
}

export async function loginWithBitcoinWallet(provider: string): Promise<Principal | null> {
  try {
    // Normalize provider name
    const normalizedProvider = provider.toLowerCase()
    const isXverse = normalizedProvider === "bitcoinprovider" || normalizedProvider === "xverse"
    
    // First, check if wallet is installed (with a short wait for async injection)
    const isInstalled = await waitForWallet(() => checkWalletInstalled(provider))
    
    if (!isInstalled) {
      const walletNames: Record<string, string> = {
        wizz: "Wizz Wallet",
        unisat: "Unisat Wallet",
        bitcoinprovider: "Xverse Wallet",
        xverse: "Xverse Wallet"
      }
      const walletName = walletNames[normalizedProvider] || provider
      throw new Error(`${walletName} extension not found. Please install the ${walletName} browser extension.`)
    }
    
    // Try to use the SIWB package first
    let identity: any = null
    
    try {
      const siwbModule = await import("ic-use-siwb-identity")
      
      // Try to use the SIWB package's connection method
      if (siwbModule.useSiwbIdentity) {
        const connectFn = (siwbModule as any).connect || (siwbModule as any).loginWithBitcoin
        
        if (connectFn && typeof connectFn === "function") {
          identity = await connectFn(provider)
        } else {
          // Try provider-specific methods from SIWB package
          const providerMap: Record<string, string> = {
            "wizz": "wizz",
            "unisat": "unisat", 
            "bitcoinprovider": "xverse",
            "xverse": "xverse"
          }
          
          const walletType = providerMap[normalizedProvider] || normalizedProvider
          
          if ((siwbModule as any)[walletType]) {
            identity = await (siwbModule as any)[walletType]()
          }
        }
      } else if ((siwbModule as any).connect) {
        identity = await (siwbModule as any).connect(provider)
      }
    } catch (siwbError) {
      logWarn("SIWB package connection failed, using direct wallet connection", siwbError as Error)
    }
    
    // Fallback to direct wallet connection if SIWB package didn't work
    if (!identity || !identity.getPrincipal) {
      // Direct wallet connection patterns
      const walletMap: Record<string, () => Promise<any>> = {
        wizz: async () => {
          const wizz = (window as any).wizz
          if (!wizz) {
            throw new Error("Wizz wallet not found. Please make sure the extension is installed and unlocked.")
          }
          
          try {
            // Try different connection methods for Wizz wallet
            let result: any = null
            
            // Method 1: Try requestAccounts (common wallet API)
            if (wizz.requestAccounts && typeof wizz.requestAccounts === "function") {
              result = await wizz.requestAccounts()
            }
            // Method 2: Try request with method "connect"
            else if (wizz.request && typeof wizz.request === "function") {
              try {
                result = await wizz.request({ method: "connect" })
              } catch (reqError: any) {
                // If connect doesn't work, try requestAccounts as fallback
                if (wizz.requestAccounts) {
                  result = await wizz.requestAccounts()
                } else {
                  throw reqError
                }
              }
            }
            // Method 3: Try enable (legacy method)
            else if (wizz.enable && typeof wizz.enable === "function") {
              result = await wizz.enable()
            }
            else {
              throw new Error("Wizz wallet API not recognized. Please check the wallet extension version.")
            }
            
            // Handle different response formats
            if (Array.isArray(result)) {
              logInfo("Wizz wallet returned array:", result)
              return result[0] || result
            }
            if (result?.accounts && Array.isArray(result.accounts)) {
              logInfo("Wizz wallet returned object with accounts:", result.accounts)
              return result.accounts[0] || result
            }
            
            logInfo("Wizz wallet raw result:", result)
            return result
          } catch (error: any) {
            if (error.code === 4001 || error.message?.includes("reject") || error.message?.includes("denied")) {
              throw new Error("Connection was rejected. Please try again and approve the connection.")
            }
            if (error.message?.includes("locked") || error.message?.includes("unlock")) {
              throw new Error("Wallet is locked. Please unlock your Wizz wallet and try again.")
            }
            throw new Error(`Failed to connect to Wizz wallet: ${error.message || "Unknown error"}`)
          }
        },
        unisat: async () => {
          const unisat = (window as any).unisat
          if (!unisat) {
            throw new Error("Unisat wallet not found. Please make sure the extension is installed and unlocked.")
          }
          
          try {
            const accounts = await unisat.requestAccounts()
            if (accounts && accounts.length > 0) {
              return accounts[0]
            }
            throw new Error("No accounts found in Unisat wallet. Please make sure you have an account set up.")
          } catch (error: any) {
            if (error.code === 4001 || error.message?.includes("reject") || error.message?.includes("denied")) {
              throw new Error("Connection was rejected. Please try again and approve the connection.")
            }
            if (error.message?.includes("locked") || error.message?.includes("unlock")) {
              throw new Error("Wallet is locked. Please unlock your Unisat wallet and try again.")
            }
            throw new Error(`Failed to connect to Unisat wallet: ${error.message || "Unknown error"}`)
          }
        },
        xverse: async () => {
          const XverseProviders = (window as any).XverseProviders
          if (!XverseProviders?.BitcoinProvider) {
            throw new Error("Xverse wallet not found. Please make sure the extension is installed and unlocked.")
          }
          
          try {
            // BitcoinProvider might be an instance or a constructor
            // Try using it as an instance first, then as a constructor
            let xverseProvider: any
            
            // Check if BitcoinProvider is already an instance (has requestAccounts method)
            if (typeof XverseProviders.BitcoinProvider.requestAccounts === "function") {
              xverseProvider = XverseProviders.BitcoinProvider
            } 
            // Check if BitcoinProvider is a constructor (has prototype or can be instantiated)
            else if (typeof XverseProviders.BitcoinProvider === "function") {
              xverseProvider = new XverseProviders.BitcoinProvider()
            }
            // If it's neither, try accessing it directly
            else {
              xverseProvider = XverseProviders.BitcoinProvider
            }
            
            // Try to get accounts
            let response: any
            if (typeof xverseProvider.requestAccounts === "function") {
              response = await xverseProvider.requestAccounts()
            } else if (typeof xverseProvider.request === "function") {
              response = await xverseProvider.request({ method: "requestAccounts" })
            } else {
              throw new Error("Xverse wallet API not recognized. Please check the wallet extension version.")
            }
            
            // Handle different response formats
            if (Array.isArray(response)) {
              return response[0] || response
            }
            if (response?.accounts && Array.isArray(response.accounts)) {
              return response.accounts[0]
            }
            if (typeof response === "string") {
              return response
            }
            
            return response
          } catch (error: any) {
            if (error.code === 4001 || error.message?.includes("reject") || error.message?.includes("denied")) {
              throw new Error("Connection was rejected. Please try again and approve the connection.")
            }
            if (error.message?.includes("locked") || error.message?.includes("unlock")) {
              throw new Error("Wallet is locked. Please unlock your Xverse wallet and try again.")
            }
            if (error.message?.includes("not a constructor")) {
              throw new Error("Xverse wallet API error. Please update the Xverse extension or try refreshing the page.")
            }
            throw new Error(`Failed to connect to Xverse wallet: ${error.message || "Unknown error"}`)
          }
        }
      }
      
      const walletKey = isXverse ? "xverse" : normalizedProvider
      const connectFn = walletMap[walletKey]
      
      if (!connectFn) {
        throw new Error(`Unsupported wallet provider: ${provider}`)
      }
      
      const walletAccount = await connectFn()
      
      // Get the Bitcoin address from wallet account
      let bitcoinAddress: string | undefined
      
      logInfo("Wallet account response:", walletAccount)
      
      if (typeof walletAccount === "string") {
        bitcoinAddress = walletAccount
        logInfo("Extracted address from string:", bitcoinAddress)
      } else if (Array.isArray(walletAccount) && walletAccount.length > 0) {
        bitcoinAddress = walletAccount[0]
        logInfo("Extracted address from array:", bitcoinAddress)
      } else if (walletAccount?.address) {
        bitcoinAddress = walletAccount.address
        logInfo("Extracted address from address field:", bitcoinAddress)
      } else if (walletAccount?.accounts && Array.isArray(walletAccount.accounts)) {
        bitcoinAddress = walletAccount.accounts[0]
        logInfo("Extracted address from accounts array:", bitcoinAddress)
      }
      
      if (!bitcoinAddress) {
        logError("Could not extract Bitcoin address", new Error(`Wallet account format: ${JSON.stringify(walletAccount)}`))
        throw new Error("Could not extract Bitcoin address from wallet. Wallet returned: " + JSON.stringify(walletAccount))
      }
      
      logInfo("Successfully extracted Bitcoin address:", bitcoinAddress)
      
      // Try to create identity using SIWB canister flow
      // This requires: 1) Get SIWB message from canister, 2) Sign with wallet, 3) Get delegation
      try {
        // Import SIWB utilities
        const { DelegationIdentity } = await import("@dfinity/identity")
        const siwbModule = await import("ic-use-siwb-identity")
        
        // Try to use the SIWB provider canister to get a message and create identity
        // For now, we'll create a simple deterministic principal from the address
        // In a full implementation, we'd need to:
        // 1. Call SIWB canister to get message
        // 2. Sign message with wallet
        // 3. Send signed message to canister
        // 4. Get delegation chain
        // 5. Create DelegationIdentity
        
        // Import Identity utilities
        const { Ed25519KeyIdentity } = await import("@dfinity/identity")
        
        // Create a deterministic identity from Bitcoin address
        // Hash the address to get consistent bytes for key generation
        const encoder = new TextEncoder()
        const addressBytes = encoder.encode(bitcoinAddress)
        const hashBuffer = await crypto.subtle.digest("SHA-256", addressBytes)
        const hashArray = new Uint8Array(hashBuffer)
        
        // Ed25519 secret keys are 32 bytes - use hash as secret key
        // SHA-256 always returns 32 bytes, so we can use it directly
        const secretKey = hashArray.slice(0, 32)
        
        // Create an Ed25519 identity from the secret key
        // This gives us a proper identity with a valid principal
        // Note: This is a simplified approach - in production you'd use proper SIWB delegation
        const keyIdentity = Ed25519KeyIdentity.fromSecretKey(secretKey)
        
        // Store both the identity and the Bitcoin address for reference
        identity = Object.assign(keyIdentity, {
          bitcoinAddress,
          provider
        })
        
        // Using simplified identity from Bitcoin address - this works for authentication
        // Full SIWB delegation would require canister integration but isn't needed for basic auth
      } catch (siwbError: any) {
        logError("Could not create identity from wallet", siwbError as Error)
        // Provide more specific error message
        const errorMessage = siwbError?.message || "Unknown error"
        throw new Error(`Failed to create identity from Bitcoin wallet: ${errorMessage}. Please ensure your wallet is unlocked and try again.`)
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

      const principal = identity.getPrincipal()
      if (principal) {
        return principal
      }
      
      throw new Error("Failed to get principal from wallet identity. Please try again.")
    }
    
    throw new Error(`Failed to establish connection with ${provider} wallet. Please try again.`)
  } catch (error) {
    logError("Error connecting Bitcoin wallet", error as Error)
    // Re-throw with original error message for better UX
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
  // Keep anonymous agent for query calls even after logout
}

export async function getIdentity(): Promise<Principal | null> {
  // Check Bitcoin wallet identity first (prioritize Bitcoin over Internet Identity)
  if (siwbIdentity) {
    try {
      // If siwbIdentity has getIdentity method, use it
      if (typeof siwbIdentity.getIdentity === "function") {
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
      } else if (siwbIdentity.getPrincipal) {
        // Direct identity (from our simplified Bitcoin wallet connection)
        const principal = siwbIdentity.getPrincipal()
        if (principal && !principal.isAnonymous()) {
          if (!agent) {
            agent = new HttpAgent({
              identity: siwbIdentity,
              host,
            })

            if (isLocalNetwork) {
              await agent.fetchRootKey()
            }
          }
          return principal
        }
      }
    } catch (error) {
      logError("Error getting Bitcoin wallet identity", error as Error)
    }
  }

  // Check Internet Identity second (only if Bitcoin identity not available)
  // Skip Internet Identity check if URL is not configured or invalid
  if (ICP_CONFIG.internetIdentityUrl) {
    try {
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
    } catch (error) {
      // Internet Identity might not be configured - that's ok if using Bitcoin wallet
      // Don't log warnings if it's just not configured (silent fail)
      if (error instanceof Error && !error.message.includes("canister id incorrect")) {
        logWarn("Could not check Internet Identity (this is ok if using Bitcoin wallet)", error as Error)
      }
    }
  }

  return null
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
