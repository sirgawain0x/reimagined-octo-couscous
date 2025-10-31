/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ICP_NETWORK?: string
  readonly VITE_INTERNET_IDENTITY_URL?: string
  readonly VITE_CANISTER_ID_REWARDS?: string
  readonly VITE_CANISTER_ID_LENDING?: string
  readonly VITE_CANISTER_ID_PORTFOLIO?: string
  readonly VITE_CANISTER_ID_SWAP?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

