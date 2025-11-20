#!/bin/bash
# Quick Start Script for ICP Shopping Rewards Platform

set -e

echo "🚀 Starting ICP Shopping Rewards Platform..."
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Step 1: Check Bitcoin
echo "📊 Step 1: Checking Bitcoin node..."
if ps aux | grep -q "[b]itcoind.*18444"; then
    echo "✅ Bitcoin node is running"
else
    echo "⚠️  Bitcoin node not running. Starting..."
    npm run bitcoin:start
    sleep 2
fi

# Step 2: Check dfx
echo ""
echo "📊 Step 2: Checking ICP network (dfx)..."
if curl -s http://localhost:4943/api/v2/status > /dev/null 2>&1; then
    echo "✅ dfx is already running"
else
    # Check for any zombie dfx processes
    DFX_PIDS=$(pgrep -f "dfx start" || true)
    POCKET_PIDS=$(pgrep -f "pocket-ic" || true)
    if [ -n "$DFX_PIDS" ] || [ -n "$POCKET_PIDS" ]; then
        echo "⚠️  Cleaning up leftover dfx processes..."
        [ -n "$DFX_PIDS" ] && kill -9 $DFX_PIDS 2>/dev/null || true
        [ -n "$POCKET_PIDS" ] && kill -9 $POCKET_PIDS 2>/dev/null || true
        sleep 2
    fi
    
    # Clean up dfx lock files
    DFX_LOCK_DIR="$HOME/Library/Application Support/org.dfinity.dfx/network/local"
    if [ -d "$DFX_LOCK_DIR" ]; then
        rm -f "$DFX_LOCK_DIR/pid" "$DFX_LOCK_DIR/pocket-ic-pid" "$DFX_LOCK_DIR/pocket-ic-proxy-pid" 2>/dev/null || true
    fi
    
    # Try proper dfx stop
    dfx stop 2>/dev/null || true
    sleep 2
    
    # Additional cleanup: kill any remaining PocketIC processes
    pkill -9 -f "pocket-ic" 2>/dev/null || true
    sleep 1
    
    # Clean .dfx state if PocketIC errors persist (but keep canister IDs)
    if [ -d ".dfx" ]; then
        echo "🧹 Cleaning PocketIC state..."
        # Only remove PocketIC-related files, not canister configs
        find .dfx -name "*pocket*" -type f -delete 2>/dev/null || true
        find .dfx -name "*.pid" -type f -delete 2>/dev/null || true
    fi
    
    echo "🔄 Starting dfx with Bitcoin support..."
    echo "   (This may take a minute - dfx is starting in the background)"
    
    # Use --clean flag to ensure fresh PocketIC instance
    dfx start --enable-bitcoin --clean --background 2>&1 | grep -v "Failed to initialize PocketIC" || true
    
    echo "   Waiting for dfx to be ready..."
    sleep 5
    
    # Check if dfx started successfully
    for i in {1..10}; do
        if curl -s http://localhost:4943/api/v2/status > /dev/null 2>&1; then
            echo "✅ dfx is ready!"
            break
        fi
        if [ $i -eq 5 ]; then
            echo "⚠️  dfx seems stuck, checking for PocketIC errors..."
            if pgrep -f "pocket-ic" > /dev/null 2>&1 && ! curl -s http://localhost:4943/api/v2/status > /dev/null 2>&1; then
                echo "⚠️  PocketIC may be stuck, cleaning state and retrying..."
                ./stop-dfx.sh
                rm -rf .dfx 2>/dev/null || true
                sleep 2
                dfx start --clean --enable-bitcoin --background
                sleep 5
            fi
        fi
        echo "   Still starting... ($i/10)"
        sleep 2
    done
fi

# Step 3: Clean up any existing Vite servers
echo ""
echo "📊 Step 3: Cleaning up any existing dev servers..."
VITE_PIDS=$(pgrep -f "node.*vite" || true)
if [ -n "$VITE_PIDS" ]; then
    echo "   Stopping existing Vite servers..."
    kill $VITE_PIDS 2>/dev/null || true
    sleep 2
fi

# Ensure ports 5173 and 5174 are free
PORT_5173=$(lsof -ti:5173)
PORT_5174=$(lsof -ti:5174)
if [ -n "$PORT_5173" ]; then
    echo "   Freeing port 5173..."
    kill $PORT_5173 2>/dev/null || true
    sleep 1
fi
if [ -n "$PORT_5174" ]; then
    echo "   Freeing port 5174..."
    kill $PORT_5174 2>/dev/null || true
    sleep 1
fi

# Step 4: Start dev server
echo ""
echo "📊 Step 4: Starting development server..."
echo "✅ Starting Vite dev server on http://localhost:5173"
echo ""
echo "🎉 Setup complete!"
echo ""
echo "📝 Note: Keep this terminal open to see dev server logs"
echo "   Press Ctrl+C to stop the dev server"
echo ""
echo "🔗 Access the app at: http://localhost:5173"
echo ""

# Start the dev server
npm run dev

