# 🚀 Simple Startup - Just Run This!

## Quick Start (Copy & Paste)

**Option 1: Use the startup script**
```bash
cd /Users/gawainbracyii/Developer/reimagined-octo-couscous
./start.sh
```

**Option 2: Two Terminal Windows**

### Terminal 1:
```bash
cd /Users/gawainbracyii/Developer/reimagined-octo-couscous
dfx start --enable-bitcoin
```
**Wait for:** "Starting server." message (takes ~30 seconds)

### Terminal 2 (after Terminal 1 shows "Starting server"):
```bash
cd /Users/gawainbracyii/Developer/reimagined-octo-couscous
npm run dev
```

Then open: **http://localhost:5173**

---

## What's Happening?

Right now, dfx is starting up but not ready yet. It takes 30-60 seconds to fully initialize.

**To check if it's ready:**
```bash
curl http://localhost:4943/api/v2/status
```

If you see JSON output → dfx is ready!
If you get connection errors → dfx is still starting, wait a bit longer.

---

## Current Status

✅ Bitcoin: Running
✅ dfx: Starting (processes visible, but still initializing)
⏳ Waiting for dfx to be ready...

**Just wait another 30-60 seconds**, then try starting the dev server!

