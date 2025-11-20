# Mainnet Deployment Guide

## Important: ICP Network Options

**ICP has only two deployment environments:**

1. **Local** (`dfx start` or `--network local`) - Free, runs on your machine
2. **Mainnet** (`--network ic`) - Requires cycles (costs ICP)

**There is NO free ICP testnet.** When you deploy with `--network ic`, you're deploying to mainnet, which requires cycles.

### What "Testnet" Means in This Project

The "testnet" references in the code refer to:
- **Bitcoin testnet** - Your canisters can interact with Bitcoin testnet via ICP's Bitcoin API (separate from the ICP network)
- **ckBTC testnet services** - Testnet versions of ckBTC ledger/minter canisters

These are separate from the ICP network you deploy to. You can deploy to ICP mainnet while still using Bitcoin testnet and ckBTC testnet services for testing.

## Pre-Deployment Checklist

### 1. Understand Network Configuration

Your canisters have two types of network settings:

**ICP Network** (where canisters run):
- `local` - Free local development
- `ic` - Mainnet (requires cycles)

**Bitcoin Network** (what Bitcoin network to use):
- `#Regtest` - Local Bitcoin node
- `#Testnet` - Bitcoin testnet (for testing)
- `#Mainnet` - Bitcoin mainnet (production)

**ckBTC Services** (which ckBTC canisters to use):
- Testnet ckBTC canisters (for testing)
- Mainnet ckBTC canisters (production)

### 2. Configure Canister Code

Before deploying to mainnet, configure your canisters:

**For Bitcoin Testnet Testing (Recommended for initial mainnet deployment):**

**File: `src/canisters/rewards/main.mo` (line 63)**
```motoko
private let BTC_NETWORK : BitcoinApi.Network = #Testnet;  // Use Bitcoin testnet for testing
```

**File: `src/canisters/lending/main.mo` (line 74)**
```motoko
private let BTC_NETWORK : BitcoinApi.Network = #Testnet;  // Use Bitcoin testnet for testing
```

**File: `src/canisters/swap/main.mo` (line 40)**
```motoko
private let USE_TESTNET : Bool = true;  // Use ckBTC testnet services
```

**For Production (Bitcoin Mainnet):**

Change the above to:
```motoko
private let BTC_NETWORK : BitcoinApi.Network = #Mainnet;
private let USE_TESTNET : Bool = false;  // Use ckBTC mainnet services
```

### 3. Set Up Identity

```bash
# Create a new secure identity (recommended)
dfx identity new mainnet-deploy

# Use the identity
dfx identity use mainnet-deploy

# Or use default with warning suppression (not recommended for production)
export DFX_WARNING=-mainnet_plaintext_identity
```

### 4. Configure Environment Variables

Create/update `.env` file:

```env
# ICP Network - use "ic" for mainnet deployment
VITE_ICP_NETWORK=ic

# Internet Identity
VITE_INTERNET_IDENTITY_URL=https://identity.ic0.app

# Bitcoin Network (for Validation Cloud queries)
# Use "testnet" for testing, "mainnet" for production
VITE_BITCOIN_NETWORK=testnet

# Validation Cloud (optional)
VITE_VALIDATION_CLOUD_API_KEY=your_api_key_here

# Canister IDs (will be populated after deployment)
VITE_CANISTER_ID_REWARDS=
VITE_CANISTER_ID_LENDING=
VITE_CANISTER_ID_PORTFOLIO=
VITE_CANISTER_ID_SWAP=
VITE_CANISTER_ID_IC_SIWB_PROVIDER=be2us-64aaa-aaaaa-qaabq-cai
```

### 5. Get Cycles

**Mainnet deployment requires cycles.** You need at least 2-3 T cycles (trillion cycles) to deploy all canisters.

```bash
# Check your cycles balance
dfx wallet --network ic balance

# Convert ICP to cycles (1 ICP ≈ 1 T cycles)
dfx cycles convert --amount=2.0 --network ic
```

For more help getting cycles, see `QUICK_FIX_CYCLES.md` or run `./get-cycles.sh`.

## Deployment Steps

### Step 1: Build Canisters

```bash
# Install dependencies
mops install

# Build all canisters for mainnet
dfx build --network ic
```

### Step 2: Deploy to Mainnet

```bash
# Deploy all canisters
dfx deploy --network ic

# Or use the deployment script
./deploy-mainnet.sh
```

### Step 3: Get Canister IDs

After successful deployment, get your canister IDs:

```bash
dfx canister --network ic id rewards_canister
dfx canister --network ic id lending_canister
dfx canister --network ic id portfolio_canister
dfx canister --network ic id swap_canister
dfx canister --network ic id shopping_rewards_frontend
```

Update your `.env` file with these IDs.

### Step 4: Initialize Canisters

```bash
# Initialize lending canister
dfx canister --network ic call lending_canister init

# Initialize swap canister
dfx canister --network ic call swap_canister init

# Add initial stores (example)
dfx canister --network ic call rewards_canister addStore '(
  record {
    name = "Amazon";
    reward = 5.0;
    logo = "https://example.com/amazon.png";
    url = opt "https://amazon.com";
  }
)'
```

### Step 5: Verify Deployment

```bash
# Check canister status
dfx canister --network ic status rewards_canister
dfx canister --network ic status lending_canister

# Check logs
dfx canister --network ic logs rewards_canister
```

## Access Your Application

Your application will be available at:
```
https://<frontend-canister-id>.ic0.app
```

## Troubleshooting

### dfx Color Bug

If you encounter `ColorOutOfRange` panic:

1. **Update dfx**: This is the best solution
2. **Use a different terminal**: Try iTerm2 or Terminal.app
3. **Report the issue**: This is a known bug in dfx 0.29.2

### Insufficient Cycles

- Check your cycles balance: `dfx wallet --network ic balance`
- Convert ICP to cycles: `dfx cycles convert --amount=2.0 --network ic`
- See `QUICK_FIX_CYCLES.md` for more options

### Canister Deployment Fails

- Verify your identity: `dfx identity whoami`
- Check network connectivity: `dfx ping --network ic`
- Ensure you have sufficient cycles

### Canister Not Found After Deployment

- Verify deployment succeeded: `dfx canister --network ic status <canister-name>`
- Check if canister was created: Look for canister ID in deployment output
- Try redeploying: `dfx deploy --network ic <canister-name>`

## Important Notes

1. **Bitcoin Testnet vs Mainnet**: You can deploy to ICP mainnet while using Bitcoin testnet for testing. This allows you to test Bitcoin functionality without using real Bitcoin.

2. **ckBTC Testnet vs Mainnet**: The swap canister can use testnet ckBTC services even when deployed to ICP mainnet:
   - Testnet Ledger: `n5wcd-faaaa-aaaar-qaaea-cai`
   - Testnet Minter: `nfvlz-3qaaa-aaaar-qaanq-cai`
   - Mainnet Ledger: `mxzaz-hqaaa-aaaah-aaada-cai`
   - Mainnet Minter: `mqygn-kiaaa-aaaah-aaaqaa-cai`

3. **Cycles**: Mainnet requires cycles. Monitor your balance regularly and top up as needed.

4. **Network Configuration**: The `dfx.json` has the `ic` network configured pointing to `https://ic0.app`.

## Recommended Deployment Strategy

1. **Local Development**: Test everything locally first (`dfx start`, `dfx deploy`)
2. **Mainnet with Bitcoin Testnet**: Deploy to ICP mainnet but use Bitcoin testnet and ckBTC testnet services
3. **Full Production**: Switch to Bitcoin mainnet and ckBTC mainnet services

This allows you to:
- Test on real ICP infrastructure
- Avoid using real Bitcoin during testing
- Gradually move to full production

## Cost Estimation

Deploying to mainnet costs cycles:
- **Per canister**: ~0.5-1 T cycles for initial deployment
- **Total for all canisters**: ~2-3 T cycles minimum
- **Ongoing**: Canisters consume cycles for operations and storage

1 ICP ≈ 1 T cycles, so expect to spend at least 2-3 ICP for initial deployment.

