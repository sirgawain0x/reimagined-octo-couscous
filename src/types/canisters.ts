import { Principal } from "@dfinity/principal"
import type { Store, LendingAsset, LendingDeposit, Portfolio, ChainKeyToken, SwapQuote, SwapResult, SwapRecord } from "./index"

export interface RewardsCanister {
  getStores: () => Promise<Store[]>
  trackPurchase: (storeId: number, amount: bigint) => Promise<{ ok: { purchaseId: bigint; rewardEarned: bigint }; err?: string } | { ok?: { purchaseId: bigint; rewardEarned: bigint }; err: string }>
  getUserRewards: (userId: Principal) => Promise<bigint>
}

export interface LendingCanister {
  getLendingAssets: () => Promise<LendingAsset[]>
  deposit: (asset: string, amount: bigint) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  withdraw: (asset: string, amount: bigint, address: string) => Promise<{ ok: { txid: string; amount: bigint }; err?: string } | { ok?: { txid: string; amount: bigint }; err: string }>
  getUserDeposits: (userId: Principal) => Promise<LendingDeposit[]>
  getCurrentAPY: (asset: string) => Promise<number>
}

export interface PortfolioCanister {
  getPortfolio: (userId: Principal) => Promise<Portfolio>
  getBalance: (userId: Principal, asset: string) => Promise<number>
}

export interface SwapCanister {
  getQuote: (poolId: string, amountIn: bigint) => Promise<{ ok: SwapQuote; err?: string } | { ok?: SwapQuote; err: string }>
  swap: (poolId: string, tokenIn: ChainKeyToken, amountIn: bigint, minAmountOut: bigint) => Promise<{ ok: SwapResult; err?: string } | { ok?: SwapResult; err: string }>
  getCKBTCBalance: (userId: Principal) => Promise<bigint>
  getBTCAddress: (userId: Principal) => Promise<string>
  updateBalance: () => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  withdrawBTC: (amount: bigint, btcAddress: string) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  getSwapHistory: (userId: Principal) => Promise<SwapRecord[]>
}

