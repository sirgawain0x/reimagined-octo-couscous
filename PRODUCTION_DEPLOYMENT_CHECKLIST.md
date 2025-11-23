# Production Deployment Checklist for ICP Mainnet

## Quick Reference: Required Environment Variables

For production on ICP mainnet, set these in your `.env` file:

```env
# REQUIRED: ICP Network Configuration
VITE_ICP_NETWORK=ic
DFX_NETWORK=ic

# REQUIRED: Internet Identity URL
VITE_INTERNET_IDENTITY_URL=https://identity.ic0.app

# OPTIONAL: Bitcoin Network (if using Validation Cloud)
VITE_BITCOIN_NETWORK=mainnet

# REQUIRED: Canister IDs (populate after deployment)
VITE_CANISTER_ID_REWARDS=<populate-after-deployment>
VITE_CANISTER_ID_LENDING=<populate-after-deployment>
VITE_CANISTER_ID_PORTFOLIO=<populate-after-deployment>
VITE_CANISTER_ID_SWAP=<populate-after-deployment>

# ALREADY CONFIGURED: IC SIWB Provider
VITE_CANISTER_ID_IC_SIWB_PROVIDER=be2us-64aaa-aaaaa-qaabq-cai
```

---

## Pre-Deployment Checklist

### ✅ Completed Items

- [x] **Build Error Fixed** - Frontend builds successfully
- [x] **Cycles Balance Verified** - 10 T cycles available (sufficient)
- [x] **Production Readiness Review** - Comprehensive report generated
- [x] **Documentation Created** - Configuration guides available

### ⚠️ Required Before Deployment

#### 1. Network Configuration Updates (5 minutes)

**Status:** ⚠️ **REQUIRED**

Update these 3 canister files if deploying with Bitcoin mainnet:

**Option A: Full Production (Bitcoin Mainnet)**
- [ ] `src/canisters/swap/main.mo:40` - Change `USE_TESTNET = false`
- [ ] `src/canisters/lending/main.mo:74` - Change `BTC_NETWORK = #Mainnet`
- [ ] `src/canisters/rewards/main.mo:63` - Change `BTC_NETWORK = #Mainnet`

**Option B: Staged Production (Bitcoin Testnet on ICP Mainnet) - RECOMMENDED**
- [ ] Keep all network configurations as testnet (no changes needed)
- [ ] This allows testing on ICP mainnet with test Bitcoin

**See:** `PRODUCTION_CONFIG_UPDATE.md` for detailed instructions

#### 2. Environment Variables Setup (5 minutes)

**Status:** ⚠️ **REQUIRED**

- [ ] Update `.env` file with production values:
  ```env
  VITE_ICP_NETWORK=ic
  DFX_NETWORK=ic
  VITE_INTERNET_IDENTITY_URL=https://identity.ic0.app
  ```

- [ ] Set Bitcoin network (if using Validation Cloud):
  ```env
  VITE_BITCOIN_NETWORK=mainnet
  ```

- [ ] Canister IDs will be populated after deployment

#### 3. Verify Cycles Balance (2 minutes)

**Status:** ✅ **Already Verified**

- [x] 10 T cycles available (sufficient for deployment)
- [ ] Manual verification: `dfx wallet --network ic balance`

---

## Deployment Steps

### Step 1: Build Canisters

```bash
# Ensure dependencies are installed
mops install

# Build all canisters for mainnet
dfx build --network ic
```

**Expected:** Successful build with no errors

### Step 2: Create Canisters (if not already created)

```bash
# Create canisters on mainnet
dfx canister --network ic create rewards_canister
dfx canister --network ic create lending_canister
dfx canister --network ic create portfolio_canister
dfx canister --network ic create swap_canister
dfx canister --network ic create shopping_rewards_frontend
```

**Note:** Canisters may already exist - script handles this

### Step 3: Deploy Canisters

```bash
# Option A: Use deployment script
./deploy-mainnet.sh

# Option B: Manual deployment
dfx deploy --network ic
```

**Expected:** Successful deployment of all canisters

### Step 4: Get Canister IDs

```bash
# Get all canister IDs
dfx canister --network ic id rewards_canister
dfx canister --network ic id lending_canister
dfx canister --network ic id portfolio_canister
dfx canister --network ic id swap_canister
dfx canister --network ic id shopping_rewards_frontend
```

**Action:** Update `.env` file with the actual canister IDs

### Step 5: Build Frontend

```bash
# Build frontend for production
npm run build
```

**Expected:** Successful build with all assets generated

### Step 6: Deploy Frontend

```bash
# Deploy frontend canister
dfx deploy --network ic shopping_rewards_frontend
```

**Expected:** Frontend deployed and accessible

---

## Post-Deployment Steps

### Step 1: Initialize Canisters

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

### Step 2: Verify Deployment

```bash
# Check canister status
dfx canister --network ic status rewards_canister
dfx canister --network ic status lending_canister
dfx canister --network ic status portfolio_canister
dfx canister --network ic status swap_canister
dfx canister --network ic status shopping_rewards_frontend

# Get frontend URL
dfx canister --network ic id shopping_rewards_frontend
# Access at: https://<canister-id>.ic0.app
```

### Step 3: Test Critical Flows

- [ ] Test wallet connection
- [ ] Test canister queries (getStores, getPools, etc.)
- [ ] Test authentication flow
- [ ] Monitor canister logs for errors

```bash
# View canister logs
dfx canister --network ic logs rewards_canister
dfx canister --network ic logs lending_canister
```

---

## Environment Variables Summary

### Required for Production Mainnet

| Variable | Value | Description |
|----------|-------|-------------|
| `VITE_ICP_NETWORK` | `ic` | ICP network (mainnet) |
| `DFX_NETWORK` | `ic` | dfx CLI network (mainnet) |
| `VITE_INTERNET_IDENTITY_URL` | `https://identity.ic0.app` | Internet Identity service URL |

### Required After Deployment

| Variable | Value | How to Get |
|----------|-------|------------|
| `VITE_CANISTER_ID_REWARDS` | `<canister-id>` | `dfx canister --network ic id rewards_canister` |
| `VITE_CANISTER_ID_LENDING` | `<canister-id>` | `dfx canister --network ic id lending_canister` |
| `VITE_CANISTER_ID_PORTFOLIO` | `<canister-id>` | `dfx canister --network ic id portfolio_canister` |
| `VITE_CANISTER_ID_SWAP` | `<canister-id>` | `dfx canister --network ic id swap_canister` |

### Optional

| Variable | Value | Description |
|----------|-------|-------------|
| `VITE_BITCOIN_NETWORK` | `mainnet` or `testnet` | For Validation Cloud API |
| `VITE_VALIDATION_CLOUD_API_KEY` | `<api-key>` | Validation Cloud API key |
| `VITE_CANISTER_ID_IC_SIWB_PROVIDER` | `be2us-64aaa-aaaaa-qaabq-cai` | Already configured |

---

## Quick Deployment Command Sequence

```bash
# 1. Set environment variables
export VITE_ICP_NETWORK=ic
export DFX_NETWORK=ic

# 2. Build canisters
dfx build --network ic

# 3. Deploy canisters
dfx deploy --network ic

# 4. Get canister IDs and update .env file
dfx canister --network ic id rewards_canister
dfx canister --network ic id lending_canister
dfx canister --network ic id portfolio_canister
dfx canister --network ic id swap_canister
dfx canister --network ic id shopping_rewards_frontend

# 5. Build frontend
npm run build

# 6. Deploy frontend
dfx deploy --network ic shopping_rewards_frontend

# 7. Initialize canisters
dfx canister --network ic call lending_canister init
dfx canister --network ic call swap_canister init

# 8. Verify deployment
dfx canister --network ic status shopping_rewards_frontend
```

---

## Troubleshooting

### Issue: Build fails

**Solution:** Ensure dependencies are installed:
```bash
mops install
npm install
```

### Issue: Deployment fails with "Insufficient cycles"

**Solution:** Verify cycles balance:
```bash
dfx wallet --network ic balance
```

You have 10 T cycles available, which is sufficient.

### Issue: Canister already exists

**Solution:** This is normal if canisters were previously created. The deployment script handles this.

### Issue: ColorOutOfRange error with dfx

**Solution:** This is a known dfx bug. Use a different terminal or update dfx.

---

## Verification

After deployment, verify:

- [ ] All canisters deployed successfully
- [ ] Frontend accessible at `https://<canister-id>.ic0.app`
- [ ] Canister IDs updated in `.env` file
- [ ] Canisters initialized successfully
- [ ] No errors in canister logs
- [ ] Critical user flows working

---

**Last Updated:** $(date)  
**Status:** Ready for deployment  
**Estimated Time:** 45-60 minutes

