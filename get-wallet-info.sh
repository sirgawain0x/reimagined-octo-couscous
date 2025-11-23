#!/bin/bash

# Wallet Information Script
# Shows your DFX wallet address and instructions for sending ICP

echo "🔐 DFX Wallet Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get current identity
CURRENT_IDENTITY=$(dfx identity whoami 2>/dev/null || echo "unknown")
echo "📋 Current Identity: $CURRENT_IDENTITY"
echo ""

# Get principal
echo "🔑 Getting Principal..."
PRINCIPAL=$(dfx identity get-principal 2>/dev/null || echo "Could not get principal")
echo "  Principal: $PRINCIPAL"
echo ""

# Get account ID (this is what you send ICP to)
echo "💳 Getting Account ID..."
ACCOUNT_ID=$(dfx ledger account-id 2>/dev/null || echo "Could not get account ID")
echo "  Account ID: $ACCOUNT_ID"
echo ""

# Check ICP balance
echo "💰 Checking ICP Balance..."
ICP_BALANCE=$(dfx ledger --network ic balance 2>/dev/null || echo "Could not check balance")
if [[ "$ICP_BALANCE" == *"Could not"* ]]; then
    echo "  ⚠️  Could not retrieve ICP balance"
    echo "  Run manually: dfx ledger --network ic balance"
else
    echo "  ICP Balance: $ICP_BALANCE"
fi
echo ""

# Check cycles balance
echo "🔋 Checking Cycles Balance..."
CYCLES_BALANCE=$(dfx wallet --network ic balance 2>/dev/null || echo "Could not check balance")
if [[ "$CYCLES_BALANCE" == *"Could not"* ]]; then
    echo "  ⚠️  Could not retrieve cycles balance"
    echo "  Run manually: dfx wallet --network ic balance"
else
    echo "  Cycles Balance: $CYCLES_BALANCE"
fi
echo ""

# Instructions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 To Send ICP to This Wallet:"
echo ""
echo "1. Copy your Account ID (above):"
echo "   $ACCOUNT_ID"
echo ""
echo "2. Send ICP from an exchange or wallet to this Account ID"
echo ""
echo "3. After receiving ICP, convert to cycles:"
echo "   dfx cycles convert --amount=2.0 --network ic"
echo ""
echo "4. Check your cycles balance:"
echo "   dfx wallet --network ic balance"
echo ""
echo "5. Deploy your canisters:"
echo "   ./deploy-with-cycle-check.sh"
echo ""

# Show account ID prominently
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 YOUR WALLET ADDRESS (Send ICP here):"
echo ""
echo "   $ACCOUNT_ID"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if wallet exists
if ! dfx wallet --network ic balance >/dev/null 2>&1; then
    echo "⚠️  Wallet may not exist. Create it with:"
    echo "   dfx wallet --network ic create"
    echo ""
fi

