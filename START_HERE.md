# 🚀 Quick Start Guide

Follow these steps to get your ICP Shopping Rewards Platform running locally.

## Prerequisites Check ✅

- ✅ Bitcoin Core v30.0.0 - **Running**
- ✅ dfx 0.29.2 - **Installed**
- ✅ Node.js v22.18.0 - **Installed**
- ✅ npm dependencies - **Installed**
- ✅ .env file - **Exists**

## Step-by-Step Startup

### 1. Start Bitcoin Node (if not running)

Bitcoin appears to already be running! If you need to restart it:

```bash
# Stop Bitcoin (if needed)
npm run bitcoin:stop

# Start Bitcoin
npm run bitcoin:start

# Check status
npm run bitcoin:status
```

### 2. Start ICP Network (dfx)

```bash
# Start dfx with Bitcoin support in the background
dfx start --enable-bitcoin --background

# Wait a few seconds, then verify it's running
dfx ping
```

**Expected output:** `"ic_api_version": ...`

### 3. Deploy Canisters (Optional - for Backend Features)

If you want to use the backend canisters (rewards, lending, portfolio, swap):

```bash
# Create canisters
dfx canister create --all

# Deploy all canisters
dfx deploy

# Initialize canisters
dfx canister call lending_canister init
dfx canister call swap_canister init
```

**Note:** You can skip this step if you just want to see the frontend UI with mock data.

### 4. Start Development Server

```bash
# Start Vite dev server
npm run dev
```

The application will be available at: **http://localhost:5173**

## Quick Commands Reference

```bash
# Start everything (one-time setup)
dfx start --enable-bitcoin --background
npm run dev

# Stop everything
dfx stop
npm run bitcoin:stop
pkill -f "vite"

# Check status
dfx ping
npm run bitcoin:status
```

## Troubleshooting

### If dfx won't start:
```bash
# Kill any existing processes
pkill -f "pocket-ic"
pkill -f "dfx start"
dfx stop

# Start fresh
dfx start --enable-bitcoin --background
```

### If Bitcoin connection fails:
```bash
# Check if Bitcoin is running
ps aux | grep bitcoind

# Restart Bitcoin
npm run bitcoin:stop
npm run bitcoin:start
```

### If you see PocketIC errors:
See `TROUBLESHOOTING.md` for detailed solutions.

## Next Steps

1. Open http://localhost:5173 in your browser
2. Try connecting with a Bitcoin wallet (if implemented)
3. Explore the different views: Shop, Lend, Portfolio, Swap

## Development Workflow

**Terminal 1:** Keep dfx running
```bash
dfx start --enable-bitcoin
```

**Terminal 2:** Run the dev server
```bash
npm run dev
```

**Terminal 3:** Deploy canisters when needed
```bash
dfx deploy
```

---

For detailed deployment instructions, see `DEPLOYMENT.md`
For troubleshooting, see `TROUBLESHOOTING.md`

