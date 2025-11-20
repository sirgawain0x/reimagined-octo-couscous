#!/bin/bash

# Script to help get cycles for mainnet deployment
# Note: ICP has no free testnet - deploying with --network ic requires cycles

echo "🔋 Checking cycles balance for ICP mainnet deployment..."
echo "⚠️  Note: ICP has no free testnet. Deploying with --network ic requires cycles."
echo ""

# Try to get wallet balance (may fail due to dfx bug, but worth trying)
WALLET_ID=$(dfx identity --network ic get-wallet 2>/dev/null | head -1 || echo "")

if [ -z "$WALLET_ID" ]; then
    echo "⚠️  Could not get wallet ID (dfx color bug)."
    echo ""
    echo "To get cycles for testnet, you have a few options:"
    echo ""
    echo "Option 1: Use the cycles faucet (if available)"
    echo "  Visit: https://faucet.dfinity.org/"
    echo ""
    echo "Option 2: Convert ICP to cycles"
    echo "  First, check if you have ICP in your wallet:"
    echo "  dfx ledger --network ic balance"
    echo ""
    echo "  Then convert ICP to cycles:"
    echo "  dfx cycles convert --amount=1.0 --network ic"
    echo ""
    echo "Option 3: Get cycles from your wallet"
    echo "  dfx wallet --network ic balance"
    echo "  dfx wallet --network ic send <wallet-id> --amount 1.0"
    echo ""
    echo "For testnet, you typically need at least 2-3 T cycles (trillion cycles)"
    echo "1 ICP = 1 T cycles approximately"
else
    echo "Wallet ID: $WALLET_ID"
    echo ""
    echo "Checking balance..."
    BALANCE=$(dfx wallet --network ic balance 2>/dev/null || echo "unknown")
    echo "Current balance: $BALANCE"
    echo ""
    
    if [[ "$BALANCE" == *"0.000"* ]] || [[ "$BALANCE" == "unknown" ]]; then
        echo "⚠️  Low or unknown cycles balance. You need to add cycles."
        echo ""
        echo "To add cycles:"
        echo "1. Convert ICP to cycles:"
        echo "   dfx cycles convert --amount=1.0 --network ic"
        echo ""
        echo "2. Or use the cycles faucet:"
        echo "   Visit: https://faucet.dfinity.org/"
    else
        echo "✅ You have cycles available!"
    fi
fi

