# Bitcoin/ckBTC Testnet Configuration Guide

## Important: Understanding "Testnet" in This Project

**ICP has NO free testnet.** ICP only has:
- **Local** - Free, runs on your machine
- **Mainnet** - Requires cycles (costs ICP)

The "testnet" references in this guide refer to:
- **Bitcoin testnet** - A separate Bitcoin network for testing (not related to ICP network)
- **ckBTC testnet services** - Testnet versions of ckBTC canisters (not related to ICP network)

You can deploy to **ICP mainnet** while using **Bitcoin testnet** and **ckBTC testnet services** for testing. This allows you to:
- Test on real ICP infrastructure
- Avoid using real Bitcoin during testing
- Test Bitcoin functionality safely

## When to Use Bitcoin/ckBTC Testnet

Use Bitcoin testnet and ckBTC testnet services when:
- You want to test Bitcoin functionality without using real Bitcoin
- You're deploying to ICP mainnet but still in testing phase
- You want to avoid costs associated with Bitcoin mainnet transactions

Switch to Bitcoin mainnet and ckBTC mainnet when:
- You're ready for full production
- You need real Bitcoin transactions
- You're confident in your implementation

## Configuration for Bitcoin/ckBTC Testnet

### 1. Update Canister Code

Configure your canisters to use Bitcoin testnet and ckBTC testnet services:

**File: `src/canisters/rewards/main.mo` (line 63)**
```motoko
private let BTC_NETWORK : BitcoinApi.Network = #Testnet;  // Use Bitcoin testnet
```

**File: `src/canisters/lending/main.mo` (line 74)**
```motoko
private let BTC_NETWORK : BitcoinApi.Network = #Testnet;  // Use Bitcoin testnet
```

**File: `src/canisters/swap/main.mo` (line 40)**
```motoko
private let USE_TESTNET : Bool = true;  // Use ckBTC testnet services
```

### 2. Configure Environment Variables

Update your `.env` file:

```env
# ICP Network - use "ic" for mainnet deployment
VITE_ICP_NETWORK=ic

# Internet Identity
VITE_INTERNET_IDENTITY_URL=https://identity.ic0.app

# Bitcoin Network (for Validation Cloud queries)
VITE_BITCOIN_NETWORK=testnet

# Validation Cloud (optional)
VITE_VALIDATION_CLOUD_API_KEY=your_api_key_here
```

### 3. Deploy to ICP Mainnet

Even though you're using Bitcoin testnet, you still deploy to ICP mainnet:

```bash
# Deploy to ICP mainnet (requires cycles)
dfx deploy --network ic

# Or use the deployment script
./deploy-mainnet.sh
```

**Note:** This deploys to ICP mainnet, which requires cycles. There is no free ICP testnet.

## ckBTC Testnet Services

When `USE_TESTNET = true`, the swap canister uses testnet ckBTC canisters:

- **Testnet Ledger**: `n5wcd-faaaa-aaaar-qaaea-cai`
- **Testnet Minter**: `nfvlz-3qaaa-aaaar-qaanq-cai`

These are separate from the ICP network - they're testnet versions of the ckBTC services.

## Bitcoin Testnet via ICP

Your canisters interact with Bitcoin testnet through ICP's Bitcoin API. This means:
- No local Bitcoin node needed
- Canisters can query Bitcoin testnet blockchain
- Canisters can send transactions to Bitcoin testnet
- All via ICP's Bitcoin integration

## Switching to Production (Bitcoin Mainnet)

When ready for production:

1. **Update canister code:**
   ```motoko
   private let BTC_NETWORK : BitcoinApi.Network = #Mainnet;
   private let USE_TESTNET : Bool = false;
   ```

2. **Update environment:**
   ```env
   VITE_BITCOIN_NETWORK=mainnet
   ```

3. **Redeploy canisters:**
   ```bash
   dfx deploy --network ic
   ```

## Deployment Options Summary

| ICP Network | Bitcoin Network | ckBTC Services | Cost | Use Case |
|------------|----------------|----------------|------|----------|
| Local | Regtest | N/A | Free | Local development |
| Mainnet | Testnet | Testnet | Requires cycles | Testing on real ICP |
| Mainnet | Mainnet | Mainnet | Requires cycles | Full production |

## Important Notes

1. **ICP Mainnet Always Requires Cycles**: Whether you use Bitcoin testnet or mainnet, deploying to ICP mainnet requires cycles.

2. **Bitcoin Testnet is Free**: Using Bitcoin testnet doesn't cost anything, but you still need cycles for ICP mainnet deployment.

3. **Gradual Migration**: You can start with Bitcoin testnet on ICP mainnet, then switch to Bitcoin mainnet when ready.

4. **No ICP Testnet**: There is no free ICP testnet. Your options are local (free) or mainnet (requires cycles).

## See Also

- `MAINNET_DEPLOYMENT.md` - Complete guide for deploying to ICP mainnet
- `DEPLOYMENT.md` - General deployment information
- `QUICK_FIX_CYCLES.md` - How to get cycles for mainnet deployment
