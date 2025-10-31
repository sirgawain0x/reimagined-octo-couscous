# Internet Identity Setup for Local Development

## The Problem

You're seeing this error:
```
400 - canister id incorrect
Failed to load resource: the server responded with a status of 400 (Bad Request)
http://localhost:4943/?canisterId=rdmx6-jaaaa-aaaah-qcaiq-cai#authorize
```

This happens because the canister ID `rdmx6-jaaaa-aaaah-qcaiq-cai` in your configuration is **invalid**. This ID has a CRC32 checksum mismatch, meaning it's not a valid canister ID format.

## Solution Options

### Option 1: Deploy Internet Identity (Recommended)

Internet Identity doesn't have a fixed canister ID for local development - you need to deploy it first and use its actual ID.

1. **Install Internet Identity locally:**
   ```bash
   # Clone the repository
   git clone https://github.com/dfinity/internet-identity.git /tmp/internet-identity
   cd /tmp/internet-identity
   
   # Install dependencies
   npm install
   
   # Build Internet Identity
   dfx build internet_identity
   
   # Deploy it (this will assign it a random canister ID)
   dfx deploy internet_identity
   
   # Get the actual canister ID
   dfx canister id internet_identity
   ```

2. **Update your configuration:**
   - Copy the canister ID from step 1
   - Update `src/config/env.ts` or set `VITE_INTERNET_IDENTITY_URL` in your `.env` file:
     ```env
     VITE_INTERNET_IDENTITY_URL=http://localhost:4943?canisterId=<actual-canister-id>
     ```

### Option 2: Use Bitcoin Wallet Authentication Only

If you're only using Bitcoin wallet authentication (Sign-in with Bitcoin), you can skip Internet Identity:

1. The app already supports Bitcoin wallets (Wizz, Unisat, Xverse)
2. Internet Identity is optional if you're using Bitcoin wallets
3. However, the error might still appear if the app tries to load Internet Identity on startup

### Option 3: Use Production Internet Identity

For local development, you can temporarily use the production Internet Identity:

Update `src/config/env.ts` or your `.env`:
```env
VITE_INTERNET_IDENTITY_URL=https://identity.ic0.app
VITE_ICP_NETWORK=ic
```

**Note:** This requires internet connectivity and uses the production Internet Identity service.

## Quick Fix (Temporary)

If you just want to test Bitcoin wallet authentication and don't need Internet Identity right now:

1. Make sure your app doesn't automatically try to connect to Internet Identity on startup
2. Use only the Bitcoin wallet connection dialog
3. The error will appear if you try to use Internet Identity, but Bitcoin wallet auth should work

## Verification

After deploying Internet Identity, verify it works:
```bash
# Check canister status
dfx canister status internet_identity

# Get the canister ID
dfx canister id internet_identity

# Visit the canister in your browser
# http://localhost:4943/?canisterId=<canister-id>
```

## Additional Notes

- Internet Identity is a complex canister that requires building from source
- For local development, each deployment gets a random canister ID
- The canister ID `rdmx6-jaaaa-aaaah-qcaiq-cai` appears to be a placeholder/template ID that's not valid
- If you're building Internet Identity yourself, ensure you have Rust and other build dependencies installed

