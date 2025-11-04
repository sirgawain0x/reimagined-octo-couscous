/**
 * Environment variable validation
 * Ensures all required environment variables are set before the app starts
 */

import { ICP_CONFIG, VALIDATION_CLOUD_CONFIG } from "@/config/env"

interface ValidationError {
  variable: string
  message: string
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

  // In production, check that canister IDs are set
  if (ICP_CONFIG.network === "ic") {
    if (!ICP_CONFIG.canisterIds.rewards) {
      errors.push({
        variable: "VITE_CANISTER_ID_REWARDS",
        message: "Rewards canister ID is required for production",
      })
    }

    if (!ICP_CONFIG.canisterIds.lending) {
      errors.push({
        variable: "VITE_CANISTER_ID_LENDING",
        message: "Lending canister ID is required for production",
      })
    }

    if (!ICP_CONFIG.canisterIds.portfolio) {
      errors.push({
        variable: "VITE_CANISTER_ID_PORTFOLIO",
        message: "Portfolio canister ID is required for production",
      })
    }

    if (!ICP_CONFIG.canisterIds.swap) {
      errors.push({
        variable: "VITE_CANISTER_ID_SWAP",
        message: "Swap canister ID is required for production",
      })
    }
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

