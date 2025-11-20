#!/bin/bash

# Deployment Readiness Check Script
# Validates that all required configuration is set before deployment

set -e

echo "🔍 Checking deployment readiness..."

ERRORS=0

# Check if .env file exists
if [ ! -f .env ]; then
  echo "❌ .env file not found"
  echo "   Create .env file from .env.example"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ .env file exists"
fi

# Check required environment variables for production
if [ "$VITE_ICP_NETWORK" = "ic" ]; then
  echo "📋 Checking production canister IDs..."
  
  REQUIRED_VARS=(
    "VITE_CANISTER_ID_REWARDS"
    "VITE_CANISTER_ID_LENDING"
    "VITE_CANISTER_ID_PORTFOLIO"
    "VITE_CANISTER_ID_SWAP"
    "VITE_INTERNET_IDENTITY_URL"
  )
  
  for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
      echo "❌ $var is not set"
      ERRORS=$((ERRORS + 1))
    else
      echo "✅ $var is set"
    fi
  done
fi

# Check if dfx is installed
if ! command -v dfx &> /dev/null; then
  echo "⚠️  dfx is not installed (required for canister deployment)"
else
  echo "✅ dfx is installed"
fi

# Check if canisters are built
if [ ! -d ".dfx" ]; then
  echo "⚠️  .dfx directory not found (run 'dfx deploy' first)"
else
  echo "✅ .dfx directory exists"
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
  echo "✅ All checks passed! Ready for deployment."
  exit 0
else
  echo "❌ Found $ERRORS issue(s). Please fix before deploying."
  exit 1
fi

