/**
 * Canister actor factories
 * Creates type-safe actors for all canisters
 * 
 * Note: IDL factories should be generated using:
 *   dfx generate <canister-name>
 * This creates bindings in .dfx/local/canisters/<canister-name>/
 * 
 * For now, we'll use a dynamic approach that works with the Candid interfaces
 */

import { Principal } from "@dfinity/principal"
import { IDL } from "@dfinity/candid"
import { createActor as createActorUtil, getIdentity } from "./icp"
import { ICP_CONFIG } from "@/config/env"
import type {
  RewardsCanister,
  LendingCanister,
  PortfolioCanister,
  SwapCanister,
} from "@/types/canisters"
import { logError } from "@/utils/logger"

/**
 * Validate canister ID format and provide helpful error messages
 * Note: We don't check for "placeholder" patterns because dfx can generate
 * canister IDs with various patterns. If it's a valid Principal, we accept it.
 */
function validateCanisterId(id: string | undefined, canisterName: string, envVarName: string): string {
  if (!id || id.trim() === "") {
    const network = ICP_CONFIG.network === "local" ? "local" : "production"
    throw new Error(
      `${canisterName} canister ID not configured.\n\n` +
      `To fix this:\n` +
      `1. Deploy the ${canisterName.toLowerCase()} canister: dfx deploy ${canisterName.toLowerCase().replace(/\s+/g, "_")}_canister\n` +
      `2. Get the canister ID: dfx canister id ${canisterName.toLowerCase().replace(/\s+/g, "_")}_canister\n` +
      `3. Set ${envVarName} in your .env file with the actual canister ID\n\n` +
      `For ${network} network, the canister ID should look like: 'rrkah-fqaaa-aaaaa-aaaaq-cai'`
    )
  }
  
  // Validate Principal format - this is the only validation we need
  // If it's a valid Principal, it's a valid canister ID
  try {
    Principal.fromText(id)
  } catch (error) {
    throw new Error(
      `${canisterName} canister ID has invalid format: ${id}\n\n` +
      `Expected a valid Principal format (e.g., 'rrkah-fqaaa-aaaaa-aaaaq-cai').\n` +
      `Get the correct ID with: dfx canister id ${canisterName.toLowerCase().replace(/\s+/g, "_")}_canister`
    )
  }
  
  return id
}

/**
 * Create rewards canister actor
 * Allows anonymous agent for query methods (getStores, getUserRewards)
 */
export async function createRewardsActor(allowAnonymous = true): Promise<RewardsCanister> {
  const canisterId = validateCanisterId(
    ICP_CONFIG.canisterIds.rewards,
    "Rewards",
    "VITE_CANISTER_ID_REWARDS"
  )
  
  try {
    const idlFactory = () => IDL.Service({
      getStores: IDL.Func([], [IDL.Vec(IDL.Record({
        id: IDL.Nat32,
        name: IDL.Text,
        reward: IDL.Float64,
        logo: IDL.Text,
        url: IDL.Opt(IDL.Text),
      }))], ["query"]),
      trackPurchase: IDL.Func(
        [IDL.Nat32, IDL.Nat64],
        [IDL.Variant({
          ok: IDL.Record({
            purchaseId: IDL.Nat64,
            rewardEarned: IDL.Nat64,
          }),
          err: IDL.Text,
        })],
        [],
      ),
      getUserRewards: IDL.Func([IDL.Principal], [IDL.Nat64], ["query"]),
    })
    
    return createActorUtil<RewardsCanister>(canisterId, idlFactory, allowAnonymous)
  } catch (error) {
    logError("Failed to create rewards actor", error as Error)
    throw error
  }
}

/**
 * Create lending canister actor
 * Allows anonymous agent for query methods (getLendingAssets, getCurrentAPY)
 */
export async function createLendingActor(allowAnonymous = true): Promise<LendingCanister> {
  const canisterId = validateCanisterId(
    ICP_CONFIG.canisterIds.lending,
    "Lending",
    "VITE_CANISTER_ID_LENDING"
  )
  
  try {
    const idlFactory = () => IDL.Service({
      getLendingAssets: IDL.Func([], [IDL.Vec(IDL.Record({
        id: IDL.Text,
        name: IDL.Text,
        symbol: IDL.Text,
        apy: IDL.Float64,
      }))], ["query"]),
      deposit: IDL.Func(
        [IDL.Text, IDL.Nat64],
        [IDL.Variant({
          ok: IDL.Nat64,
          err: IDL.Text,
        })],
        [],
      ),
      withdraw: IDL.Func(
        [IDL.Text, IDL.Nat64, IDL.Text],
        [IDL.Variant({
          ok: IDL.Record({
            txid: IDL.Text,
            amount: IDL.Nat64,
          }),
          err: IDL.Text,
        })],
        [],
      ),
      getUserDeposits: IDL.Func([IDL.Principal], [IDL.Vec(IDL.Record({
        asset: IDL.Text,
        amount: IDL.Nat64,
        apy: IDL.Float64,
      }))], ["query"]),
      getCurrentAPY: IDL.Func([IDL.Text], [IDL.Float64], ["query"]),
    })
    
    return createActorUtil<LendingCanister>(canisterId, idlFactory, allowAnonymous)
  } catch (error) {
    logError("Failed to create lending actor", error as Error)
    throw error
  }
}

/**
 * Create portfolio canister actor
 */
export async function createPortfolioActor(): Promise<PortfolioCanister> {
  const canisterId = validateCanisterId(
    ICP_CONFIG.canisterIds.portfolio,
    "Portfolio",
    "VITE_CANISTER_ID_PORTFOLIO"
  )
  
  try {
    const idlFactory = () => IDL.Service({
      getPortfolio: IDL.Func([IDL.Principal], [IDL.Record({
        totalValue: IDL.Float64,
        totalRewards: IDL.Nat64,
        totalLended: IDL.Float64,
        assets: IDL.Vec(IDL.Record({
          name: IDL.Text,
          symbol: IDL.Text,
          amount: IDL.Nat64,
          value: IDL.Float64,
        })),
      })], []),
      getBalance: IDL.Func([IDL.Principal, IDL.Text], [IDL.Nat64], []),
      getTotalValue: IDL.Func([IDL.Principal], [IDL.Float64], []),
      setRewardsCanister: IDL.Func([IDL.Principal], [], []),
      setLendingCanister: IDL.Func([IDL.Principal], [], []),
    })
    
    return createActorUtil<PortfolioCanister>(canisterId, idlFactory)
  } catch (error) {
    logError("Failed to create portfolio actor", error as Error)
    throw error
  }
}

/**
 * Create swap canister actor
 * Allows anonymous agent for query methods (getQuote, getPools)
 */
export async function createSwapActor(allowAnonymous = true): Promise<SwapCanister> {
  const canisterId = validateCanisterId(
    ICP_CONFIG.canisterIds.swap,
    "Swap",
    "VITE_CANISTER_ID_SWAP"
  )
  
  try {
    const ChainKeyToken = IDL.Variant({
      ckBTC: IDL.Null,
      ckETH: IDL.Null,
      SOL: IDL.Null,
      ICP: IDL.Null,
    })
    
    const idlFactory = () => IDL.Service({
      getQuote: IDL.Func(
        [IDL.Text, IDL.Nat64],
        [IDL.Variant({
          ok: IDL.Record({
            amountOut: IDL.Nat64,
            priceImpact: IDL.Float64,
            fee: IDL.Nat64,
          }),
          err: IDL.Text,
        })],
        ["query"],
      ),
      swap: IDL.Func(
        [IDL.Text, ChainKeyToken, IDL.Nat64, IDL.Nat64],
        [IDL.Variant({
          ok: IDL.Record({
            txIndex: IDL.Nat,
            amountOut: IDL.Nat64,
            priceImpact: IDL.Float64,
          }),
          err: IDL.Text,
        })],
        [],
      ),
      getCKBTCBalance: IDL.Func([IDL.Principal], [IDL.Nat], ["query"]),
      getBTCAddress: IDL.Func([IDL.Principal], [IDL.Text], ["query"]),
      updateBalance: IDL.Func([], [IDL.Variant({
        ok: IDL.Nat,
        err: IDL.Text,
      })], []),
      withdrawBTC: IDL.Func([IDL.Nat64, IDL.Text], [IDL.Variant({
        ok: IDL.Nat,
        err: IDL.Text,
      })], []),
      getSwapHistory: IDL.Func([IDL.Principal], [IDL.Vec(IDL.Record({
        id: IDL.Nat64,
        user: IDL.Principal,
        tokenIn: ChainKeyToken,
        tokenOut: ChainKeyToken,
        amountIn: IDL.Nat64,
        amountOut: IDL.Nat64,
        timestamp: IDL.Nat64,
      }))], ["query"]),
      getPools: IDL.Func([], [IDL.Vec(IDL.Record({
        tokenA: ChainKeyToken,
        tokenB: ChainKeyToken,
        reserveA: IDL.Nat64,
        reserveB: IDL.Nat64,
        kLast: IDL.Nat64,
      }))], ["query"]),
      getSOLBalance: IDL.Func([IDL.Text], [IDL.Variant({
        ok: IDL.Nat64,
        err: IDL.Text,
      })], []),
      getSolanaSlot: IDL.Func([], [IDL.Variant({
        ok: IDL.Nat64,
        err: IDL.Text,
      })], ["query"]),
      getSolanaAddress: IDL.Func([IDL.Opt(IDL.Text)], [IDL.Variant({
        ok: IDL.Text,
        err: IDL.Text,
      })], []),
      sendSOL: IDL.Func([IDL.Text, IDL.Nat64, IDL.Opt(IDL.Text)], [IDL.Variant({
        ok: IDL.Text,
        err: IDL.Text,
      })], []),
      getRecentBlockhash: IDL.Func([], [IDL.Variant({
        ok: IDL.Text,
        err: IDL.Text,
      })], []),
    })
    
    return createActorUtil<SwapCanister>(canisterId, idlFactory, allowAnonymous)
  } catch (error) {
    logError("Failed to create swap actor", error as Error)
    throw error
  }
}

/**
 * Check if user is authenticated before creating actors
 */
export async function requireAuth(): Promise<Principal> {
  const identity = await getIdentity()
  if (!identity) {
    throw new Error("User must be authenticated to perform this action")
  }
  return identity
}
