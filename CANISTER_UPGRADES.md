# Canister Upgrade Procedures

This document outlines the procedures for upgrading canisters in production.

## Pre-Upgrade Checklist

1. **Backup Current State**
   - Export all persistent data (if applicable)
   - Document current canister IDs
   - Note any pending transactions

2. **Test Upgrade Locally**
   - Deploy to local dfx environment
   - Test all critical flows
   - Verify data persistence

3. **Review Changes**
   - Check for breaking changes in canister interfaces
   - Verify backward compatibility
   - Review security implications

## Upgrade Process

### 1. Stop Canister Operations (if needed)

For canisters with critical state:
```bash
# Note: Most canisters use persistent storage, so upgrades preserve state
# Only stop if you need to prevent new operations during upgrade
```

### 2. Build Canisters

```bash
# Build all canisters
dfx build

# Or build specific canister
dfx build rewards
dfx build lending
dfx build portfolio
dfx build swap
```

### 3. Deploy Upgrade

```bash
# Deploy to mainnet (requires wallet and cycles)
dfx deploy --network ic

# Or deploy specific canister
dfx deploy --network ic rewards
dfx deploy --network ic lending
dfx deploy --network ic portfolio
dfx deploy --network ic swap
```

### 4. Verify Upgrade

After upgrade, verify:
- Canister is running: `dfx canister --network ic status <canister-id>`
- Test critical flows
- Check logs for errors: `dfx canister --network ic logs <canister-id>`

## Upgrade Order

If canisters have dependencies, upgrade in this order:

1. **Shared Modules** (if changed)
   - Update shared modules first
   - All canisters depend on shared modules

2. **Independent Canisters**
   - Rewards canister
   - Lending canister
   - Swap canister

3. **Dependent Canisters**
   - Portfolio canister (depends on rewards and lending)

## State Persistence

### Persistent Storage

All canisters use `persistent` storage for:
- **Rewards Canister**: Stores, purchases, rewards, rune tokens
- **Lending Canister**: Assets, deposits, borrows, Bitcoin UTXOs
- **Portfolio Canister**: Canister ID configuration
- **Swap Canister**: Pools, swaps, ckBTC configuration

### Transient Storage

The following reset on upgrade:
- Rate limiter state (resets to allow fresh start)
- Temporary caches

## Rollback Procedure

If upgrade fails:

1. **Stop Canister** (if needed)
   ```bash
   dfx canister --network ic stop <canister-id>
   ```

2. **Redeploy Previous Version**
   ```bash
   git checkout <previous-commit>
   dfx build
   dfx deploy --network ic <canister-id>
   ```

3. **Verify Rollback**
   - Test critical flows
   - Check data integrity

## Testing Upgrades

### Local Testing

```bash
# Start local dfx
dfx start

# Deploy canisters
dfx deploy

# Test critical flows
npm test

# Run E2E tests
npx playwright test
```

### Testing Before Production

**Note:** ICP has no free testnet. The `--network ic` option deploys to mainnet, which requires cycles.

For testing, you can:
1. Test locally first: `dfx deploy` (local network, free)
2. Deploy to mainnet with Bitcoin testnet: Use Bitcoin testnet and ckBTC testnet services even when deployed to ICP mainnet
3. See `TESTNET_DEPLOYMENT.md` for configuring Bitcoin/ckBTC testnet

```bash
# Deploy to mainnet (requires cycles)
dfx deploy --network ic --wallet <wallet-id>

# Use mainnet canister IDs in .env
```

## Breaking Changes

If upgrade includes breaking changes:

1. **Interface Changes**
   - Update frontend code first
   - Deploy frontend
   - Then upgrade canisters

2. **Data Structure Changes**
   - Implement migration logic in `preupgrade`/`postupgrade` hooks
   - Test migration on local/testnet first

3. **Cross-Canister Changes**
   - Coordinate upgrades across dependent canisters
   - Update portfolio canister IDs if needed

## Monitoring

After upgrade, monitor:
- Error rates
- Response times
- Rate limit violations
- Cross-canister call failures

## Emergency Procedures

If canister becomes unresponsive:

1. **Check Status**
   ```bash
   dfx canister --network ic status <canister-id>
   ```

2. **Check Logs**
   ```bash
   dfx canister --network ic logs <canister-id>
   ```

3. **Restart Canister** (if needed)
   ```bash
   dfx canister --network ic stop <canister-id>
   dfx canister --network ic start <canister-id>
   ```

4. **Rollback** (if restart doesn't work)
   - Follow rollback procedure above

## Best Practices

1. **Always test locally first** - Use `dfx deploy` (local network, free)
2. **Test with Bitcoin testnet** - Deploy to ICP mainnet but use Bitcoin testnet for testing (see `TESTNET_DEPLOYMENT.md`)
3. **Have rollback plan ready**
4. **Monitor after upgrade**
5. **Document all changes**
6. **Coordinate with team**
7. **Backup critical data**

**Note:** ICP has no free testnet. For testing, use local development or deploy to mainnet with Bitcoin testnet configuration.

## Notes

- Canister upgrades preserve persistent state
- Transient state (rate limiters) resets on upgrade
- Cross-canister calls may fail during upgrade window
- Frontend should handle temporary unavailability gracefully

