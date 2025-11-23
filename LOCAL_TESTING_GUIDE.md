# Local Testing Guide

This guide outlines all the tests you can run **locally for FREE** before deploying to mainnet (which costs cycles).

## Overview

You have **4 types of tests** that can be run locally:

1. **Unit Tests** (Vitest) - ✅ Runs immediately, no setup needed
2. **Integration Tests** - Requires local dfx and canisters
3. **Bitcoin Integration Tests** - Requires local Bitcoin regtest node
4. **E2E Tests** (Playwright) - Requires app and canisters running

## Quick Start: Run All Available Tests

```bash
# 1. Run unit tests (works immediately)
npm test

# 2. Run unit tests with coverage
npm run test:ci
```

## 1. Unit Tests (No Setup Required)

**Status:** ✅ Ready to run immediately

These tests use mocks and don't require any services to be running.

```bash
# Run all unit tests
npm test

# Run in watch mode (auto-rerun on file changes)
npm test -- --watch

# Run with coverage report
npm run test:ci
```

### What Gets Tested:

- ✅ **Service Layer Tests** (`src/services/__tests__/`):
  - `canisters.test.ts` - Canister actor creation and error handling
  - `icp.test.ts` - ICP service functionality
  - `validationcloud.test.ts` - ValidationCloud service mocks

- ✅ **Hook Tests** (`src/hooks/__tests__/`):
  - `useLending.test.ts` - Lending hook logic
  - `usePortfolio.test.ts` - Portfolio hook logic
  - `useRewards.test.ts` - Rewards hook logic
  - `useSwap.test.ts` - Swap hook logic

- ✅ **Utility Tests** (`src/utils/__tests__/`):
  - `retry.test.ts` - Retry utility logic

### Test Coverage

The test suite includes coverage reporting. Check `coverage/` directory after running `npm run test:ci`.

## 2. Integration Tests (Requires Local dfx)

**Status:** ⚠️ Requires local dfx and canisters deployed

These tests interact with real canisters running on your local ICP replica.

### Prerequisites:

```bash
# 1. Start local ICP replica with Bitcoin support
dfx start --enable-bitcoin

# 2. Deploy canisters locally (free, uses no cycles)
dfx deploy

# 3. Get canister IDs and set environment variables
export VITE_CANISTER_ID_REWARDS=$(dfx canister id rewards_canister)
export VITE_CANISTER_ID_LENDING=$(dfx canister id lending_canister)
export VITE_CANISTER_ID_PORTFOLIO=$(dfx canister id portfolio_canister)
export VITE_CANISTER_ID_SWAP=$(dfx canister id swap_canister)
export VITE_ICP_NETWORK=local
```

### Run Integration Tests:

```bash
# Run specific integration test file
npm test -- src/canisters/__tests__/integration/canister-interactions.test.ts

# Or run all integration tests
npm test -- src/canisters/__tests__/
```

### What Gets Tested:

- ✅ Canister initialization
- ✅ Cross-canister calls (portfolio → lending, rewards, swap)
- ✅ Rate limiting across canisters
- ✅ Error propagation between canisters
- ✅ Bitcoin API integration on regtest

**Test File:** `src/canisters/__tests__/integration/canister-interactions.test.ts`

## 3. Bitcoin Integration Tests (Requires Bitcoin Regtest)

**Status:** ⚠️ Requires Bitcoin regtest node + local dfx

These tests verify Bitcoin functionality using a local Bitcoin node.

### Prerequisites:

```bash
# 1. Start Bitcoin regtest node
npm run bitcoin:start

# 2. Wait for Bitcoin node to sync
npm run bitcoin:status

# 3. Start dfx with Bitcoin support
dfx start --enable-bitcoin

# 4. Deploy canisters
dfx deploy
```

### Run Bitcoin Tests:

```bash
# Run Bitcoin integration tests
npm test -- src/canisters/__tests__/bitcoin-integration.test.ts
```

### What Gets Tested:

- ✅ Bitcoin address generation (P2PKH, P2WPKH, P2TR)
- ✅ UTXO management
- ✅ Transaction building
- ✅ Address validation
- ✅ Integration with ICP Bitcoin API

**Test File:** `src/canisters/__tests__/bitcoin-integration.test.ts`

**Note:** Some tests are placeholders and require actual Bitcoin on regtest. See the test file comments for details.

## 4. E2E Tests (Playwright)

**Status:** ⚠️ Requires Playwright installation + running app

These tests verify complete user flows in a browser.

### Prerequisites:

```bash
# 1. Install Playwright (if not already installed)
npx playwright install

# 2. Start dfx with Bitcoin support
dfx start --enable-bitcoin

# 3. Deploy canisters
dfx deploy

# 4. Start the frontend in a separate terminal
npm run dev
```

### Run E2E Tests:

```bash
# Run E2E tests
npx playwright test

# Run with UI mode (interactive)
npx playwright test --ui
```

### What Gets Tested:

- ✅ Complete Bitcoin deposit flow
- ✅ Complete withdrawal flow
- ✅ Complete swap flow
- ✅ Complete lending flow

**Test File:** `e2e/critical-flows.spec.ts`

**Note:** Some transaction confirmations are commented out to avoid actual transactions. Review the test file before enabling.

## Complete Local Testing Workflow

Here's the recommended order for comprehensive local testing:

```bash
# Step 1: Run unit tests (fast, no setup)
npm run test:ci

# Step 2: Start local environment
dfx start --enable-bitcoin &
npm run bitcoin:start &

# Step 3: Wait for services to be ready
sleep 30  # Wait for dfx to initialize
npm run bitcoin:status  # Verify Bitcoin is running

# Step 4: Deploy canisters locally
dfx deploy

# Step 5: Run integration tests
npm test -- src/canisters/__tests__/integration/

# Step 6: Run Bitcoin integration tests
npm test -- src/canisters/__tests__/bitcoin-integration.test.ts

# Step 7: Start frontend and run E2E tests
npm run dev &
npx playwright test
```

## What You Can Test Locally

### ✅ Can Test Locally (Free):

1. **All unit tests** - Service logic, hooks, utilities
2. **Canister interactions** - Cross-canister calls, error handling
3. **Bitcoin address generation** - All address types (P2PKH, P2WPKH, P2TR)
4. **UTXO management** - With local Bitcoin regtest
5. **Transaction building** - Structure and validation
6. **Address validation** - All Bitcoin address formats
7. **Rate limiting** - Canister-level rate limiting
8. **Error handling** - Error propagation across canisters
9. **UI flows** - Complete user journeys (deposit, withdraw, swap, lend)

### ❌ Cannot Test Locally (Requires Mainnet):

1. **Real ICP mainnet interactions** - Requires cycles
2. **Real Bitcoin mainnet transactions** - Requires real Bitcoin
3. **ckBTC mainnet services** - Only available on mainnet
4. **Internet Identity mainnet** - Only available on mainnet
5. **Actual cycle consumption** - Only measurable on mainnet

## Testing Best Practices

### Before Deploying to Mainnet:

1. ✅ **Run all unit tests** - `npm run test:ci`
2. ✅ **Run integration tests locally** - Verify canister interactions
3. ✅ **Test Bitcoin flows on regtest** - Verify Bitcoin integration
4. ✅ **Run E2E tests** - Verify complete user flows
5. ✅ **Check test coverage** - Aim for >80% coverage
6. ✅ **Review error handling** - Ensure graceful failures

### Test Environment Configuration

Create a `.env.test` file for local testing:

```env
VITE_ICP_NETWORK=local
VITE_CANISTER_ID_REWARDS=rrkah-fqaaa-aaaaa-aaaaq-cai
VITE_CANISTER_ID_LENDING=rrkah-fqaaa-aaaaa-aaaaq-cai
VITE_CANISTER_ID_PORTFOLIO=rrkah-fqaaa-aaaaa-aaaaq-cai
VITE_CANISTER_ID_SWAP=rrkah-fqaaa-aaaaa-aaaaq-cai
VITE_BITCOIN_NETWORK=regtest
```

## Troubleshooting

### Unit Tests Fail:

```bash
# Clear cache and reinstall
rm -rf node_modules .vitest
npm install
npm test
```

### Integration Tests Fail:

```bash
# Verify dfx is running
dfx ping

# Verify canisters are deployed
dfx canister list

# Check canister IDs match environment variables
dfx canister id rewards_canister
echo $VITE_CANISTER_ID_REWARDS
```

### Bitcoin Tests Fail:

```bash
# Check Bitcoin node status
npm run bitcoin:status

# Restart Bitcoin node if needed
npm run bitcoin:stop
npm run bitcoin:start
```

### E2E Tests Fail:

```bash
# Verify frontend is running
curl http://localhost:5173

# Check browser installation
npx playwright install chromium
```

## Summary

You can test **almost everything locally** before deploying to mainnet:

- ✅ All unit tests (immediate)
- ✅ Canister integration (requires local dfx)
- ✅ Bitcoin functionality (requires regtest)
- ✅ Complete user flows (requires E2E setup)

**Total cost for local testing: $0** (completely free!)

Only deploy to mainnet when:
- ✅ All local tests pass
- ✅ You've verified functionality on regtest
- ✅ You're ready to spend cycles (2-3 ICP for deployment)

