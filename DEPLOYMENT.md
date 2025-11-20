# Deployment Guide for Bitcoin-Enabled ICP Shopping Rewards Platform

## Overview

This guide will help you set up and deploy the Bitcoin-enabled shopping rewards platform on ICP with Motoko canisters.

## Important: ICP Network Options

**ICP has only two deployment environments:**

1. **Local** (`dfx start` or `--network local`) - Free, runs on your machine
2. **Mainnet** (`--network ic`) - Requires cycles (costs ICP)

**There is NO free ICP testnet.** When you deploy with `--network ic`, you're deploying to mainnet, which requires cycles.

### Understanding "Testnet" in This Project

The "testnet" references in this codebase refer to:
- **Bitcoin testnet** - Your canisters can interact with Bitcoin testnet via ICP's Bitcoin API (separate from the ICP network)
- **ckBTC testnet services** - Testnet versions of ckBTC ledger/minter canisters

These are separate from the ICP network. You can deploy to ICP mainnet while using Bitcoin testnet and ckBTC testnet services for testing.

For more details, see:
- `MAINNET_DEPLOYMENT.md` - Complete guide for mainnet deployment
- `TESTNET_DEPLOYMENT.md` - Guide for configuring Bitcoin/ckBTC testnet

## Prerequisites

### Required Software

1. **IC SDK (dfx)** - Version 0.29.2 or higher
   ```bash
   curl --proto '=https' --tlsv1.2 https://internetcomputer.org/install.sh -sSf | sh
   ```

2. **Bitcoin Core** - For local regtest network
   ```bash
   # macOS
   brew install bitcoin
   
   # Linux
   sudo apt-get install bitcoin
   ```

3. **Node.js** - v18 or higher
   ```bash
   # Already installed via nvm
   ```

4. **mops** - Motoko package manager (v3.0.2+)
   ```bash
   npm install -g mops
   ```

### Bitcoin Network Setup

1. Create Bitcoin data directory (if not exists):
   ```bash
   mkdir -p bitcoin_data
   ```

2. Bitcoin configuration is already set up in `bitcoin_data/bitcoin.conf`:
   - Regtest mode enabled
   - RPC authentication configured
   - Transaction index enabled

3. Start Bitcoin node:
   ```bash
   bitcoind -conf=$(pwd)/bitcoin_data/bitcoin.conf -datadir=$(pwd)/bitcoin_data --port=18444 -daemon
   ```

## Deployment Steps

### 1. Install Motoko Dependencies

```bash
# Navigate to project directory
cd /Users/gawainbracyii/Developer/reimagined-octo-couscous

# Install mops dependencies (when Bitcoin libraries are ready)
mops install

# Note: Currently, the Bitcoin libraries are placeholders.
# Full implementation will be added once the motoko-bitcoin libraries are published.
```

### 2. Start ICP Network with Bitcoin Support

```bash
# Start dfx with Bitcoin integration
dfx start --enable-bitcoin --background

# This will:
# - Start the local ICP network
# - Connect to Bitcoin regtest node at 127.0.0.1:18444
# - Deploy Bitcoin API adapter canister
```

### 3. Create Canisters

```bash
# Create ic_siwb_provider canister first (if deploying locally)
dfx canister create ic_siwb_provider --specified-id be2us-64aaa-aaaaa-qaabq-cai

# Create all other canisters
dfx canister create --all

# Verify canisters were created
dfx canister id ic_siwb_provider
dfx canister id rewards_canister
dfx canister id lending_canister
dfx canister id portfolio_canister
dfx canister id swap_canister
```

### 3.1. Deploy Sign-in with Bitcoin Provider

```bash
# Deploy ic_siwb_provider canister with configuration
dfx deploy ic_siwb_provider --argument $'(
  record {
    domain = "127.0.0.1";
    uri = "http://127.0.0.1:5173";
    salt = "123456";
    network = opt "testnet";
    scheme = opt "http";
    statement = opt "Login to BitRewards Platform";
    sign_in_expires_in = opt 1500000000000;
    session_expires_in = opt 604800000000000;
    targets = null;
  }
)'

# For production (mainnet), update domain and uri accordingly
```

### 4. Build Canisters

```bash
# Build all Motoko canisters
dfx build rewards_canister
dfx build lending_canister
dfx build portfolio_canister
dfx build swap_canister

# Or build all at once
dfx build
```

### 5. Deploy Canisters

```bash
# Deploy all canisters
dfx deploy

# Or deploy individually
dfx deploy rewards_canister
dfx deploy lending_canister
dfx deploy portfolio_canister
dfx deploy swap_canister
```

### 6. Initialize Canisters

```bash
# Initialize lending canister with default assets
dfx canister call lending_canister init

# Initialize swap canister with default pools
dfx canister call swap_canister init

# Add initial stores to rewards canister (example)
dfx canister call rewards_canister addStore '(
  record {
    name = "Amazon";
    reward = 5.0;
    logo = "https://example.com/amazon.png";
    url = opt "https://amazon.com";
  }
)'
```

### 7. Verify Deployment

```bash
# Check canister status
dfx canister status rewards_canister
dfx canister status lending_canister
dfx canister status portfolio_canister
dfx canister status swap_canister

# Query canister info
dfx canister info rewards_canister
```

## Canister Interactions

### Rewards Canister

```bash
# Get all stores
dfx canister call rewards_canister getStores

# Track a purchase (requires authentication)
dfx canister call rewards_canister trackPurchase '(1, 1000)'

# Get user rewards
dfx canister call rewards_canister getUserRewards '(
  principal "your-principal-here"
)'

# Claim rewards (will create Bitcoin transaction when fully implemented)
dfx canister call rewards_canister claimRewards
```

### Lending Canister

```bash
# Get lending assets
dfx canister call lending_canister getLendingAssets

# Deposit assets
dfx canister call lending_canister deposit '("BTC", 1000000)'

# Get user deposits
dfx canister call lending_canister getUserDeposits '(
  principal "your-principal-here"
)'

# Withdraw assets
dfx canister call lending_canister withdraw '("BTC", 500000, "bc1q...")'
```

### Portfolio Canister

```bash
# Get user portfolio
dfx canister call portfolio_canister getPortfolio '(
  principal "your-principal-here"
)'

# Get balance for specific asset
dfx canister call portfolio_canister getBalance '(
  principal "your-principal-here",
  "BTC"
)'
```

### Swap Canister

```bash
# Get all swap pools
dfx canister call swap_canister getPools

# Get swap quote for a pool
dfx canister call swap_canister getQuote '(
  "ckBTC_ICP",
  10_000_000
)'

# Execute a swap
dfx canister call swap_canister swap '(
  "ckBTC_ICP",
  variant { ckBTC },
  10_000_000,
  59_000_000
)'

# Get ckBTC balance
dfx canister call swap_canister getCKBTCBalance '(
  principal "your-principal-here"
)'

# Get Bitcoin address for ckBTC deposit
dfx canister call swap_canister getBTCAddress '(
  principal "your-principal-here"
)'

# Check balance update
dfx canister call swap_canister updateBalance

# Get swap history
dfx canister call swap_canister getSwapHistory '(
  principal "your-principal-here"
)'
```

## Frontend Deployment

### Development Mode

```bash
# Install frontend dependencies
npm install

# Start development server
npm run dev

# The app will be available at http://localhost:5173
```

### Production Build

```bash
# Build frontend
npm run build

# Deploy frontend to ICP
dfx deploy shopping_rewards_frontend

# Get frontend canister URL
dfx canister id shopping_rewards_frontend
# Visit: http://<canister-id>.ic0.app or http://localhost:4943?canisterId=<canister-id>
```

## Bitcoin Integration Status

### Current Implementation

✅ **Canister Infrastructure**
- Canister structure and Candid interfaces defined for all 4 canisters
- State management for rewards, lending, portfolio, and swap
- Basic cross-canister communication

✅ **Swap Canister**
- Chain-Key Token support (ckBTC, ckETH, ICP)
- Automated Market Maker (AMM) pools
- Real-time price quotes with slippage protection
- Swap execution and history tracking
- ckBTC deposit/withdrawal interfaces (placeholder)

✅ **Bitcoin Utilities (Stubs)**
- Placeholder implementations for address generation
- Validation functions
- Hex conversion utilities

⚠️ **Pending Bitcoin Library Integration**
- Full motoko-bitcoin library integration
- Real address generation (P2PKH, P2SH, P2WPKH, P2TR)
- ECDSA signing and verification
- Complete ckBTC minter integration
- BIP32 key derivation
- ICP Bitcoin API integration
- Transaction building and broadcasting

### Next Steps for Full Bitcoin Integration

1. **Install Bitcoin Libraries**
   ```bash
   # Once libraries are published, add them via mops
   mops add motoko-bitcoin
   ```

2. **Update BitcoinUtils.mo**
   - Replace stub implementations with real cryptographic functions
   - Implement complete address generation
   - Add transaction signing logic

3. **Implement ICP Bitcoin API Integration**
   - Add Bitcoin API actor references
   - Implement UTXO fetching
   - Add transaction broadcast functionality
   - Implement balance checking

4. **Test Bitcoin Functionality**
   - Test address generation on regtest
   - Validate transactions
   - Test reward claiming with real Bitcoin transactions

## Troubleshooting

### Issue: Canister build fails

**Solution**: Check that all imports are correct and Bitcoin libraries are properly installed.
```bash
dfx build --verbose rewards_canister
```

### Issue: Bitcoin node not connecting

**Solution**: Verify Bitcoin node is running and accessible.
```bash
# Check if bitcoind is running
ps aux | grep bitcoind

# Check Bitcoin RPC connection
bitcoin-cli -conf=$(pwd)/bitcoin_data/bitcoin.conf getblockchaininfo
```

### Issue: DFX start fails

**Solution**: Kill existing dfx processes and restart.
```bash
pkill dfx
rm -rf .dfx
dfx start --enable-bitcoin --background
```

### Issue: Cannot deploy canisters

**Solution**: Ensure local network is running and canisters were created.
```bash
dfx ping
dfx canister create --all
dfx deploy
```

## Security Considerations

1. **Private Keys**: Never store private keys in canister code. Use secure key derivation.
2. **Admin Controls**: Implement proper admin checks before adding stores.
3. **Authentication**: Add proper authentication for all user-facing operations.
4. **Validation**: Always validate Bitcoin addresses before transactions.
5. **Testing**: Thoroughly test on regtest before mainnet deployment.

## Resources

- [ICP Bitcoin Integration Docs](https://internetcomputer.org/docs/current/developer-docs/integrations/bitcoin/)
- [Motoko Language Reference](https://internetcomputer.org/docs/current/references/motoko-ref/)
- [mops Package Manager](https://mops.one/)
- [dfx CLI Reference](https://internetcomputer.org/docs/current/references/cli-reference/)

## Project Structure

```
reimagined-octo-couscous/
├── src/
│   ├── canisters/
│   │   ├── rewards/
│   │   │   ├── main.mo          # Rewards canister logic
│   │   │   ├── rewards.did      # Candid interface
│   │   │   └── Types.mo         # Type definitions
│   │   ├── lending/
│   │   │   ├── main.mo          # Lending canister logic
│   │   │   ├── lending.did      # Candid interface
│   │   │   └── Types.mo         # Type definitions
│   │   ├── portfolio/
│   │   │   ├── main.mo          # Portfolio canister logic
│   │   │   └── portfolio.did    # Candid interface
│   │   └── shared/
│   │       ├── BitcoinUtils.mo  # Bitcoin utilities (full)
│   │       ├── BitcoinUtilsStub.mo # Bitcoin utilities (stubs)
│   │       └── Types.mo         # Shared types
│   ├── components/              # React components
│   ├── hooks/                   # React hooks
│   └── services/                # ICP services
├── bitcoin_data/                # Bitcoin regtest data
├── dfx.json                     # DFX configuration
├── mop.json                     # Mops dependencies
└── README.md                    # Project documentation
```

## Support

For issues or questions:
1. Check the logs: `dfx canister logs <canister-name>`
2. Review canister status: `dfx canister status <canister-name>`
3. Consult ICP documentation
4. Open an issue in the project repository

