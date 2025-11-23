# Vercel Deployment Guide

This document outlines the steps and configuration for deploying the frontend to Vercel.

## ✅ Pre-Deployment Checklist

- [x] Build script configured correctly (`npm run build`)
- [x] Tests excluded from build process
- [x] Vercel configuration file created (`vercel.json`)
- [x] Build output directory configured (`dist/`)
- [x] SPA routing configured for client-side routing

## Configuration Files

### `vercel.json`
- **Build Command**: `npm run build` (runs TypeScript compilation + Vite build)
- **Output Directory**: `dist/` (Vite's default output)
- **Framework**: Vite (auto-detected)
- **SPA Routing**: All routes rewrite to `index.html` for client-side routing
- **Caching**: Static assets cached for 1 year with immutable flag

### `.vercelignore`
Excludes unnecessary files from deployment:
- Bitcoin data files
- ICP/DFX canister files
- Test files and coverage
- Documentation (except README)
- Local environment files

## Environment Variables

Configure these in Vercel's dashboard under **Settings → Environment Variables**:

### Required Variables

```env
# ICP Network Configuration
VITE_ICP_NETWORK=ic
VITE_INTERNET_IDENTITY_URL=https://identity.ic0.app

# Canister IDs (populate after deploying canisters to ICP mainnet)
VITE_CANISTER_ID_REWARDS=your_rewards_canister_id
VITE_CANISTER_ID_LENDING=your_lending_canister_id
VITE_CANISTER_ID_PORTFOLIO=your_portfolio_canister_id
VITE_CANISTER_ID_SWAP=your_swap_canister_id
VITE_CANISTER_ID_IC_SIWB_PROVIDER=be2us-64aaa-aaaaa-qaabq-cai
```

### Optional Variables

```env
# Bitcoin Network (defaults to testnet)
VITE_BITCOIN_NETWORK=testnet

# Validation Cloud API Key (optional)
VITE_VALIDATION_CLOUD_API_KEY=your_api_key_here

# Validation Cloud Solana Endpoints (optional, has defaults)
VITE_VALIDATION_CLOUD_SOLANA_DEVNET=your_devnet_endpoint
VITE_VALIDATION_CLOUD_SOLANA_MAINNET=your_mainnet_endpoint

# Amazon Affiliate Link (optional)
VITE_AMAZON_AFFILIATE_LINK=your_affiliate_link
```

## Deployment Steps

### 1. Connect Repository to Vercel

1. Go to [vercel.com](https://vercel.com)
2. Click **Add New Project**
3. Import your Git repository
4. Vercel will auto-detect Vite framework

### 2. Configure Build Settings

Vercel should auto-detect these settings from `vercel.json`:
- **Framework Preset**: Vite
- **Build Command**: `npm run build`
- **Output Directory**: `dist`
- **Install Command**: `npm install`

### 3. Set Environment Variables

1. Go to **Settings → Environment Variables**
2. Add all required variables listed above
3. Set them for **Production**, **Preview**, and **Development** environments as needed

### 4. Deploy

1. Click **Deploy**
2. Vercel will:
   - Install dependencies (`npm install`)
   - Run build (`npm run build`)
   - Deploy the `dist/` directory
   - Configure SPA routing

## Build Process

The build process runs:
1. **TypeScript Compilation** (`tsc`) - Type checks and compiles TypeScript
2. **Vite Build** (`vite build`) - Bundles and optimizes the application

**Note**: Tests are **NOT** run during the build process. The build script is:
```json
"build": "tsc && vite build"
```

Tests can be run separately using:
- `npm test` - Run tests in watch mode
- `npm run test:ci` - Run tests once with coverage

## Troubleshooting

### Build Fails

1. **TypeScript Errors**: Check `tsconfig.json` configuration
2. **Missing Dependencies**: Ensure all dependencies are in `package.json`
3. **Environment Variables**: Verify all required variables are set in Vercel

### Routing Issues

- Ensure `vercel.json` has the SPA rewrite rule
- Check that `index.html` exists in the build output

### Environment Variable Issues

- Variables must be prefixed with `VITE_` to be available in the browser
- Restart deployment after adding new environment variables

## Post-Deployment

After successful deployment:

1. **Verify Canister IDs**: Ensure all canister IDs are correctly set in environment variables
2. **Test Authentication**: Verify Internet Identity authentication works
3. **Test Features**: Test all major features (swap, lend, borrow, portfolio)
4. **Check Console**: Monitor browser console for any errors

## Continuous Deployment

Vercel automatically deploys:
- **Production**: On push to main/master branch
- **Preview**: On push to other branches or pull requests

Each deployment gets a unique URL for testing.

