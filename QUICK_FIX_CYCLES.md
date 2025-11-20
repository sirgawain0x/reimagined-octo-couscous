# Quick Fix: Getting Cycles for Mainnet Deployment

**Important:** ICP has no free testnet. When you deploy with `--network ic`, you're deploying to mainnet, which requires cycles.

Your deployment is failing because you don't have enough cycles in your wallet. Here's how to fix it:

## Option 1: Convert ICP to Cycles (Recommended)

If you have ICP in your wallet:

```bash
# Check your ICP balance
dfx ledger --network ic balance

# Convert ICP to cycles (1 ICP ≈ 1 T cycles)
# You'll need at least 2-3 T cycles for all canisters
dfx cycles convert --amount=2.0 --network ic
```

## Option 2: Use Cycles Faucet

For testnet, you can get free cycles from the faucet:

1. Visit: https://faucet.dfinity.org/
2. Connect your wallet
3. Request cycles for testnet

## Option 3: Check Your Wallet

```bash
# Check your current cycles balance
dfx wallet --network ic balance

# If you have a wallet with cycles, you can send them:
# dfx wallet --network ic send <destination-wallet-id> --amount 1.0
```

## How Much Do You Need?

For deploying all canisters to ICP mainnet, you typically need:
- **Minimum**: 2-3 T cycles (trillion cycles)
- **Recommended**: 5 T cycles for safety
- **Per canister**: ~0.5-1 T cycles

**Note:** 1 ICP ≈ 1 T cycles, so expect to spend at least 2-3 ICP for initial deployment.

## After Getting Cycles

Once you have cycles, run the deployment script again:

```bash
./deploy-testnet.sh
```

## Troubleshooting

### "Cannot find wallet"
- Make sure you're using the correct identity: `dfx identity use testnet-deploy`
- Create a wallet if needed: `dfx wallet --network ic create`

### "Insufficient cycles" even after converting
- Wait a few minutes for the transaction to process
- Check balance again: `dfx wallet --network ic balance`
- Make sure you converted enough (at least 2-3 T cycles)

