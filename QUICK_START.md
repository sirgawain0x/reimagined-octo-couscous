# Quick Start Guide

## Current Status

### ✅ Bitcoin Node
- **Status**: Running in regtest mode
- **Blocks**: 0 (normal for regtest - blocks are generated manually)
- **Note**: Regtest mode doesn't sync with mainnet. You generate blocks as needed for testing.

### ✅ ICP Network (dfx)
- **Status**: Running on port 4943
- **Bitcoin Support**: Enabled
- **Canisters**: Deployed and running

### ✅ Development Server
- **Port**: 5173 (cleaned up)
- **Status**: Ready to start

## Running the Project

### Option 1: Use the Startup Script (Recommended)
```bash
./start.sh
```

This script will:
1. Check Bitcoin node (start if needed)
2. Check dfx (start if needed)
3. Clean up any existing Vite servers
4. Start the dev server on port 5173 only

### Option 2: Manual Start
```bash
# 1. Ensure dfx is running
dfx start --enable-bitcoin --background

# 2. Clean up ports
./stop-dfx.sh  # This also cleans Vite servers now

# 3. Start dev server
npm run dev
```

## Bitcoin Regtest Notes

### Generate Blocks (if needed for testing)
```bash
bitcoin-cli -conf=$(pwd)/bitcoin_data/bitcoin.conf -datadir=$(pwd)/bitcoin_data generate 101
```

### Check Bitcoin Status
```bash
npm run bitcoin:status
```

### Common Regtest Commands
```bash
# Generate 1 block
bitcoin-cli -conf=$(pwd)/bitcoin_data/bitcoin.conf -datadir=$(pwd)/bitcoin_data generate 1

# Get balance
bitcoin-cli -conf=$(pwd)/bitcoin_data/bitcoin.conf -datadir=$(pwd)/bitcoin_data getbalance

# Get block count
bitcoin-cli -conf=$(pwd)/bitcoin_data/bitcoin.conf -datadir=$(pwd)/bitcoin_data getblockcount
```

## Troubleshooting

### Port 5173/5174 Already in Use
```bash
./stop-dfx.sh  # Stops all dev processes
```

### dfx Port 4943 in Use
```bash
./stop-dfx.sh  # This will free port 4943 too
```

### Verify Services Are Running
```bash
# Check dfx
curl http://localhost:4943/api/v2/status

# Check Vite (should only be one)
lsof -ti:5173,5174

# Check Bitcoin
npm run bitcoin:status
```

## Environment Variables

Make sure your `.env` file has the canister IDs:
```env
VITE_CANISTER_ID_REWARDS=uzt4z-lp777-77774-qaabq-cai
VITE_CANISTER_ID_LENDING=uxrrr-q7777-77774-qaaaq-cai
VITE_CANISTER_ID_PORTFOLIO=u6s2n-gx777-77774-qaaba-cai
VITE_CANISTER_ID_SWAP=ulvla-h7777-77774-qaacq-cai
VITE_ICP_NETWORK=local
```

## Access Points

- **Frontend**: http://localhost:5173
- **dfx Dashboard**: http://localhost:4943
- **Bitcoin RPC**: http://localhost:18443

