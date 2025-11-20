# ckBTC Integration Testing Guide

## Overview
This document outlines the testing strategy for ckBTC integration in the swap canister.

## Test Environment Setup

### Prerequisites
1. ckBTC testnet canister IDs (or mainnet for production testing)
2. Bitcoin testnet node (for deposit/withdrawal testing)
3. Test Bitcoin address with funds

### Testnet Canister IDs
- ckBTC Ledger (testnet): To be configured
- ckBTC Minter (testnet): To be configured

### Mainnet Canister IDs (Production)
- ckBTC Ledger: `mxzaz-hqaaa-aaaah-aaada-cai`
- ckBTC Minter: `mqygn-kiaaa-aaaah-aaaqaa-cai`

## Test Cases

### 1. Balance Checks
**Test**: `getCKBTCBalance(userId)`
- **Setup**: User with known ckBTC balance
- **Expected**: Returns correct balance in e8s (8 decimals)
- **Validation**: Compare with expected balance

### 2. Address Generation
**Test**: `getBTCAddress(userId)`
- **Setup**: Valid user principal
- **Expected**: Returns valid Bitcoin address (mainnet format)
- **Validation**: 
  - Address format validation
  - Address is unique per user
  - Address can receive Bitcoin

### 3. Deposit Flow
**Test**: Complete deposit flow
1. Get Bitcoin address via `getBTCAddress(userId)`
2. Send Bitcoin to the address (testnet)
3. Call `updateBalance()` to mint ckBTC
4. Verify ckBTC balance increased
5. Verify mint transaction recorded

**Expected Results**:
- ckBTC minted matches Bitcoin deposited (1:1 ratio)
- Balance updates correctly
- Transaction is recorded

### 4. Withdrawal Flow
**Test**: Complete withdrawal flow
1. User has ckBTC balance
2. Call `withdrawBTC(amount, btcAddress)`
3. Verify ckBTC is burned
4. Verify Bitcoin withdrawal request is created
5. Wait for Bitcoin to arrive at address

**Expected Results**:
- ckBTC balance decreases
- Withdrawal request is created
- Bitcoin arrives at specified address

### 5. Error Scenarios
- **Insufficient Balance**: Attempt withdrawal with insufficient ckBTC
- **Invalid Address**: Attempt withdrawal to invalid Bitcoin address
- **Amount Too Low**: Attempt withdrawal below minimum threshold
- **Network Errors**: Handle ckBTC canister unavailability

## Manual Testing Steps

### Test Deposit Flow
```bash
# 1. Get Bitcoin address
dfx canister call swap_canister getBTCAddress '(principal "USER_PRINCIPAL")'

# 2. Send Bitcoin to address (use Bitcoin testnet)
# Send 0.001 BTC to the address

# 3. Update balance to mint ckBTC
dfx canister call swap_canister updateBalance '()'

# 4. Check ckBTC balance
dfx canister call swap_canister getCKBTCBalance '(principal "USER_PRINCIPAL")'
```

### Test Withdrawal Flow
```bash
# 1. Check ckBTC balance
dfx canister call swap_canister getCKBTCBalance '(principal "USER_PRINCIPAL")'

# 2. Withdraw ckBTC
dfx canister call swap_canister withdrawBTC '(100000000 : nat64, "bc1qtest...")'

# 3. Verify withdrawal request created
# Check ckBTC minter for withdrawal status
```

## Implementation Status

✅ **Completed**:
- ckBTC ledger actor creation
- ckBTC minter actor creation
- Balance retrieval (`getCKBTCBalance`)
- Address generation (`getBTCAddress`)
- Balance update (`updateBalance`)
- BTC withdrawal (`withdrawBTC`)
- Error handling
- Input validation
- Rate limiting

⚠️ **Needs Testing**:
- Actual ckBTC canister integration (testnet/mainnet)
- End-to-end deposit flow
- End-to-end withdrawal flow
- Error scenario handling
- Network failure recovery

## Notes

- ckBTC uses 8 decimals (same as Bitcoin)
- Minimum withdrawal amounts apply (check minter configuration)
- Withdrawal processing time varies (typically 1-2 hours)
- Testnet ckBTC canister IDs need to be configured for testing

