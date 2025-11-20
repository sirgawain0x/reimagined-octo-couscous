#!/bin/bash
# Quick fix for PocketIC initialization errors

echo "🔧 Fixing PocketIC initialization errors..."
echo ""

# Stop everything
echo "1. Stopping all dfx and PocketIC processes..."
pkill -9 -f "pocket-ic" 2>/dev/null || true
pkill -9 -f "dfx" 2>/dev/null || true
dfx stop 2>/dev/null || true
sleep 2

# Clean lock files
echo "2. Cleaning lock files..."
DFX_LOCK_DIR="$HOME/Library/Application Support/org.dfinity.dfx/network/local"
if [ -d "$DFX_LOCK_DIR" ]; then
    rm -f "$DFX_LOCK_DIR"/*.pid 2>/dev/null || true
    echo "   ✅ Lock files cleaned"
fi

# Clean .dfx PocketIC state
echo "3. Cleaning PocketIC state..."
if [ -d ".dfx" ]; then
    find .dfx -name "*pocket*" -type f -delete 2>/dev/null || true
    find .dfx -name "*.pid" -type f -delete 2>/dev/null || true
    echo "   ✅ PocketIC state cleaned"
fi

# Verify everything is stopped
echo "4. Verifying cleanup..."
REMAINING=$(pgrep -f "pocket-ic|dfx" | grep -v grep || true)
if [ -z "$REMAINING" ]; then
    echo "   ✅ All processes stopped"
else
    echo "   ⚠️  Some processes still running: $REMAINING"
    echo "   Force killing..."
    kill -9 $REMAINING 2>/dev/null || true
fi

echo ""
echo "✅ Cleanup complete! Now try running ./start.sh again"
