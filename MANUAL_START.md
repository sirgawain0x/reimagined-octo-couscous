# Manual Startup Instructions

If the automatic script doesn't work, follow these steps manually:

## Option 1: Quick Start (Recommended)

Just run:
```bash
./start.sh
```

## Option 2: Manual Step-by-Step

### Terminal 1: Start dfx
```bash
cd /Users/gawainbracyii/Developer/reimagined-octo-couscous
dfx start --enable-bitcoin
```
**Keep this terminal open!** dfx needs to keep running.

Wait until you see:
```
Starting server.
```

### Terminal 2: Start Dev Server
```bash
cd /Users/gawainbracyii/Developer/reimagined-octo-couscous
npm run dev
```

Then open: **http://localhost:5173**

## Option 3: Run Everything in Background

### Start dfx in background:
```bash
cd /Users/gawainbracyii/Developer/reimagined-octo-couscous
dfx start --enable-bitcoin --background
```

Wait 10-15 seconds, then verify:
```bash
curl http://localhost:4943/api/v2/status
```

If you see JSON output, dfx is ready!

### Start dev server:
```bash
npm run dev
```

## Troubleshooting

### dfx won't start?
```bash
# Kill everything
pkill -f "pocket-ic"
pkill -f "dfx start"
dfx stop

# Start fresh
dfx start --enable-bitcoin --background
```

### Port 4943 already in use?
```bash
# Find what's using it
lsof -i :4943

# Kill it
kill <PID>

# Restart dfx
dfx start --enable-bitcoin
```

### Check what's running:
```bash
# Check dfx
curl http://localhost:4943/api/v2/status

# Check Bitcoin
npm run bitcoin:status

# Check processes
ps aux | grep -E "(dfx|bitcoind|vite)"
```

