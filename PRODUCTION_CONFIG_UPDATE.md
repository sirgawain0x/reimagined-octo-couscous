# Production Configuration Update Guide

## Overview

This guide provides step-by-step instructions to update your application configurations for production (mainnet) deployment.

**Status:** ⚠️ **REQUIRED BEFORE MAINNET DEPLOYMENT**

---

## 1. Update Network Configurations in Canisters

### 1.1 Update Swap Canister (ckBTC Configuration)

**File:** `src/canisters/swap/main.mo`  
**Line:** 40  
**Current:** `private let USE_TESTNET : Bool = true;`  
**Required:** `private let USE_TESTNET : Bool = false;`

**Change:**
```motoko
// Network configuration (should be set from environment or canister argument)
// Set to true for testnet deployment, false for mainnet
private let USE_TESTNET : Bool = false; // Changed to false for mainnet deployment
```

**Impact:** This configures the swap canister to use mainnet ckBTC ledger and minter canisters:
- Mainnet Ledger: `mxzaz-hqaaa-aaaah-aaada-cai`
- Mainnet Minter: `mqygn-kiaaa-aaaah-aaaqaa-cai`

**Warning:** Only change this after thoroughly testing with testnet ckBTC services.

---

### 1.2 Update Lending Canister (Bitcoin Network)

**File:** `src/canisters/lending/main.mo`  
**Line:** 74  
**Current:** `private let BTC_NETWORK : BitcoinApi.Network = #Testnet;`  
**Required:** `private let BTC_NETWORK : BitcoinApi.Network = #Mainnet;`

**Change:**
```motoko
// Bitcoin API integration
private let BTC_API_ENABLED : Bool = true; // Enable for mainnet
private let BTC_NETWORK : BitcoinApi.Network = #Mainnet; // Changed to #Mainnet
```

**Impact:** 
- Bitcoin address generation will use mainnet addresses
- UTXO queries will query Bitcoin mainnet
- Transaction broadcasts will go to Bitcoin mainnet
- Minimum confirmations will be 6 (instead of 1 for testnet)

**Warning:** Only change this when you're ready to use real Bitcoin on mainnet.

---

### 1.3 Update Rewards Canister (Bitcoin Network)

**File:** `src/canisters/rewards/main.mo`  
**Line:** 63  
**Current:** `private let BTC_NETWORK : BitcoinApi.Network = #Testnet;`  
**Required:** `private let BTC_NETWORK : BitcoinApi.Network = #Mainnet;`

**Change:**
```motoko
// Bitcoin API integration
private transient let BTC_API_ENABLED : Bool = true; // Enable for mainnet
private let BTC_NETWORK : BitcoinApi.Network = #Mainnet; // Changed to #Mainnet
```

**Impact:**
- Reward claim transactions will use Bitcoin mainnet
- Address generation will use mainnet addresses
- Transaction broadcasts will go to Bitcoin mainnet

**Warning:** Only change this when you're ready to process real Bitcoin rewards.

---

## 2. Update Environment Variables

### 2.1 Update `.env` File

**File:** `.env` (in project root)

**Required Changes:**

```env
# ICP Network - REQUIRED for production mainnet deployment
VITE_ICP_NETWORK=ic
DFX_NETWORK=ic

# Internet Identity URL - REQUIRED for production mainnet deployment
VITE_INTERNET_IDENTITY_URL=https://identity.ic0.app

# Update Bitcoin network if using Validation Cloud
VITE_BITCOIN_NETWORK=mainnet

# Canister IDs (will be populated after deployment)
# After deploying, run: dfx canister --network ic id <canister_name>
VITE_CANISTER_ID_REWARDS=<populate-after-deployment>
VITE_CANISTER_ID_LENDING=<populate-after-deployment>
VITE_CANISTER_ID_PORTFOLIO=<populate-after-deployment>
VITE_CANISTER_ID_SWAP=<populate-after-deployment>

# IC SIWB Provider (already configured for mainnet)
VITE_CANISTER_ID_IC_SIWB_PROVIDER=be2us-64aaa-aaaaa-qaabq-cai
```

### 2.2 Verify Environment Variables After Deployment

After deploying canisters, update the `.env` file with actual canister IDs:

```bash
# Get canister IDs from mainnet deployment
dfx canister --network ic id rewards_canister
dfx canister --network ic id lending_canister
dfx canister --network ic id portfolio_canister
dfx canister --network ic id swap_canister
dfx canister --network ic id shopping_rewards_frontend

# Update .env file with the actual IDs
```

---

## 3. Verify Cycles Balance

Before deployment, verify you have sufficient cycles:

```bash
# Check cycles balance on mainnet
dfx wallet --network ic balance

# Expected output: Should show 10+ T cycles (trillion cycles)
# Minimum recommended: 5 T cycles
# Current: 10 T cycles (✅ Sufficient)
```

**Note:** If the `dfx wallet` command fails with `ColorOutOfRange` error, this is a known dfx bug. You can verify cycles balance via the NNS frontend or use a different terminal.

---

## 4. Deployment Strategy Options

### Option A: Full Production (Bitcoin Mainnet + ckBTC Mainnet)

**When to Use:** When you're ready for full production with real Bitcoin.

**Steps:**
1. Update all network configurations to mainnet (as described above)
2. Deploy to ICP mainnet
3. Initialize canisters
4. Test with small amounts first

**Requirements:**
- Thorough testing completed
- Bitcoin functionality validated on testnet
- All configurations verified

### Option B: Staged Production (Bitcoin Testnet + ckBTC Testnet on ICP Mainnet)

**When to Use:** When you want to test on real ICP infrastructure but use test Bitcoin.

**Steps:**
1. Keep network configurations as testnet (don't change them)
2. Deploy to ICP mainnet
3. Test with Bitcoin testnet and ckBTC testnet services
4. Switch to mainnet configurations after validation

**Benefits:**
- Test on real ICP infrastructure
- Avoid costs associated with real Bitcoin
- Gradual transition to full production

**Recommendation:** Start with Option B, then switch to Option A after validation.

---

## 5. Configuration Verification Checklist

Before deploying to mainnet, verify:

- [ ] Swap canister: `USE_TESTNET` set to `false` (for Option A) or `true` (for Option B)
- [ ] Lending canister: `BTC_NETWORK` set to `#Mainnet` (for Option A) or `#Testnet` (for Option B)
- [ ] Rewards canister: `BTC_NETWORK` set to `#Mainnet` (for Option A) or `#Testnet` (for Option B)
- [ ] `.env` file: `VITE_ICP_NETWORK=ic`
- [ ] `.env` file: `VITE_INTERNET_IDENTITY_URL=https://identity.ic0.app`
- [ ] Cycles balance verified (10 T cycles available)
- [ ] Canister IDs updated in `.env` after deployment (if redeploying)

---

## 6. After Deployment

### 6.1 Initialize Canisters

After successful deployment:

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

### 6.2 Verify Deployment

```bash
# Check canister status
dfx canister --network ic status rewards_canister
dfx canister --network ic status lending_canister
dfx canister --network ic status portfolio_canister
dfx canister --network ic status swap_canister
dfx canister --network ic status shopping_rewards_frontend

# Get canister IDs
dfx canister --network ic id shopping_rewards_frontend
# Access at: https://<canister-id>.ic0.app
```

---

## 7. Important Notes

### Security Considerations

1. **Private Keys:** Never store private keys in canister code (you're using ICP system APIs ✅)
2. **Admin Controls:** Ensure admin authentication is properly configured
3. **Rate Limiting:** Already implemented in all canisters ✅
4. **Input Validation:** Already implemented in all canisters ✅

### Testing Recommendations

1. **Start Small:** Test with small amounts before full deployment
2. **Monitor Closely:** Watch canister logs during initial operations
3. **Gradual Rollout:** Consider staged deployment (Option B first)
4. **User Testing:** Test critical flows with real users before public launch

### Rollback Plan

If issues occur after deployment:

1. **Canister Upgrades:** Use `dfx canister --network ic install --mode upgrade`
2. **Configuration Changes:** Update canister code and redeploy
3. **Data Preservation:** Canisters use persistent actors, so data persists across upgrades

---

## 8. Quick Reference: Network Configuration Matrix

| Component | Testnet Config | Mainnet Config | File |
|-----------|---------------|----------------|------|
| **Swap Canister** | `USE_TESTNET = true` | `USE_TESTNET = false` | `swap/main.mo:40` |
| **Lending Canister** | `BTC_NETWORK = #Testnet` | `BTC_NETWORK = #Mainnet` | `lending/main.mo:74` |
| **Rewards Canister** | `BTC_NETWORK = #Testnet` | `BTC_NETWORK = #Mainnet` | `rewards/main.mo:63` |
| **Environment** | `VITE_ICP_NETWORK=local` | `VITE_ICP_NETWORK=ic` | `.env` |
| **Internet Identity** | Local deployment | `https://identity.ic0.app` | `.env` |
| **Bitcoin Network** | `VITE_BITCOIN_NETWORK=testnet` | `VITE_BITCOIN_NETWORK=mainnet` | `.env` |

---

## 9. Next Steps

1. ✅ **Build Error Fixed** - Frontend builds successfully
2. ⚠️ **Update Network Configurations** - Follow steps 1.1-1.3 above
3. ⚠️ **Update Environment Variables** - Follow step 2 above
4. ✅ **Verify Cycles Balance** - Already verified (10 T cycles)
5. ⚠️ **Deploy to Mainnet** - Use `./deploy-mainnet.sh` or manual deployment
6. ⚠️ **Initialize Canisters** - Follow step 6.1 above
7. ⚠️ **Verify Deployment** - Follow step 6.2 above

---

**Last Updated:** $(date)  
**Status:** Ready for configuration updates  
**Estimated Time:** 10-15 minutes for configuration updates

