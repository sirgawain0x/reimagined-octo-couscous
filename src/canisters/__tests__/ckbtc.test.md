# ckBTC Integration Tests

This document outlines the test plan for ckBTC integration validation.

## Test Environment Setup

1. **Testnet Configuration**:
   - ckBTC Testnet Ledger: `n5wcd-faaaa-aaaar-qaaea-cai`
   - ckBTC Testnet Minter: `nfvlz-3qaaa-aaaar-qaanq-cai`
   - Set `USE_TESTNET = true` in swap canister

2. **Mainnet Configuration**:
   - ckBTC Mainnet Ledger: `mxzaz-hqaaa-aaaah-aaada-cai`
   - ckBTC Mainnet Minter: `mqygn-kiaaa-aaaah-aaaqaa-cai`
   - Set `USE_TESTNET = false` in swap canister

## Test Cases

### 1. ckBTC Ledger Integration

- [ ] Test balance query for user account
- [ ] Test balance query for account with subaccount
- [ ] Test balance query error handling (invalid account)
- [ ] Test ledger metadata (decimals, symbol, name)
- [ ] Test fee calculation

### 2. ckBTC Minter Integration

- [ ] Test Bitcoin address generation for user
- [ ] Test Bitcoin address generation with subaccount
- [ ] Test address generation error handling
- [ ] Test minter info retrieval

### 3. ckBTC Deposit Flow

- [ ] Test `updateBalance` with no new deposits
- [ ] Test `updateBalance` with new Bitcoin deposit
- [ ] Test `updateBalance` retry logic on TemporarilyUnavailable
- [ ] Test `updateBalance` error handling (MalformedAddress, InsufficientFunds)
- [ ] Test deposit amount validation
- [ ] Test deposit confirmation requirements

### 4. ckBTC Withdrawal Flow

- [ ] Test `withdrawBTC` with valid address and amount
- [ ] Test `withdrawBTC` with invalid Bitcoin address
- [ ] Test `withdrawBTC` with amount below minimum
- [ ] Test `withdrawBTC` with insufficient balance
- [ ] Test `withdrawBTC` retry logic on TemporarilyUnavailable
- [ ] Test `withdrawBTC` error handling (AlreadyProcessing)
- [ ] Test withdrawal address validation

### 5. Error Handling

- [ ] Test TemporarilyUnavailable error retry (3 attempts)
- [ ] Test non-retryable errors (MalformedAddress, InsufficientFunds)
- [ ] Test network error handling
- [ ] Test canister unavailable error handling
- [ ] Test error message clarity and user-friendliness

### 6. Network Configuration

- [ ] Test testnet canister ID configuration
- [ ] Test mainnet canister ID configuration
- [ ] Test network switching (if supported)
- [ ] Test invalid canister ID error handling

## Implementation Notes

- Retry logic is implemented in `updateBalance` and `withdrawBTC` methods
- Retry attempts: 3 maximum
- Retryable errors: TemporarilyUnavailable
- Non-retryable errors: MalformedAddress, InsufficientFunds, AmountTooLow, AlreadyProcessing

## Test Execution

To run ckBTC tests:

1. Deploy swap canister to testnet
2. Set `USE_TESTNET = true` in swap canister
3. Run integration tests: `npm test -- ckbtc`
4. Verify all test cases pass

## Known Limitations

- Motoko doesn't have built-in retry utilities, so retry logic is implemented inline
- Retry delays are not implemented (would require timer support)
- Network configuration is hardcoded (should be configurable via canister argument)
