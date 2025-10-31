export interface Store {
  id: number
  name: string
  reward: number
  logo: string
  url?: string
}

export interface LendingAsset {
  id: string
  name: string
  symbol: string
  apy: number
  icon: string
}

export interface PortfolioAsset {
  name: string
  symbol: string
  amount: number
  value: number
}

export interface Portfolio {
  totalValue: number
  totalRewards: number
  totalLended: number
  assets: PortfolioAsset[]
}

export interface LendingDeposit {
  asset: string
  amount: number
  apy: number
}

export type View = "shop" | "lend" | "portfolio" | "swap"

export type ChainKeyToken = "ckBTC" | "ckETH" | "ICP"

export interface SwapPool {
  id: string
  tokenA: ChainKeyToken
  tokenB: ChainKeyToken
  liquidity: number
  volume24h: number
}

export interface SwapQuote {
  amountOut: bigint
  priceImpact: number
  fee: bigint
}

export interface SwapResult {
  txIndex: bigint
  amountOut: bigint
  priceImpact: number
}

export interface SwapRecord {
  id: bigint
  tokenIn: ChainKeyToken
  tokenOut: ChainKeyToken
  amountIn: bigint
  amountOut: bigint
  timestamp: bigint
}

