#!/bin/bash
# Stop all dfx and dev server processes

echo "🛑 Stopping all development processes..."

# Kill processes using port 4943 (dfx)
PORT_4943=$(lsof -ti:4943)
if [ -n "$PORT_4943" ]; then
    echo "Killing process on port 4943 (dfx) (PID: $PORT_4943)..."
    kill -9 $PORT_4943 2>/dev/null || true
fi

# Kill processes using port 5173 (Vite dev server)
PORT_5173=$(lsof -ti:5173)
if [ -n "$PORT_5173" ]; then
    echo "Killing process on port 5173 (Vite) (PID: $PORT_5173)..."
    kill -9 $PORT_5173 2>/dev/null || true
fi

# Kill all dfx and pocket-ic processes
DFX_PIDS=$(pgrep -f "dfx start" || true)
POCKET_PIDS=$(pgrep -f "pocket-ic" || true)

if [ -n "$DFX_PIDS" ]; then
    echo "Killing dfx processes..."
    kill -9 $DFX_PIDS 2>/dev/null || true
fi

if [ -n "$POCKET_PIDS" ]; then
    echo "Killing pocket-ic processes..."
    kill -9 $POCKET_PIDS 2>/dev/null || true
fi

# Kill Vite dev servers
VITE_PIDS=$(pgrep -f "node.*vite" || true)
if [ -n "$VITE_PIDS" ]; then
    echo "Killing Vite dev server processes..."
    kill $VITE_PIDS 2>/dev/null || true
fi

# Wait a moment
sleep 2

# Final check for any remaining dfx processes
REMAINING_DFX=$(pgrep -f "dfx start" || true)
REMAINING_POCKET=$(pgrep -f "pocket-ic" || true)
if [ -n "$REMAINING_DFX" ] || [ -n "$REMAINING_POCKET" ]; then
    echo "⚠️  Some dfx processes still running, force killing..."
    if [ -n "$REMAINING_DFX" ]; then
        kill -9 $REMAINING_DFX 2>/dev/null || true
    fi
    if [ -n "$REMAINING_POCKET" ]; then
        kill -9 $REMAINING_POCKET 2>/dev/null || true
    fi
    sleep 1
fi

# Check ports
echo ""
if lsof -ti:4943 > /dev/null 2>&1; then
    REMAINING_PORT=$(lsof -ti:4943)
    echo "⚠️  Port 4943 is still in use. Force killing (PID: $REMAINING_PORT)..."
    kill -9 $REMAINING_PORT 2>/dev/null || true
    sleep 1
    echo "✅ Port 4943 (dfx) is free"
else
    echo "✅ Port 4943 (dfx) is free"
fi

if lsof -ti:5173 > /dev/null 2>&1; then
    REMAINING_PORT=$(lsof -ti:5173)
    echo "⚠️  Port 5173 is still in use. Force killing (PID: $REMAINING_PORT)..."
    kill -9 $REMAINING_PORT 2>/dev/null || true
    sleep 1
    echo "✅ Port 5173 (Vite) is free"
else
    echo "✅ Port 5173 (Vite) is free"
fi

# Clean up dfx lock files
echo ""
echo "🧹 Cleaning up dfx lock files..."
DFX_LOCK_DIR="$HOME/Library/Application Support/org.dfinity.dfx/network/local"
if [ -d "$DFX_LOCK_DIR" ]; then
    rm -f "$DFX_LOCK_DIR/pid" "$DFX_LOCK_DIR/pocket-ic-pid" "$DFX_LOCK_DIR/pocket-ic-proxy-pid" 2>/dev/null || true
    echo "✅ dfx lock files cleaned"
fi

echo ""
echo "✅ Cleanup complete!"

