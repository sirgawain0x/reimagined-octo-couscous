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
    echo "🔄 Starting dfx with Bitcoin support..."
    echo "   (This may take a minute - dfx is starting in the background)"
    dfx start --enable-bitcoin --background
    echo "   Waiting for dfx to be ready..."
    sleep 5
    
    # Check if dfx started successfully
    for i in {1..10}; do
        if curl -s http://localhost:4943/api/v2/status > /dev/null 2>&1; then
            echo "✅ dfx is ready!"
            break
        fi
        echo "   Still starting... ($i/10)"
        sleep 2
    done
fi

# Step 3: Start dev server
echo ""
echo "📊 Step 3: Starting development server..."
echo "✅ Starting Vite dev server on http://localhost:5173"
echo ""
echo "🎉 Setup complete! Opening browser..."
echo ""
echo "📝 Note: Keep this terminal open to see dev server logs"
echo "   Press Ctrl+C to stop the dev server"
echo ""

# Start the dev server
npm run dev

