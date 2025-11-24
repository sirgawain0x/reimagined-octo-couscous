import { Principal } from "@dfinity/principal"
import type { Store, LendingAsset, LendingDeposit, Portfolio, ChainKeyToken, SwapQuote, SwapResult, SwapRecord } from "./index"

export interface RewardsCanister {
  getStores: () => Promise<Store[]>
  trackPurchase: (storeId: number, amount: bigint) => Promise<{ ok: { purchaseId: bigint; rewardEarned: bigint }; err?: string } | { ok?: { purchaseId: bigint; rewardEarned: bigint }; err: string }>
  getUserRewards: (userId: Principal) => Promise<bigint>
}

import type { BorrowInfo } from "./index"

export interface LendingCanister {
  getLendingAssets: () => Promise<LendingAsset[]>
  deposit: (asset: string, amount: bigint) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  withdraw: (asset: string, amount: bigint, address: string) => Promise<{ ok: { txid: string; amount: bigint }; err?: string } | { ok?: { txid: string; amount: bigint }; err: string }>
  getUserDeposits: (userId: Principal) => Promise<LendingDeposit[]>
  getCurrentAPY: (asset: string) => Promise<number>
  borrow: (asset: string, amount: bigint, collateralAsset: string, collateralAmount: bigint) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  repay: (borrowId: bigint, amount: bigint) => Promise<{ ok: void; err?: string } | { ok?: void; err: string }>
  getUserBorrows: (userId: Principal) => Promise<BorrowInfo[]>
  getAvailableLiquidity: (asset: string) => Promise<bigint>
}

export interface PortfolioCanister {
  getPortfolio: (userId: Principal) => Promise<Portfolio>
  getBalance: (userId: Principal, asset: string) => Promise<number>
}

export interface SwapCanister {
  getQuote: (poolId: string, amountIn: bigint) => Promise<{ ok: SwapQuote; err?: string } | { ok?: SwapQuote; err: string }>
  swap: (poolId: string, tokenIn: ChainKeyToken, amountIn: bigint, minAmountOut: bigint) => Promise<{ ok: SwapResult; err?: string } | { ok?: SwapResult; err: string }>
  getCKBTCBalance: (userId: Principal) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  getBTCAddress: (userId: Principal) => Promise<{ ok: string; err?: string } | { ok?: string; err: string }>
  updateBalance: () => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  withdrawBTC: (amount: bigint, btcAddress: string) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  getCanisterCKBTCBalance: () => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  depositCKBTC: (amount: bigint) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  getCKETHBalance: (userId: Principal) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  getETHAddress: (userId: Principal) => Promise<{ ok: string; err?: string } | { ok?: string; err: string }>
  updateCkETHBalance: () => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  withdrawETH: (amount: bigint, ethAddress: string) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  getCanisterCKETHBalance: () => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  depositCKETH: (amount: bigint) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  getSwapHistory: (userId: Principal) => Promise<SwapRecord[]>
  getPools: () => Promise<Array<{ tokenA: ChainKeyToken; tokenB: ChainKeyToken; reserveA: bigint; reserveB: bigint; kLast: bigint }>>
  getSOLBalance: (solAddress: string) => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  getSolanaSlot: () => Promise<{ ok: bigint; err?: string } | { ok?: bigint; err: string }>
  getSolanaAddress: (keyName?: string | null) => Promise<{ ok: string; err?: string } | { ok?: string; err: string }>
  sendSOL: (toAddress: string, amountLamports: bigint, keyName?: string | null) => Promise<{ ok: string; err?: string } | { ok?: string; err: string }>
  getRecentBlockhash: () => Promise<{ ok: string; err?: string } | { ok?: string; err: string }>
}

