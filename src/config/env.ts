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

export const isLocalNetwork = ICP_CONFIG.network === "local"
export const host = isLocalNetwork ? "http://localhost:4943" : "https://ic0.app"

