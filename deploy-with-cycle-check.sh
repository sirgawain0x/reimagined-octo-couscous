#!/bin/bash

# Smart Deployment Script with Cycle Balance Checks
# Deploys canisters to ICP mainnet, checking cycles balance before each deployment

set +e  # Don't exit on error - we handle errors individually

NETWORK="ic"
MIN_CYCLES_PER_CANISTER=0.5  # Minimum T cycles per canister
RECOMMENDED_CYCLES_PER_CANISTER=1.0  # Recommended T cycles per canister

# Canisters to deploy (in order)
CANISTERS=(
  "portfolio_canister"
  "swap_canister"
  "shopping_rewards_frontend"
)

echo "🚀 Smart Deployment Script with Cycle Balance Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if using correct identity
CURRENT_IDENTITY=$(dfx identity whoami 2>/dev/null || echo "unknown")
echo "📋 Current identity: $CURRENT_IDENTITY"

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

echo ""

# Function to get cycles balance (returns number as string, e.g., "3.5")
get_cycles_balance() {
    local balance_output=$(dfx wallet --network "$NETWORK" balance 2>&1)
    # Extract number before "T" (e.g., "3.5 T cycles" -> "3.5")
    local balance=$(echo "$balance_output" | grep -oE '[0-9]+\.[0-9]+|[0-9]+' | head -1 || echo "0")
    echo "$balance"
}

# Function to check if first number >= second number
# Returns 0 (true) if a >= b, 1 (false) otherwise
compare_decimals() {
    local a=$1
    local b=$2
    # Use awk for floating point comparison
    if command -v awk >/dev/null 2>&1; then
        awk -v a="$a" -v b="$b" 'BEGIN {if (a >= b) exit 0; else exit 1}' && return 0 || return 1
    else
        # Fallback: simple integer comparison (multiply by 10 to handle one decimal)
        local a_int=$(echo "$a" | awk '{printf "%.0f", $1 * 10}' 2>/dev/null || echo "0")
        local b_int=$(echo "$b" | awk '{printf "%.0f", $1 * 10}' 2>/dev/null || echo "0")
        [ "$a_int" -ge "$b_int" ] && return 0 || return 1
    fi
}

# Function to check if canister is already deployed
is_canister_deployed() {
    local canister_name=$1
    
    # Check if canister exists
    if ! dfx canister --network "$NETWORK" id "$canister_name" >/dev/null 2>&1; then
        return 1  # Not created
    fi
    
    # Check if it has code deployed
    local status_output=$(dfx canister --network "$NETWORK" status "$canister_name" 2>/dev/null || echo "")
    
    if echo "$status_output" | grep -q "Module hash"; then
        return 0  # Deployed
    fi
    
    # Special check for frontend
    if [ "$canister_name" = "shopping_rewards_frontend" ]; then
        local canister_id=$(dfx canister --network "$NETWORK" id "$canister_name" 2>/dev/null | tr -d '[:space:]')
        if curl -s --max-time 5 "https://${canister_id}.ic0.app" >/dev/null 2>&1; then
            return 0  # Deployed
        fi
    fi
    
    return 1  # Created but not deployed
}

# Initial cycles balance check
echo "💰 Checking initial cycles balance..."
INITIAL_BALANCE=$(get_cycles_balance)
echo "  Current balance: ${INITIAL_BALANCE} T cycles"
echo ""

# Check if balance is valid (greater than 0.1)
if ! compare_decimals "$INITIAL_BALANCE" "0.1"; then
    echo "❌ ERROR: Cannot retrieve cycles balance or balance is too low"
    echo "   Please check your wallet: dfx wallet --network ic balance"
    echo "   Or convert ICP to cycles: dfx cycles convert --amount=2.0 --network ic"
    exit 1
fi

# Filter canisters that need deployment
CANISTERS_TO_DEPLOY=()
for canister in "${CANISTERS[@]}"; do
    if is_canister_deployed "$canister"; then
        local canister_id=$(dfx canister --network "$NETWORK" id "$canister" 2>/dev/null | tr -d '[:space:]')
        echo "  ✅ $canister is already deployed (ID: $canister_id)"
    else
        CANISTERS_TO_DEPLOY+=("$canister")
        echo "  ⚠️  $canister needs deployment"
    fi
done

echo ""

if [ ${#CANISTERS_TO_DEPLOY[@]} -eq 0 ]; then
    echo "✅ All canisters are already deployed!"
    echo ""
    echo "📋 Current canister IDs:"
    for canister in "${CANISTERS[@]}"; do
        local canister_id=$(dfx canister --network "$NETWORK" id "$canister" 2>/dev/null | tr -d '[:space:]' || echo "NOT_DEPLOYED")
        echo "$(echo "$canister" | tr '[:lower:]' '[:upper:]' | tr '_' '_')_ID=$canister_id"
    done
    exit 0
fi

REMAINING_COUNT=${#CANISTERS_TO_DEPLOY[@]}
# Calculate estimated cycles needed (simple multiplication)
if command -v awk >/dev/null 2>&1; then
    ESTIMATED_NEEDED=$(awk -v count="$REMAINING_COUNT" -v per="$RECOMMENDED_CYCLES_PER_CANISTER" 'BEGIN {printf "%.1f", count * per}')
else
    ESTIMATED_NEEDED=$REMAINING_COUNT
fi

echo "📊 Deployment Plan:"
echo "  Canisters to deploy: $REMAINING_COUNT"
echo "  Estimated cycles needed: ~${ESTIMATED_NEEDED} T cycles"
echo "  Current balance: ${INITIAL_BALANCE} T cycles"
echo ""

if ! compare_decimals "$INITIAL_BALANCE" "$ESTIMATED_NEEDED"; then
    echo "⚠️  WARNING: Your cycles balance may be insufficient!"
    echo "   Recommended: ${ESTIMATED_NEEDED} T cycles"
    echo "   Current: ${INITIAL_BALANCE} T cycles"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled. Get more cycles:"
        # Calculate needed amount (add 1 for safety)
        if command -v awk >/dev/null 2>&1; then
            NEEDED_AMOUNT=$(awk -v est="$ESTIMATED_NEEDED" -v bal="$INITIAL_BALANCE" 'BEGIN {printf "%.1f", est - bal + 1}')
        else
            NEEDED_AMOUNT=2
        fi
        echo "  dfx cycles convert --amount=${NEEDED_AMOUNT} --network ic"
        exit 1
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create canisters that don't exist
echo "📝 Creating canisters (if needed)..."
for canister in "${CANISTERS_TO_DEPLOY[@]}"; do
    if dfx canister --network "$NETWORK" id "$canister" >/dev/null 2>&1; then
        echo "  ℹ️  $canister already exists"
    else
        echo "  Creating $canister..."
        if dfx canister --network "$NETWORK" create "$canister" 2>&1; then
            echo "  ✅ $canister created"
        else
            echo "  ⚠️  Failed to create $canister (may already exist)"
        fi
    fi
done

echo ""

# Build canisters
echo "📦 Building canisters..."
if dfx build --network "$NETWORK" 2>&1; then
    echo "  ✅ Build successful"
else
    echo "  ⚠️  Build had warnings/errors, but continuing..."
fi

echo ""

# Deploy canisters one by one with cycle checks
echo "🚀 Deploying canisters (with cycle balance checks)..."
echo ""

DEPLOYMENT_ERRORS=0
DEPLOYMENT_SUCCESS=0

for canister in "${CANISTERS_TO_DEPLOY[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Deploying: $canister"
    echo ""
    
    # Check cycles balance before deployment
    CURRENT_BALANCE=$(get_cycles_balance)
    echo "  💰 Current cycles balance: ${CURRENT_BALANCE} T cycles"
    
    if ! compare_decimals "$CURRENT_BALANCE" "$MIN_CYCLES_PER_CANISTER"; then
        echo "  ❌ ERROR: Insufficient cycles! Need at least ${MIN_CYCLES_PER_CANISTER} T cycles"
        echo "  Current balance: ${CURRENT_BALANCE} T cycles"
        echo ""
        echo "  Get more cycles:"
        echo "    dfx cycles convert --amount=2.0 --network ic"
        echo ""
        DEPLOYMENT_ERRORS=$((DEPLOYMENT_ERRORS + 1))
        continue
    fi
    
    if ! compare_decimals "$CURRENT_BALANCE" "$RECOMMENDED_CYCLES_PER_CANISTER"; then
        echo "  ⚠️  WARNING: Low cycles balance. Recommended: ${RECOMMENDED_CYCLES_PER_CANISTER} T cycles"
        echo "  Continuing anyway..."
    fi
    
    echo ""
    
    # Special handling for frontend
    if [ "$canister" = "shopping_rewards_frontend" ]; then
        echo "  Building frontend..."
        if npm run build 2>&1; then
            echo "  ✅ Frontend built"
        else
            echo "  ❌ Failed to build frontend"
            DEPLOYMENT_ERRORS=$((DEPLOYMENT_ERRORS + 1))
            continue
        fi
        echo ""
    fi
    
    # Deploy the canister
    echo "  Deploying $canister..."
    DEPLOY_LOG="/tmp/${canister}-deploy.log"
    
    if dfx deploy --network "$NETWORK" "$canister" 2>&1 | tee "$DEPLOY_LOG"; then
        echo ""
        echo "  ✅ $canister deployed successfully!"
        
        # Check balance after deployment
        NEW_BALANCE=$(get_cycles_balance)
        # Calculate cycles used
        if command -v awk >/dev/null 2>&1; then
            BALANCE_USED=$(awk -v curr="$CURRENT_BALANCE" -v new="$NEW_BALANCE" 'BEGIN {printf "%.2f", curr - new}')
        else
            BALANCE_USED="unknown"
        fi
        echo "  💰 Cycles used: ~${BALANCE_USED} T cycles"
        echo "  💰 Remaining balance: ${NEW_BALANCE} T cycles"
        
        DEPLOYMENT_SUCCESS=$((DEPLOYMENT_SUCCESS + 1))
    else
        echo ""
        ERROR_MSG=$(cat "$DEPLOY_LOG" 2>/dev/null | grep -i "insufficient\|cycles" || echo "")
        
        if [[ "$ERROR_MSG" == *"Insufficient"* ]] || [[ "$ERROR_MSG" == *"cycles"* ]]; then
            echo "  ❌ Failed: Insufficient cycles!"
            echo "  Get more cycles: dfx cycles convert --amount=1.0 --network ic"
        else
            echo "  ❌ Failed to deploy $canister"
            echo "  Check the log above for details"
        fi
        
        DEPLOYMENT_ERRORS=$((DEPLOYMENT_ERRORS + 1))
    fi
    
    echo ""
done

# Final summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Deployment Summary:"
echo ""
echo "  ✅ Successfully deployed: $DEPLOYMENT_SUCCESS"
echo "  ❌ Failed: $DEPLOYMENT_ERRORS"
echo ""

FINAL_BALANCE=$(get_cycles_balance)
echo "💰 Final cycles balance: ${FINAL_BALANCE} T cycles"
echo ""

# Get all canister IDs
echo "📋 Canister IDs:"
for canister in "${CANISTERS[@]}"; do
    if canister_id=$(dfx canister --network "$NETWORK" id "$canister" 2>/dev/null); then
        canister_id=$(echo "$canister_id" | tr -d '[:space:]')
        echo "$(echo "$canister" | tr '[:lower:]' '[:upper:]' | tr '_' '_')_ID=$canister_id"
    else
        echo "$(echo "$canister" | tr '[:lower:]' '[:upper:]' | tr '_' '_')_ID=NOT_DEPLOYED"
    fi
done

echo ""

if [ $DEPLOYMENT_ERRORS -eq 0 ] && [ $DEPLOYMENT_SUCCESS -gt 0 ]; then
    echo "✅ Deployment complete! All canisters deployed successfully."
    echo ""
    echo "Next steps:"
    echo "1. Update your .env file with the canister IDs above"
    
    # Check if canisters need initialization
    if [[ " ${CANISTERS_TO_DEPLOY[@]} " =~ " lending_canister " ]]; then
        echo "2. Initialize lending canister:"
        echo "   dfx canister --network ic call lending_canister init"
    fi
    
    if [[ " ${CANISTERS_TO_DEPLOY[@]} " =~ " swap_canister " ]]; then
        echo "3. Initialize swap canister:"
        echo "   dfx canister --network ic call swap_canister init"
    fi
    
    FRONTEND_ID=$(dfx canister --network ic id shopping_rewards_frontend 2>/dev/null | tr -d '[:space:]' || echo "")
    if [ -n "$FRONTEND_ID" ] && [ "$FRONTEND_ID" != "NOT_DEPLOYED" ]; then
        echo "4. Access your app at: https://${FRONTEND_ID}.ic0.app"
    fi
elif [ $DEPLOYMENT_ERRORS -gt 0 ]; then
    echo "⚠️  Deployment completed with $DEPLOYMENT_ERRORS error(s)."
    echo "   Review the output above and fix any issues."
    echo "   You may need more cycles or check canister configuration."
else
    echo "ℹ️  No canisters were deployed (all were already deployed or failed checks)."
fi

echo ""

