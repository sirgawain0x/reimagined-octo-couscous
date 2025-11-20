/**
 * Environment variable validation
 * Ensures all required environment variables are set before the app starts
 */

import { ICP_CONFIG, VALIDATION_CLOUD_CONFIG } from "@/config/env"
import { Principal } from "@dfinity/principal"

interface ValidationError {
  variable: string
  message: string
}

/**
 * Validate that a string is a valid Principal format
 * ICP Principals are base32-encoded and typically look like: 'rrkah-fqaaa-aaaaa-aaaaq-cai'
 */
function isValidPrincipalFormat(id: string): boolean {
  try {
    Principal.fromText(id)
    // Basic format check: should contain hyphens and be reasonable length
    return id.length > 0 && id.length < 100 && id.includes("-")
  } catch {
    return false
  }
}

export function validateEnvironment(): { valid: boolean; errors: ValidationError[] } {
  const errors: ValidationError[] = []

  // Check network configuration
  if (!import.meta.env.VITE_ICP_NETWORK) {
    errors.push({
      variable: "VITE_ICP_NETWORK",
      message: "ICP network must be specified (local or ic)",
    })
  } else if (!["local", "ic"].includes(import.meta.env.VITE_ICP_NETWORK)) {
    errors.push({
      variable: "VITE_ICP_NETWORK",
      message: "VITE_ICP_NETWORK must be either 'local' or 'ic'",
    })
  }

  // Validate Bitcoin network configuration if Validation Cloud is configured
  if (VALIDATION_CLOUD_CONFIG.apiKey) {
    if (!VALIDATION_CLOUD_CONFIG.network) {
      errors.push({
        variable: "VITE_BITCOIN_NETWORK",
        message: "Bitcoin network must be specified (mainnet or testnet) when Validation Cloud is configured",
      })
    } else if (!["mainnet", "testnet"].includes(VALIDATION_CLOUD_CONFIG.network)) {
      errors.push({
        variable: "VITE_BITCOIN_NETWORK",
        message: "VITE_BITCOIN_NETWORK must be either 'mainnet' or 'testnet'",
      })
    }
  }

  // In production, check that canister IDs are set and valid
  if (ICP_CONFIG.network === "ic") {
    const validateCanisterId = (id: string | undefined, varName: string, name: string): void => {
      if (!id) {
        errors.push({
          variable: varName,
          message: `${name} canister ID is required for production`,
        })
      } else if (!isValidPrincipalFormat(id)) {
        errors.push({
          variable: varName,
          message: `${name} canister ID has invalid format. Expected Principal format (e.g., 'rrkah-fqaaa-aaaaa-aaaaq-cai')`,
        })
      }
    }

    validateCanisterId(ICP_CONFIG.canisterIds.rewards, "VITE_CANISTER_ID_REWARDS", "Rewards")
    validateCanisterId(ICP_CONFIG.canisterIds.lending, "VITE_CANISTER_ID_LENDING", "Lending")
    validateCanisterId(ICP_CONFIG.canisterIds.portfolio, "VITE_CANISTER_ID_PORTFOLIO", "Portfolio")
    validateCanisterId(ICP_CONFIG.canisterIds.swap, "VITE_CANISTER_ID_SWAP", "Swap")
  }

  // Internet Identity URL should always be set
  if (!ICP_CONFIG.internetIdentityUrl) {
    errors.push({
      variable: "VITE_INTERNET_IDENTITY_URL",
      message: "Internet Identity URL is required",
    })
  }

  return {
    valid: errors.length === 0,
    errors,
  }
}

export function assertEnvironmentValid(): void {
  const validation = validateEnvironment()

  if (!validation.valid) {
    const errorMessages = validation.errors.map((e) => `  - ${e.variable}: ${e.message}`).join("\n")
    
    throw new Error(
      `Environment validation failed. Please check the following variables:\n${errorMessages}\n\n` +
      `See .env.example for required configuration.`
    )
  }
}

