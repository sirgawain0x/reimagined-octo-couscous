import { vi } from 'vitest'
import { Principal } from '@dfinity/principal'
import { HttpAgent } from '@dfinity/agent'

// Export all the named exports that tests expect
export const getAgent = vi.fn((): HttpAgent | null => null)

export const getAnonymousAgent = vi.fn(async (): Promise<HttpAgent> => {
  return {} as HttpAgent
})

export const createAuthClient = vi.fn(async () => ({
  create: vi.fn(),
  login: vi.fn(),
  logout: vi.fn(),
  isAuthenticated: vi.fn(() => false),
}))

export const getIdentity = vi.fn(async (): Promise<Principal | null> => null)

export const createActor = vi.fn(async <T = any>(): Promise<T> => {
  return {} as T
})

export const login = vi.fn(async (): Promise<Principal | null> => null)

export const logout = vi.fn(async (): Promise<void> => {})

export const loginWithBitcoin = vi.fn(async (): Promise<Principal | null> => null)

export const loginWithBitcoinWallet = vi.fn(async (): Promise<Principal | null> => null)

export const setBitcoinIdentity = vi.fn(async (_principal: Principal): Promise<void> => {})

