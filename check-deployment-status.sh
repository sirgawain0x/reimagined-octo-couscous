#!/bin/bash

# Deployment Status Checker
# Checks which canisters are fully deployed vs. just created on ICP mainnet

# Don't exit on error - we handle errors in the script
set +e

NETWORK="ic"
CANISTERS=(
  "rewards_canister"
  "lending_canister"
  "portfolio_canister"
  "swap_canister"
  "shopping_rewards_frontend"
)

echo "🔍 Checking deployment status on ICP mainnet..."
echo ""

# Check cycles balance first
echo "💰 Cycles Balance:"
BALANCE_OUTPUT=$(dfx wallet --network "$NETWORK" balance 2>&1)
if echo "$BALANCE_OUTPUT" | grep -qiE "balance|cycles|T cycles"; then
  BALANCE=$(echo "$BALANCE_OUTPUT" | grep -oE '[0-9.]+[[:space:]]*T' | head -1 || echo "unknown")
  echo "  Current balance: $BALANCE"
  echo "$BALANCE_OUTPUT" | head -3
else
  echo "  ⚠️  Could not retrieve cycles balance"
  echo "  Run manually: dfx wallet --network ic balance"
fi
echo ""

# Function to check if canister exists and is deployed
check_canister_status() {
  local canister_name=$1
  local status="NOT_FOUND"
  local canister_id=""
  local has_code=false
  
  # Try to get canister ID
  if canister_id=$(dfx canister --network "$NETWORK" id "$canister_name" 2>/dev/null); then
    status="CREATED"
    canister_id=$(echo "$canister_id" | tr -d '[:space:]')
    
    # Check if canister has code deployed (by checking if it responds to a status query)
    # For Motoko canisters, we can check if they have a module hash
    if dfx canister --network "$NETWORK" status "$canister_name" 2>/dev/null | grep -q "Module hash"; then
      has_code=true
      status="DEPLOYED"
    elif dfx canister --network "$NETWORK" status "$canister_name" 2>/dev/null | grep -q "No update"; then
      # Assets canisters might show "No update" but still be deployed
      if [ "$canister_name" = "shopping_rewards_frontend" ]; then
        # For frontend, check if we can query it
        if curl -s --max-time 5 "https://${canister_id}.ic0.app" > /dev/null 2>&1; then
          has_code=true
          status="DEPLOYED"
        fi
      fi
    fi
    
    # Additional check: try to get canister info
    if dfx canister --network "$NETWORK" info "$canister_name" 2>/dev/null | grep -q "Module hash\|Controllers"; then
      has_code=true
      status="DEPLOYED"
    fi
  fi
  
  # Print status
  case "$status" in
    "DEPLOYED")
      echo "  ✅ $canister_name: DEPLOYED"
      echo "     ID: $canister_id"
      ;;
    "CREATED")
      echo "  ⚠️  $canister_name: CREATED (but not deployed)"
      echo "     ID: $canister_id"
      ;;
    "NOT_FOUND")
      echo "  ❌ $canister_name: NOT CREATED"
      ;;
  esac
}

# Check each canister
echo "📋 Canister Status:"
echo ""

for canister in "${CANISTERS[@]}"; do
  check_canister_status "$canister"
  echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo ""

DEPLOYED_COUNT=0
CREATED_COUNT=0
NOT_FOUND_COUNT=0

for canister in "${CANISTERS[@]}"; do
  if canister_id=$(dfx canister --network "$NETWORK" id "$canister" 2>/dev/null); then
    canister_id=$(echo "$canister_id" | tr -d '[:space:]')
    if dfx canister --network "$NETWORK" status "$canister" 2>/dev/null | grep -q "Module hash"; then
      DEPLOYED_COUNT=$((DEPLOYED_COUNT + 1))
    elif [ "$canister" = "shopping_rewards_frontend" ] && curl -s --max-time 5 "https://${canister_id}.ic0.app" > /dev/null 2>&1; then
      DEPLOYED_COUNT=$((DEPLOYED_COUNT + 1))
    else
      CREATED_COUNT=$((CREATED_COUNT + 1))
    fi
  else
    NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1))
  fi
done

echo "  ✅ Deployed: $DEPLOYED_COUNT"
echo "  ⚠️  Created (not deployed): $CREATED_COUNT"
echo "  ❌ Not created: $NOT_FOUND_COUNT"
echo ""

# Estimate cycles needed
REMAINING=$((CREATED_COUNT + NOT_FOUND_COUNT))
if [ "$REMAINING" -gt 0 ]; then
  MIN_CYCLES=$((REMAINING * 1))
  RECOMMENDED_CYCLES=$((REMAINING * 1 + 1))
  echo "💡 Estimated cycles needed for remaining canisters:"
  echo "   Minimum: ~${MIN_CYCLES} T cycles (0.5-1 T per canister)"
  echo "   Recommended: ${RECOMMENDED_CYCLES} T cycles (with buffer)"
  echo ""
fi

# Get all canister IDs
echo "📝 Canister IDs:"
for canister in "${CANISTERS[@]}"; do
  if canister_id=$(dfx canister --network "$NETWORK" id "$canister" 2>/dev/null); then
    canister_id=$(echo "$canister_id" | tr -d '[:space:]')
    echo "$(echo "$canister" | tr '[:lower:]' '[:upper:]' | tr '_' '_')_ID=$canister_id"
  else
    echo "$(echo "$canister" | tr '[:lower:]' '[:upper:]' | tr '_' '_')_ID=NOT_DEPLOYED"
  fi
done

echo ""
echo "✅ Status check complete!"

