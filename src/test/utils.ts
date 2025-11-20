/**
 * Test utilities for mocking canister actors and ICP interactions
 */

import { vi, type Mock } from 'vitest'
import { Principal } from '@dfinity/principal'
import type {
  RewardsCanister,
  LendingCanister,
  PortfolioCanister,
  SwapCanister,
} from '@/types/canisters'
import type { Store, LendingAsset, LendingDeposit, Portfolio, SwapQuote, SwapResult, SwapRecord, ChainKeyToken } from '@/types'

/**
 * Create a mock rewards canister actor
 */
export function createMockRewardsActor(overrides?: Partial<RewardsCanister>): RewardsCanister {
  const defaultStores: Store[] = [
    {
      id: 1,
      name: 'Test Store',
      reward: 5.0,
      logo: 'https://example.com/logo.png',
      url: 'https://example.com',
    },
  ]

  return {
    getStores: vi.fn().mockResolvedValue(defaultStores),
    trackPurchase: vi.fn().mockResolvedValue({
      ok: { purchaseId: BigInt(1), rewardEarned: BigInt(1000) },
    }),
    getUserRewards: vi.fn().mockResolvedValue(BigInt(5000)),
    ...overrides,
  } as RewardsCanister
}

/**
 * Create a mock lending canister actor
 */
export function createMockLendingActor(overrides?: Partial<LendingCanister>): LendingCanister {
  const defaultAssets: LendingAsset[] = [
    {
      id: 'BTC',
      name: 'Bitcoin',
      symbol: 'BTC',
      apy: 5.5,
    },
    {
      id: 'ETH',
      name: 'Ethereum',
      symbol: 'ETH',
      apy: 4.2,
    },
  ]

  return {
    getLendingAssets: vi.fn().mockResolvedValue(defaultAssets),
    deposit: vi.fn().mockResolvedValue({ ok: BigInt(1) }),
    withdraw: vi.fn().mockResolvedValue({
      ok: { txid: 'mock_tx_123', amount: BigInt(1000000) },
    }),
    getUserDeposits: vi.fn().mockResolvedValue([]),
    getCurrentAPY: vi.fn().mockResolvedValue(5.5),
    borrow: vi.fn().mockResolvedValue({ ok: BigInt(1) }),
    repay: vi.fn().mockResolvedValue({ ok: undefined }),
    getUserBorrows: vi.fn().mockResolvedValue([]),
    getAvailableLiquidity: vi.fn().mockResolvedValue(BigInt(1000000000)),
    ...overrides,
  } as LendingCanister
}

/**
 * Create a mock portfolio canister actor
 */
export function createMockPortfolioActor(overrides?: Partial<PortfolioCanister>): PortfolioCanister {
  const defaultPortfolio: Portfolio = {
    totalValue: 10000.0,
    totalRewards: BigInt(5000),
    totalLended: 5000.0,
    assets: [
      {
        name: 'Bitcoin',
        symbol: 'BTC',
        amount: BigInt(100000000), // 1 BTC in satoshis
        value: 6000.0,
      },
    ],
  }

  return {
    getPortfolio: vi.fn().mockResolvedValue(defaultPortfolio),
    getBalance: vi.fn().mockResolvedValue(100000000),
    ...overrides,
  } as PortfolioCanister
}

/**
 * Create a mock swap canister actor
 */
export function createMockSwapActor(overrides?: Partial<SwapCanister>): SwapCanister {
  const defaultQuote: SwapQuote = {
    amountOut: BigInt(950000),
    priceImpact: 0.05,
    fee: BigInt(50000),
  }

  const defaultSwapResult: SwapResult = {
    txIndex: BigInt(1),
    amountOut: BigInt(950000),
    priceImpact: 0.05,
  }

  return {
    getQuote: vi.fn().mockResolvedValue({ ok: defaultQuote }),
    swap: vi.fn().mockResolvedValue({ ok: defaultSwapResult }),
    getCKBTCBalance: vi.fn().mockResolvedValue({ ok: BigInt(1000000) }),
    getBTCAddress: vi.fn().mockResolvedValue({ ok: 'bc1qtest123456789' }),
    updateBalance: vi.fn().mockResolvedValue({ ok: BigInt(100000) }),
    withdrawBTC: vi.fn().mockResolvedValue({ ok: BigInt(1) }),
    getSwapHistory: vi.fn().mockResolvedValue([]),
    getPools: vi.fn().mockResolvedValue([]),
    getSOLBalance: vi.fn().mockResolvedValue({ ok: BigInt(1000000000) }),
    getSolanaSlot: vi.fn().mockResolvedValue({ ok: BigInt(123456) }),
    getSolanaAddress: vi.fn().mockResolvedValue({ ok: 'SolanaTestAddress123' }),
    sendSOL: vi.fn().mockResolvedValue({ ok: 'mock_tx_signature' }),
    getRecentBlockhash: vi.fn().mockResolvedValue({ ok: 'mock_blockhash' }),
    ...overrides,
  } as SwapCanister
}

/**
 * Mock the canister actor factories
 */
export function mockCanisterActors() {
  const mockRewards = createMockRewardsActor()
  const mockLending = createMockLendingActor()
  const mockPortfolio = createMockPortfolioActor()
  const mockSwap = createMockSwapActor()

  vi.mock('@/services/canisters', async () => {
    const actual = await vi.importActual('@/services/canisters')
    return {
      ...actual,
      createRewardsActor: vi.fn().mockResolvedValue(mockRewards),
      createLendingActor: vi.fn().mockResolvedValue(mockLending),
      createPortfolioActor: vi.fn().mockResolvedValue(mockPortfolio),
      createSwapActor: vi.fn().mockResolvedValue(mockSwap),
    }
  })

  return {
    rewards: mockRewards,
    lending: mockLending,
    portfolio: mockPortfolio,
    swap: mockSwap,
  }
}

/**
 * Mock ICP identity and agent
 */
export function mockICPIdentity(principal?: Principal) {
  const mockPrincipal = principal || Principal.anonymous()
  const mockIdentity = {
    getPrincipal: () => Promise.resolve(mockPrincipal),
    sign: vi.fn(),
    transformRequest: vi.fn(),
  }

  vi.mock('@/services/icp', () => ({
    getIdentity: vi.fn().mockResolvedValue(mockIdentity),
    createActor: vi.fn(),
    connect: vi.fn().mockResolvedValue(mockIdentity),
    disconnect: vi.fn().mockResolvedValue(undefined),
  }))

  return mockIdentity
}

/**
 * Helper to wait for async operations in tests
 */
export function waitFor(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

/**
 * Helper to create mock error responses
 */
export function createErrorResponse(message: string): { err: string } {
  return { err: message }
}

/**
 * Helper to create mock success responses
 */
export function createSuccessResponse<T>(data: T): { ok: T } {
  return { ok: data }
}


