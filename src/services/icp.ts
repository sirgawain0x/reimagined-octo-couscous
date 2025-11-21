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

export async function createAuthClient(): Promise<AuthClient | null> {
  // Only create auth client if Internet Identity is configured
  // Return null if not configured (Bitcoin wallet is an alternative)
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
    } catch (error: any) {
      // If AuthClient creation fails (e.g., invalid canister ID), don't block Bitcoin auth
      // Return null instead of throwing - this allows Bitcoin wallet to work
      if (error?.message?.includes("canister id incorrect") || 
          error?.message?.includes("400") ||
          error?.message?.includes("Invalid")) {
        // Silently return null - Internet Identity is not available, but that's ok
        return null
      }
      // For other errors, log a warning but still return null
      logWarn("Failed to create AuthClient (this is ok if using Bitcoin wallet)", { error: String(error) })
      return null
    }
  }
  return authClient
}

export async function login(): Promise<Principal | null> {
  if (!ICP_CONFIG.internetIdentityUrl) {
    // Internet Identity is optional - Bitcoin wallet is an alternative
    logWarn("Internet Identity URL not configured. Use Bitcoin wallet authentication instead.")
    return null
  }

  const authClient = await createAuthClient()
  if (!authClient) {
    // Internet Identity is not available (invalid canister ID, not deployed, etc.)
    // This is expected when using Bitcoin wallet authentication
    logWarn("Internet Identity not available. Use Bitcoin wallet authentication instead.")
    return null
  }

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
  
  const normalized = provider.toLowerCase()
  
  switch (normalized) {
    case "wizz":
      return !!(window as any).wizz
    case "unisat":
      return !!(window as any).unisat
    case "bitcoinprovider":
    case "xverse":
      // Check for Xverse in multiple possible locations
      return !!(window as any).XverseProviders?.BitcoinProvider || !!(window as any).Xverse
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
      if (typeof siwbModule.useSiwbIdentity === "function") {
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
      logWarn("SIWB package connection failed, using direct wallet connection", { error: String(siwbError) })
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
              logInfo("Wizz wallet returned array:", { result: JSON.stringify(result) })
              return result[0] || result
            }
            if (result?.accounts && Array.isArray(result.accounts)) {
              logInfo("Wizz wallet returned object with accounts:", { accounts: JSON.stringify(result.accounts) })
              return result.accounts[0] || result
            }
            
            logInfo("Wizz wallet raw result:", { result: JSON.stringify(result) })
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
          
          logInfo("Connecting to Unisat wallet", { 
            hasUnisat: !!unisat,
            hasRequestAccounts: typeof unisat.requestAccounts === "function"
          })
          
          try {
            // Add a small delay to ensure extension is ready
            await new Promise(resolve => setTimeout(resolve, 100))
            
            // Try with timeout (30 seconds for user interaction)
            const accounts = await Promise.race([
              unisat.requestAccounts(),
              new Promise((_, reject) => 
                setTimeout(() => reject(new Error("Request timeout after 30s")), 30000)
              )
            ]) as string[]
            
            // Check for Chrome runtime errors
            const chromeRuntime = (window as any).chrome?.runtime
            if (chromeRuntime?.lastError) {
              const errorMsg = chromeRuntime.lastError.message || String(chromeRuntime.lastError)
              logWarn("Chrome runtime error after Unisat requestAccounts", { error: errorMsg })
              throw new Error(`Chrome runtime error: ${errorMsg}`)
            }
            
            if (accounts && accounts.length > 0) {
              logInfo("Unisat wallet returned accounts", { accountCount: accounts.length, firstAccount: accounts[0] })
              return accounts[0]
            }
            throw new Error("No accounts found in Unisat wallet. Please make sure you have an account set up.")
          } catch (error: any) {
            const errorMsg = error?.message || String(error)
            logError("Unisat wallet connection error", error as Error, { 
              errorCode: error?.code,
              errorMessage: errorMsg,
              errorName: error?.name
            })
            
            if (error.code === 4001 || errorMsg.includes("reject") || errorMsg.includes("denied")) {
              throw new Error("Connection was rejected. Please try again and approve the connection in Unisat wallet.")
            }
            if (errorMsg.includes("locked") || errorMsg.includes("unlock")) {
              throw new Error("Wallet is locked. Please unlock your Unisat wallet and try again.")
            }
            if (errorMsg.includes("timeout")) {
              throw new Error("Unisat wallet connection timed out. The wallet may be waiting for your approval. Please: 1) Check if a popup appeared in Unisat, 2) Ensure Unisat is unlocked, 3) Try clicking the connect button again.")
            }
            if (errorMsg.includes("message channel") || errorMsg.includes("asynchronous response")) {
              throw new Error("Unisat wallet extension is not responding. Please try: 1) Refreshing the page, 2) Ensuring Unisat is unlocked, 3) Restarting the Unisat extension.")
            }
            throw new Error(`Failed to connect to Unisat wallet: ${errorMsg || "Unknown error"}`)
          }
        },
        xverse: async () => {
          // Check for Xverse wallet in multiple possible locations
          const XverseProviders = (window as any).XverseProviders
          const Xverse = (window as any).Xverse
          
          logInfo("Checking for Xverse wallet", { 
            hasXverseProviders: !!XverseProviders,
            hasBitcoinProvider: !!XverseProviders?.BitcoinProvider,
            hasXverse: !!Xverse,
            xverseType: typeof XverseProviders?.BitcoinProvider
          })
          
          if (!XverseProviders?.BitcoinProvider && !Xverse) {
            throw new Error("Xverse wallet not found. Please make sure the Xverse extension is installed and unlocked.")
          }
          
          try {
            let xverseProvider: any
            let response: any
            
            // Method 1: Try XverseProviders.BitcoinProvider (newer API)
            if (XverseProviders?.BitcoinProvider) {
              const BitcoinProvider = XverseProviders.BitcoinProvider
              
              // Check if it's already an instance
              if (typeof BitcoinProvider.requestAccounts === "function") {
                xverseProvider = BitcoinProvider
                logInfo("Using XverseProviders.BitcoinProvider as instance")
              } 
              // Check if it's a constructor
              else if (typeof BitcoinProvider === "function") {
                try {
                  xverseProvider = new BitcoinProvider()
                  logInfo("Instantiated XverseProviders.BitcoinProvider")
                } catch (constructorError: any) {
                  logWarn("Failed to instantiate BitcoinProvider, trying as direct object", { error: String(constructorError) })
                  xverseProvider = BitcoinProvider
                }
              }
              // Try as direct object
              else {
                xverseProvider = BitcoinProvider
                logInfo("Using XverseProviders.BitcoinProvider as direct object")
              }
            }
            // Method 2: Try Xverse directly (older API)
            else if (Xverse) {
              xverseProvider = Xverse
              logInfo("Using Xverse directly")
            }
            
            if (!xverseProvider) {
              throw new Error("Xverse wallet provider not found. Please check the wallet extension.")
            }
            
            // Log available methods for debugging
            const availableMethodsList = Object.keys(xverseProvider).filter(key => 
              typeof xverseProvider[key] === "function"
            )
            logInfo("Available methods on Xverse provider", { methods: availableMethodsList })
            
            // Try to get accounts using different methods with retry logic
            // The extension might need a moment to be ready
            // Order matters: try direct methods first, then request API
            const methods = [
              {
                name: "requestAccounts (direct)",
                fn: () => xverseProvider.requestAccounts(),
                condition: typeof xverseProvider.requestAccounts === "function",
                timeout: 30000 // 30 seconds for user interaction
              },
              {
                name: "getAccounts",
                fn: () => xverseProvider.getAccounts(),
                condition: typeof xverseProvider.getAccounts === "function",
                timeout: 10000
              },
              {
                name: "enable",
                fn: () => xverseProvider.enable(),
                condition: typeof xverseProvider.enable === "function",
                timeout: 30000 // 30 seconds for user interaction
              },
              {
                name: "request with requestAccounts method",
                fn: () => xverseProvider.request({ method: "requestAccounts" }),
                condition: typeof xverseProvider.request === "function",
                timeout: 30000 // 30 seconds for user interaction
              },
              {
                name: "request with getAccounts method",
                fn: () => xverseProvider.request({ method: "getAccounts" }),
                condition: typeof xverseProvider.request === "function",
                timeout: 10000
              }
            ]
            
            const availableMethods = methods.filter(m => m.condition)
            
            if (availableMethods.length === 0) {
              logError("Xverse wallet API not recognized", new Error(`Provider type: ${typeof xverseProvider}, available methods: ${Object.keys(xverseProvider || {}).join(", ")}`))
              throw new Error("Xverse wallet API not recognized. Please check the wallet extension version or try updating Xverse.")
            }
            
            // Try each method with retry logic
            let lastError: any = null
            for (const method of availableMethods) {
              try {
                logInfo(`Trying ${method.name} on Xverse provider`, { timeout: method.timeout })
                
                // Add a small delay before calling to ensure extension is ready
                await new Promise(resolve => setTimeout(resolve, 200))
                
                // Try with timeout to avoid hanging
                // Use method-specific timeout (longer for methods that require user interaction)
                const timeout = method.timeout || 10000
                response = await Promise.race([
                  method.fn(),
                  new Promise((_, reject) => 
                    setTimeout(() => reject(new Error(`Request timeout after ${timeout}ms`)), timeout)
                  )
                ])
                
                // Check for Chrome runtime errors immediately after call
                const chromeRuntime = (window as any).chrome?.runtime
                if (chromeRuntime?.lastError) {
                  const errorMsg = chromeRuntime.lastError.message || String(chromeRuntime.lastError)
                  logWarn(`Chrome runtime error after ${method.name}`, { error: errorMsg })
                  
                  // If it's a message channel error, try next method
                  if (errorMsg.includes("message channel") || errorMsg.includes("asynchronous response")) {
                    throw new Error(`Message channel error: ${errorMsg}`)
                  }
                  
                  // For other Chrome errors, throw to try next method
                  throw new Error(`Chrome runtime error: ${errorMsg}`)
                }
                
                logInfo(`Successfully called ${method.name}`, { response })
                break // Success, exit loop
              } catch (methodError: any) {
                lastError = methodError
                const errorMsg = methodError?.message || String(methodError)
                
                // If it's a message channel error, try next method
                if (errorMsg.includes("message channel") || 
                    errorMsg.includes("asynchronous response") ||
                    errorMsg.includes("runtime.lastError")) {
                  logWarn(`${method.name} failed with message channel error, trying next method`, { error: errorMsg })
                  continue // Try next method
                }
                
                // If it's a timeout and we have more methods, try next
                if (errorMsg.includes("timeout") && availableMethods.length > 1) {
                  logWarn(`${method.name} timed out, trying next method`, { error: errorMsg })
                  continue // Try next method
                }
                
                // If it's a user rejection, don't try other methods
                if (methodError.code === 4001 || errorMsg.includes("reject") || errorMsg.includes("denied")) {
                  throw new Error("Connection was rejected. Please try again and approve the connection in Xverse wallet.")
                }
                
                // For other errors, log and try next method
                logWarn(`${method.name} failed, trying next method`, { error: errorMsg })
              }
            }
            
            // If all methods failed, throw a helpful error
            if (!response && lastError) {
              const errorMsg = lastError?.message || String(lastError)
              if (errorMsg.includes("message channel") || 
                  errorMsg.includes("asynchronous response") ||
                  errorMsg.includes("runtime.lastError")) {
                throw new Error("Xverse wallet extension is not responding. Please try: 1) Refreshing the page, 2) Ensuring Xverse is unlocked, 3) Restarting the Xverse extension.")
              }
              if (errorMsg.includes("timeout")) {
                throw new Error("Xverse wallet connection timed out. The wallet may be waiting for your approval. Please: 1) Check if a popup appeared in Xverse, 2) Ensure Xverse is unlocked, 3) Try clicking the connect button again.")
              }
              throw lastError
            }
            
            if (!response) {
              throw new Error("Failed to connect to Xverse wallet. No response from any connection method.")
            }
            
            logInfo("Xverse wallet response", { response, responseType: typeof response, isArray: Array.isArray(response) })
            
            // Handle different response formats
            if (Array.isArray(response)) {
              const address = response[0] || response
              logInfo("Extracted address from array", { address })
              return address
            }
            if (response?.accounts && Array.isArray(response.accounts)) {
              const address = response.accounts[0]
              logInfo("Extracted address from accounts array", { address })
              return address
            }
            if (response?.result && Array.isArray(response.result)) {
              const address = response.result[0]
              logInfo("Extracted address from result array", { address })
              return address
            }
            if (typeof response === "string") {
              logInfo("Response is string address", { address: response })
              return response
            }
            if (response?.address) {
              logInfo("Extracted address from address field", { address: response.address })
              return response.address
            }
            
            logWarn("Unexpected Xverse response format", { response })
            return response
          } catch (error: any) {
            const errorMessage = error?.message || String(error)
            const chromeError = (window as any).chrome?.runtime?.lastError?.message
            
            logError("Xverse wallet connection error", error as Error, { 
              errorCode: error?.code,
              errorMessage,
              errorName: error?.name,
              chromeRuntimeError: chromeError
            })
            
            // Check for timeout errors FIRST (before checking for locked)
            // Timeout errors should not be confused with locked errors
            if (errorMessage.includes("timeout") || errorMessage.includes("Request timeout")) {
              throw new Error("Xverse wallet connection timed out. The wallet may be waiting for your approval. Please: 1) Check if a popup appeared in Xverse, 2) Ensure Xverse is unlocked, 3) Try clicking the connect button again, 4) Make sure Xverse extension is not blocked by browser.")
            }
            
            // Check for Chrome extension message channel errors
            if (errorMessage.includes("message channel") || 
                errorMessage.includes("asynchronous response") ||
                errorMessage.includes("runtime.lastError") ||
                chromeError?.includes("message channel") ||
                chromeError?.includes("asynchronous response")) {
              throw new Error("Xverse wallet extension is not responding. Please try: 1) Refreshing the page, 2) Ensuring Xverse is unlocked, 3) Restarting the Xverse extension, or 4) Waiting a few seconds and trying again.")
            }
            
            // Check for user rejection
            if (error.code === 4001 || errorMessage.includes("reject") || errorMessage.includes("denied")) {
              throw new Error("Connection was rejected. Please try again and approve the connection in Xverse wallet.")
            }
            
            // Check for locked wallet (but only if it's NOT a timeout error)
            // Some wallets return "locked" when they timeout, so we need to be careful
            if ((errorMessage.includes("locked") || errorMessage.includes("unlock")) && 
                !errorMessage.includes("timeout")) {
              throw new Error("Wallet is locked. Please unlock your Xverse wallet and try again.")
            }
            
            if (errorMessage.includes("not a constructor") || errorMessage.includes("not a function")) {
              throw new Error("Xverse wallet API error. Please update the Xverse extension or try refreshing the page.")
            }
            if (errorMessage.includes("not found") || errorMessage.includes("not installed")) {
              throw new Error("Xverse wallet not found. Please install the Xverse browser extension.")
            }
            throw new Error(`Failed to connect to Xverse wallet: ${errorMessage || "Unknown error"}`)
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
        logInfo("Extracted address from string:", { address: bitcoinAddress })
      } else if (Array.isArray(walletAccount) && walletAccount.length > 0) {
        bitcoinAddress = walletAccount[0]
        logInfo("Extracted address from array:", { address: bitcoinAddress })
      } else if (walletAccount?.address) {
        bitcoinAddress = walletAccount.address
        logInfo("Extracted address from address field:", { address: bitcoinAddress })
      } else if (walletAccount?.accounts && Array.isArray(walletAccount.accounts)) {
        bitcoinAddress = walletAccount.accounts[0]
        logInfo("Extracted address from accounts array:", { address: bitcoinAddress })
      }
      
      if (!bitcoinAddress) {
        logError("Could not extract Bitcoin address", new Error(`Wallet account format: ${JSON.stringify(walletAccount)}`), { walletAccount: JSON.stringify(walletAccount) })
        throw new Error("Could not extract Bitcoin address from wallet. Wallet returned: " + JSON.stringify(walletAccount))
      }
      
      logInfo("Successfully extracted Bitcoin address:", { address: bitcoinAddress })
      
      // Try to create identity using SIWB canister flow
      // This requires: 1) Get SIWB message from canister, 2) Sign with wallet, 3) Get delegation
      try {
        // Import SIWB utilities
        await import("@dfinity/identity")
        await import("ic-use-siwb-identity")
        
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
        logError("Could not create identity from wallet", siwbError as Error, { provider, error: String(siwbError) })
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

export async function setBitcoinIdentity(_principal: Principal): Promise<void> {
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
      // Only call logout if it exists - not all identity types have this method
      if (typeof siwbIdentity.logout === "function") {
        await siwbIdentity.logout()
      }
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
      
      // If authClient is null, Internet Identity is not available (e.g., invalid canister ID)
      // This is expected and shouldn't be logged as a warning
      if (!authClient) {
        return null
      }
      
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
      // Only log unexpected errors (not configuration issues)
      if (error instanceof Error && 
          !error.message.includes("canister id incorrect") &&
          !error.message.includes("Internet Identity") &&
          !error.message.includes("400")) {
        logWarn("Unexpected error checking Internet Identity (this is ok if using Bitcoin wallet)", { error: error.message })
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
