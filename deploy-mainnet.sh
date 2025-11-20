#!/bin/bash

# Mainnet Deployment Script
# This script deploys the application to ICP mainnet
# Note: ICP has no free testnet - this deploys to mainnet which requires cycles

# Don't exit on error - we'll handle errors individually
set +e

echo "🚀 Starting mainnet deployment..."
echo "⚠️  Note: This deploys to ICP mainnet, which requires cycles (costs ICP)"
echo "   ICP has no free testnet - only local (free) and mainnet (requires cycles)"
echo ""

# Check if using correct identity
CURRENT_IDENTITY=$(dfx identity whoami)
echo "Current identity: $CURRENT_IDENTITY"

if [ "$CURRENT_IDENTITY" = "default" ]; then
    echo "⚠️  Warning: Using default identity. For better security, consider creating a new identity:"
    echo "   dfx identity new mainnet-deploy"
    echo ""
    read -p "Continue with default identity? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    export DFX_WARNING=-mainnet_plaintext_identity
fi

# Create canisters first (required before building/deploying)
echo "📝 Creating canisters on mainnet..."
echo "  - Creating rewards_canister..."
dfx canister --network ic create rewards_canister 2>/dev/null || echo "  ℹ️  rewards_canister already exists"

echo "  - Creating lending_canister..."
dfx canister --network ic create lending_canister 2>/dev/null || echo "  ℹ️  lending_canister already exists"

echo "  - Creating portfolio_canister..."
dfx canister --network ic create portfolio_canister 2>/dev/null || echo "  ℹ️  portfolio_canister already exists"

echo "  - Creating swap_canister..."
dfx canister --network ic create swap_canister 2>/dev/null || echo "  ℹ️  swap_canister already exists"

echo "  - Creating shopping_rewards_frontend..."
dfx canister --network ic create shopping_rewards_frontend 2>/dev/null || echo "  ℹ️  shopping_rewards_frontend already exists"

# Check cycles balance before building
echo "🔋 Checking cycles balance..."
echo "  ℹ️  Note: You need at least 2-3 T cycles to deploy all canisters"
echo "  ℹ️  If deployment fails with 'Insufficient cycles', run: ./get-cycles.sh"
echo ""

# Build canisters (build for the ic network to use correct canister IDs)
echo "📦 Building canisters for mainnet..."
# Build for the ic network so it uses the correct canister IDs
if dfx build --network ic 2>&1; then
    echo "  ✅ Build successful"
else
    echo "  ⚠️  Build had warnings/errors, but continuing with deployment..."
    echo "  ℹ️  Some build errors are normal if canisters aren't fully set up yet"
fi

# Deploy canisters one by one to avoid issues
echo "🚀 Deploying canisters to mainnet..."

DEPLOYMENT_ERRORS=0

echo "  - Deploying rewards_canister..."
if dfx deploy --network ic rewards_canister 2>&1 | tee /tmp/rewards-deploy.log; then
    echo "  ✅ rewards_canister deployed successfully"
else
    ERROR_MSG=$(cat /tmp/rewards-deploy.log 2>/dev/null | grep -i "insufficient\|cycles" || echo "")
    if [[ "$ERROR_MSG" == *"Insufficient"* ]] || [[ "$ERROR_MSG" == *"cycles"* ]]; then
        echo "  ❌ Failed: Insufficient cycles. Run ./get-cycles.sh for help"
    else
        echo "  ⚠️  Failed to deploy rewards_canister"
    fi
    DEPLOYMENT_ERRORS=$((DEPLOYMENT_ERRORS + 1))
fi

echo "  - Deploying lending_canister..."
if dfx deploy --network ic lending_canister; then
    echo "  ✅ lending_canister deployed successfully"
else
    echo "  ⚠️  Failed to deploy lending_canister"
    DEPLOYMENT_ERRORS=$((DEPLOYMENT_ERRORS + 1))
fi

echo "  - Deploying portfolio_canister..."
if dfx deploy --network ic portfolio_canister; then
    echo "  ✅ portfolio_canister deployed successfully"
else
    echo "  ⚠️  Failed to deploy portfolio_canister"
    DEPLOYMENT_ERRORS=$((DEPLOYMENT_ERRORS + 1))
fi

echo "  - Deploying swap_canister..."
if dfx deploy --network ic swap_canister; then
    echo "  ✅ swap_canister deployed successfully"
else
    echo "  ⚠️  Failed to deploy swap_canister"
    DEPLOYMENT_ERRORS=$((DEPLOYMENT_ERRORS + 1))
fi

echo "  - Building frontend..."
if npm run build; then
    echo "  ✅ Frontend built successfully"
else
    echo "  ⚠️  Failed to build frontend"
    DEPLOYMENT_ERRORS=$((DEPLOYMENT_ERRORS + 1))
fi

echo "  - Deploying shopping_rewards_frontend..."
if dfx deploy --network ic shopping_rewards_frontend; then
    echo "  ✅ shopping_rewards_frontend deployed successfully"
else
    echo "  ⚠️  Failed to deploy shopping_rewards_frontend"
    DEPLOYMENT_ERRORS=$((DEPLOYMENT_ERRORS + 1))
fi

# Get canister IDs
echo ""
echo "📋 Canister IDs:"
echo "REWARDS_CANISTER_ID=$(dfx canister --network ic id rewards_canister 2>/dev/null || echo 'NOT_DEPLOYED')"
echo "LENDING_CANISTER_ID=$(dfx canister --network ic id lending_canister 2>/dev/null || echo 'NOT_DEPLOYED')"
echo "PORTFOLIO_CANISTER_ID=$(dfx canister --network ic id portfolio_canister 2>/dev/null || echo 'NOT_DEPLOYED')"
echo "SWAP_CANISTER_ID=$(dfx canister --network ic id swap_canister 2>/dev/null || echo 'NOT_DEPLOYED')"
echo "FRONTEND_CANISTER_ID=$(dfx canister --network ic id shopping_rewards_frontend 2>/dev/null || echo 'NOT_DEPLOYED')"

echo ""
if [ $DEPLOYMENT_ERRORS -eq 0 ]; then
    echo "✅ Deployment complete! All canisters deployed successfully."
else
    echo "⚠️  Deployment completed with $DEPLOYMENT_ERRORS error(s). Please review the output above."
fi
echo ""
echo "Next steps:"
echo "1. Update your .env file with the canister IDs above"
echo "2. Initialize canisters:"
echo "   dfx canister --network ic call lending_canister init"
echo "   dfx canister --network ic call swap_canister init"
echo "3. Access your app at: https://<FRONTEND_CANISTER_ID>.ic0.app"

