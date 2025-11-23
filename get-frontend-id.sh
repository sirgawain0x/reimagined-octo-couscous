#!/bin/bash

# Helper script to get frontend canister ID
# Uses IC dashboard API since dfx has color output issues

echo "🔍 Finding frontend canister ID..."
echo ""

# Get principal
PRINCIPAL=$(dfx identity get-principal 2>/dev/null || echo "")

if [ -z "$PRINCIPAL" ]; then
    echo "❌ Could not get principal"
    exit 1
fi

echo "📋 Your Principal: $PRINCIPAL"
echo ""

# Method 1: Try to get from IC Dashboard API
echo "Method 1: Checking IC Dashboard API..."
echo "Visit: https://dashboard.internetcomputer.org/canister"
echo "Search for canisters owned by: $PRINCIPAL"
echo ""

# Method 2: Try dfx with different approach
echo "Method 2: Trying dfx commands..."
echo ""

# Try to list all canisters
echo "Listing canisters..."
dfx canister --network ic list 2>&1 | grep -i "shopping\|frontend" || echo "  Could not list canisters"

echo ""
echo "Method 3: Manual check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Since dfx has a color output bug, try these options:"
echo ""
echo "1. Check IC Dashboard:"
echo "   https://dashboard.internetcomputer.org/"
echo "   - Log in with your identity"
echo "   - Look for 'shopping_rewards_frontend' canister"
echo ""
echo "2. Try dfx with RUST_BACKTRACE=0:"
echo "   RUST_BACKTRACE=0 dfx canister --network ic id shopping_rewards_frontend"
echo ""
echo "3. Check if canister responds (if you know the ID):"
echo "   curl https://<canister-id>.ic0.app"
echo ""
echo "4. The canister was created at timestamp: 1763870045665402000"
echo "   You can search for canisters created around that time"
echo ""

