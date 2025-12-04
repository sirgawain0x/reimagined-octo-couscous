export const ICP_CONFIG = {
  network: import.meta.env.VITE_ICP_NETWORK || "local",
  internetIdentityUrl:
    import.meta.env.VITE_INTERNET_IDENTITY_URL ||
    (import.meta.env.VITE_ICP_NETWORK === "local" || !import.meta.env.VITE_ICP_NETWORK
      ? null // Internet Identity must be deployed locally and configured via VITE_INTERNET_IDENTITY_URL
      : "https://identity.ic0.app"),
  canisterIds: {
    icSiwbProvider: import.meta.env.VITE_CANISTER_ID_IC_SIWB_PROVIDER || "be2us-64aaa-aaaaa-qaabq-cai",
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
    devnet: import.meta.env.VITE_VALIDATION_CLOUD_SOLANA_DEVNET || "https://devnet.solana.validationcloud.io/v1/WYszimlgQzHUV_TqIVIV-l_FQ1jCUEYY0tGBId0VKy0",
    mainnet: import.meta.env.VITE_VALIDATION_CLOUD_SOLANA_MAINNET || "https://mainnet.solana.validationcloud.io/v1/gvRvjzER-2hsL04FVN4_Xg9RvaxLl7SkOshnvphtnOU",
  },
} as const

export const AFFILIATE_LINKS = {
  amazon: import.meta.env.VITE_AMAZON_AFFILIATE_LINK || "https://amzn.to/3KG7zfG",
  walmart: import.meta.env.VITE_WALMART_AFFILIATE_LINK || "https://goto.walmart.com/c/5898735/1398372/16662?sourceid=imp_000011112222333344&veh=aff&u=https%3A%2F%2Fwww.walmart.com",
  ebay: import.meta.env.VITE_EBAY_AFFILIATE_LINK || "https://ebay.us/XS4KJV",
} as const

export const isLocalNetwork = ICP_CONFIG.network === "local"
export const host = isLocalNetwork ? "http://localhost:4943" : "https://ic0.app"

