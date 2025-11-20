# Network Options Explained

## ICP Network Options

**ICP has only two deployment environments:**

| Network | Command | Cost | Use Case |
|---------|---------|------|----------|
| **Local** | `dfx start` or `dfx deploy` | Free | Local development and testing |
| **Mainnet** | `dfx deploy --network ic` | Requires cycles (costs ICP) | Production deployment |

**There is NO free ICP testnet.**

## Bitcoin Network Options

Your canisters can interact with different Bitcoin networks via ICP's Bitcoin API:

| Network | Use Case | Cost |
|---------|----------|------|
| **Regtest** | Local Bitcoin node testing | Free (local only) |
| **Testnet** | Bitcoin testnet for testing | Free (but need cycles for ICP mainnet) |
| **Mainnet** | Production Bitcoin transactions | Real Bitcoin costs |

## ckBTC Service Options

The swap canister can use different ckBTC service canisters:

| Service | Ledger ID | Minter ID | Use Case |
|---------|-----------|-----------|----------|
| **Testnet** | `n5wcd-faaaa-aaaar-qaaea-cai` | `nfvlz-3qaaa-aaaar-qaanq-cai` | Testing |
| **Mainnet** | `mxzaz-hqaaa-aaaah-aaada-cai` | `mqygn-kiaaa-aaaah-aaaqaa-cai` | Production |

## Common Deployment Scenarios

### Scenario 1: Local Development (Free)
- **ICP Network**: Local
- **Bitcoin Network**: Regtest (local Bitcoin node)
- **ckBTC Services**: N/A (not available locally)
- **Cost**: Free
- **Command**: `dfx deploy`

### Scenario 2: Testing on Real ICP (Recommended for Testing)
- **ICP Network**: Mainnet (requires cycles)
- **Bitcoin Network**: Testnet
- **ckBTC Services**: Testnet
- **Cost**: ~2-3 ICP for deployment
- **Command**: `dfx deploy --network ic`
- **Why**: Test on real ICP infrastructure without using real Bitcoin

### Scenario 3: Full Production
- **ICP Network**: Mainnet (requires cycles)
- **Bitcoin Network**: Mainnet
- **ckBTC Services**: Mainnet
- **Cost**: ~2-3 ICP for deployment + ongoing cycles
- **Command**: `dfx deploy --network ic`
- **Why**: Full production with real Bitcoin

## Configuration Files

### Canister Code Configuration

**Bitcoin Network** (in `rewards/main.mo` and `lending/main.mo`):
```motoko
private let BTC_NETWORK : BitcoinApi.Network = #Testnet;  // or #Mainnet, #Regtest
```

**ckBTC Services** (in `swap/main.mo`):
```motoko
private let USE_TESTNET : Bool = true;  // or false for mainnet
```

### Environment Variables

**`.env` file:**
```env
# ICP Network
VITE_ICP_NETWORK=ic  # or "local"

# Bitcoin Network (for Validation Cloud)
VITE_BITCOIN_NETWORK=testnet  # or "mainnet"
```

## Key Points to Remember

1. **ICP Mainnet Always Costs**: Whether you use Bitcoin testnet or mainnet, deploying to ICP mainnet requires cycles.

2. **Bitcoin Testnet is Free**: Using Bitcoin testnet doesn't cost Bitcoin, but you still need cycles for ICP mainnet deployment.

3. **No ICP Testnet**: There is no free ICP testnet. Your options are:
   - Local (free) - for development
   - Mainnet (requires cycles) - for production/testing on real infrastructure

4. **Gradual Migration Path**: 
   - Start: Local development
   - Next: Deploy to ICP mainnet with Bitcoin testnet
   - Finally: Switch to Bitcoin mainnet when ready

## Getting Cycles

To deploy to ICP mainnet, you need cycles:

```bash
# Check balance
dfx wallet --network ic balance

# Convert ICP to cycles (1 ICP ≈ 1 T cycles)
dfx cycles convert --amount=2.0 --network ic
```

See `QUICK_FIX_CYCLES.md` for more options.

## Documentation

- `MAINNET_DEPLOYMENT.md` - Complete guide for mainnet deployment
- `TESTNET_DEPLOYMENT.md` - Guide for configuring Bitcoin/ckBTC testnet
- `DEPLOYMENT.md` - General deployment information
- `QUICK_FIX_CYCLES.md` - How to get cycles

