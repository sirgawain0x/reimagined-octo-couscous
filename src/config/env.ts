const network = import.meta.env.VITE_ICP_NETWORK || (import.meta.env.PROD ? "ic" : "local")

export const ICP_CONFIG = {
  network,
  internetIdentityUrl:
    import.meta.env.VITE_INTERNET_IDENTITY_URL ||
    (network === "local"
      ? null // Internet Identity must be deployed locally and configured via VITE_INTERNET_IDENTITY_URL
      : "https://identity.ic0.app"),
  canisterIds: {
    rewards: import.meta.env.VITE_CANISTER_ID_REWARDS || "",
    lending: import.meta.env.VITE_CANISTER_ID_LENDING || "",
    portfolio: import.meta.env.VITE_CANISTER_ID_PORTFOLIO || "",
    swap: import.meta.env.VITE_CANISTER_ID_SWAP || "",
  },
} as const

export const VALIDATION_CLOUD_CONFIG = {
  apiKey: import.meta.env.VITE_VALIDATION_CLOUD_API_KEY || "",
  network: (import.meta.env.VITE_BITCOIN_NETWORK || "testnet") as "mainnet" | "testnet",
  solana: {
    devnet: import.meta.env.VITE_VALIDATION_CLOUD_SOLANA_DEVNET || "",
    mainnet: import.meta.env.VITE_VALIDATION_CLOUD_SOLANA_MAINNET || "",
  },
} as const

export const isLocalNetwork = ICP_CONFIG.network === "local"
export const host = isLocalNetwork ? "http://localhost:4943" : "https://ic0.app"

