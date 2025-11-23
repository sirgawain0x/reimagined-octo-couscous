# How to Send ICP to Your DFX Wallet

This guide explains how to send ICP to your DFX wallet so you can convert it to cycles for deployment.

## Quick Steps

1. **Get your wallet address** (see below)
2. **Send ICP from an exchange or another wallet** to your DFX wallet address
3. **Convert ICP to cycles** using `dfx cycles convert`

## Method 1: Get Your Wallet Address

### Option A: Using DFX Commands

```bash
# Get your principal (wallet controller)
dfx identity get-principal

# Get your ledger account ID (this is what you send ICP to)
dfx ledger account-id

# Or get the full account identifier
dfx ledger account-id --of-canister <canister-id>
```

### Option B: Using the Helper Script

Run the helper script to get all your wallet information:

```bash
./get-wallet-info.sh
```

## Method 2: Send ICP to Your Wallet

### From an Exchange (Coinbase, Binance, etc.)

1. **Get your account ID** (see Method 1 above)
2. **Copy your account ID** - it looks like: `92c6b10419469507da05c24644e54a474aab97810b787e0d057ee15e30d07244`
3. **In your exchange:**
   - Go to "Withdraw" or "Send"
   - Select ICP (Internet Computer)
   - Paste your account ID as the recipient address
   - Enter the amount you want to send
   - Confirm the transaction

**Important:** 
- Make sure you're sending to the **ICP mainnet** (not a different network)
- Double-check the account ID before sending
- Exchanges may have minimum withdrawal amounts

### From Another Wallet (NNS, Plug, etc.)

1. **Get your account ID** (see Method 1)
2. **In your wallet app:**
   - Select "Send" or "Transfer"
   - Paste your account ID as the recipient
   - Enter the amount
   - Confirm the transaction

### From Another DFX Wallet

If you have ICP in another DFX identity/wallet:

```bash
# Switch to the identity with ICP
dfx identity use <identity-name>

# Send ICP to your deployer wallet's account ID
dfx ledger transfer <account-id> --amount <amount> --memo 0
```

## Method 3: Verify ICP Received

After sending ICP, verify it arrived:

```bash
# Check your ICP balance
dfx ledger --network ic balance

# This should show your ICP balance (not cycles)
```

## Method 4: Convert ICP to Cycles

Once you have ICP in your wallet, convert it to cycles:

```bash
# Convert ICP to cycles (1 ICP ≈ 1 T cycles)
# For 3 remaining canisters, you need ~3-4 T cycles
dfx cycles convert --amount=2.0 --network ic

# Check cycles balance
dfx wallet --network ic balance
```

**Conversion Rate:** Approximately 1 ICP = 1 T (trillion) cycles

## Your Current Wallet Information

Based on your current identity:

- **Principal:** `nagta-do5ig-32qbx-pfkii-cggj2-c6ygr-qlkcc-emi2q-yq75u-ffz54-bae`
- **Account ID:** `92c6b10419469507da05c24644e54a474aab97810b787e0d057ee15e30d07244`

**To receive ICP, send it to your Account ID:** `92c6b10419469507da05c24644e54a474aab97810b787e0d057ee15e30d07244`

## Troubleshooting

### "Cannot find wallet"

If you get this error, create a wallet first:

```bash
dfx wallet --network ic create
```

### "Insufficient balance" when converting

- Wait a few minutes for the ICP transaction to confirm
- Check your ICP balance: `dfx ledger --network ic balance`
- Make sure you sent ICP to the correct account ID

### "Account ID not found"

- Verify you're using the correct account ID
- Make sure you're on the ICP mainnet (not a testnet)
- Check that the transaction was sent to the ICP network

## Quick Reference

```bash
# Get wallet info
dfx identity get-principal
dfx ledger account-id

# Check balances
dfx ledger --network ic balance        # ICP balance
dfx wallet --network ic balance         # Cycles balance

# Convert ICP to cycles
dfx cycles convert --amount=2.0 --network ic

# Deploy (after getting cycles)
./deploy-with-cycle-check.sh
```

## Recommended Amount

For your 3 remaining canisters:
- **Minimum:** 3 T cycles (3 ICP)
- **Recommended:** 4-5 T cycles (4-5 ICP) for safety

Send at least **4-5 ICP** to your wallet to have enough for deployment with a buffer.

