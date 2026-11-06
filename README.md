# Bit Rewards

The release candidate is an affiliate storefront for Amazon, Walmart, and eBay. Visitors can shop without signing in. The storefront reads its merchant links from the build configuration and never calls the legacy rewards, lending, swap, or portfolio canisters. Internet Identity is optional.

## Storefront release

Use Node 22 and the committed dependency lockfiles:

```sh
npm ci
npm test -- --run
npm audit --omit=dev --audit-level=high
npm run build
npx --no-install playwright-core install chromium
node e2e/storefront.mjs
npm ci --prefix tests/rewards-pilot
npm test --prefix tests/rewards-pilot
```

The browser test serves the built output with the intended security headers from `config/storefront-headers.json`. Verify those headers separately on the Render preview. It intercepts merchant and identity-provider handoffs without placing an order or signing into a live account. Confirm the real Internet Identity return flow and affiliate attribution on an approved preview origin before production promotion.

The production build defaults to the IC network and the default Internet Identity provider. The affiliate-only storefront requires no treasury credentials, merchant secrets, or canister IDs. Set affiliate overrides in the host's build environment if the campaign uses different approved URLs. Confirm the short links belong to the intended affiliate accounts. The production host is the existing Bit Rewards service on Render. Confirm its service type, deployed commit, linked branch and auto-deploy setting in the Render dashboard before pushing. For a Render Static Site, use the repository root, build with `npm ci && npm run build`, publish `dist`, and apply the headers from `config/storefront-headers.json` to `/*` in the service settings. For a Render Web Service, verify its current start command serves that same build and sends those headers. The repository's `proxy-server` instructions apply to a separate backend. Validate a preview and obtain approval before promoting or pushing to an auto-deployed production branch. A frontend rollback should restore the previous approved storefront or maintenance page; avoid pointing users to legacy financial features.

## Paid rewards

The PocketIC pilot uses signed synthetic orders and nonredeemable units. See [pilot tests](tests/rewards-pilot/README.md). The legacy mainnet deployment requires a separate release and custody review. Run `node scripts/inspect-mainnet.mjs` for fresh certified controller and module metadata, published interfaces, and default-account ckBTC balances. This public check cannot establish who controls each identity, native BTC balances, or cycle runway.

Before authorizing paid rewards:
- Reconcile native BTC addresses, derivation paths, historical transfers, token subaccounts, user liabilities, and controller recovery with the CTO. Preserve legacy records before upgrading.
- Obtain authenticated purchase, refund and cancellation records plus attribution from the merchant. Reconcile a trial batch to merchant records.
- Select the payout asset, rate, caps, hold period and budget. Implement and test a separate manually approved payout path, including reconciliation after an ambiguous transfer.
- Revoke the exposed RPC credentials with approval, verify service activity, and prove a low-cycle alert reaches its owner.

## Historical implementation notes

The material below describes the earlier multi-canister system. Its deployment commands are outside the storefront release process.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v18 or higher)
- **npm** or **yarn**
- **IC SDK (dfx)** - [Installation Guide](https://internetcomputer.org/docs/current/developer-docs/setup/install/)
- **Rust toolchain** (for backend canisters) - [Install Rust](https://rustup.rs/)

## Project Structure

```
reimagined-octo-couscous/
├── src/
│   ├── canisters/          # Motoko backend canisters
│   │   ├── rewards/        # Rewards canister
│   │   │   ├── main.mo
│   │   │   ├── rewards.did
│   │   │   └── Types.mo
│   │   ├── lending/        # Lending canister
│   │   │   ├── main.mo
│   │   │   ├── lending.did
│   │   │   └── Types.mo
│   │   ├── portfolio/      # Portfolio canister
│   │   │   ├── main.mo
│   │   │   └── portfolio.did
│   │   ├── swap/           # Swap canister
│   │   │   ├── main.mo
│   │   │   ├── swap.did
│   │   │   └── Types.mo
│   │   └── shared/         # Shared utilities
│   │       ├── BitcoinUtils.mo
│   │       ├── BitcoinUtilsStub.mo
│   │       └── Types.mo
│   ├── components/         # React components
│   │   ├── Header.tsx
│   │   ├── ShopView.tsx
│   │   ├── LendView.tsx
│   │   ├── PortfolioView.tsx
│   │   ├── SwapView.tsx
│   │   └── Footer.tsx
│   ├── hooks/              # Custom React hooks
│   │   ├── useICP.ts
│   │   ├── useRewards.ts
│   │   ├── useLending.ts
│   │   ├── usePortfolio.ts
│   │   ├── useSwap.ts
│   │   └── useBitcoin.ts   # Bitcoin queries via Validation Cloud
│   ├── services/           # ICP integration services
│   │   ├── icp.ts
│   │   └── validationcloud.ts  # Validation Cloud Bitcoin RPC client
│   ├── types/              # TypeScript types
│   │   ├── index.ts
│   │   └── canisters.ts
│   ├── config/             # Configuration
│   │   └── env.ts
│   ├── App.tsx
│   ├── main.tsx
│   └── index.css
├── bitcoin_data/           # Bitcoin regtest data
├── dfx.json                # ICP canister configuration
├── mop.json                # Mops dependencies
├── package.json
├── DEPLOYMENT.md           # Deployment guide
├── vite.config.ts
└── tailwind.config.js
```

## Getting Started

### 1. Install Dependencies

```bash
npm install
```

**Note**: If `ic-siwb-identity` is not available on npm, you may need to install it from GitHub:
```bash
npm install github:AstroxNetwork/ic-siwb#main
# Or clone the repository and link it locally
```

### 2. Configure Environment Variables

Copy the example environment file and configure it:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
# For local development
VITE_ICP_NETWORK=local
# Internet Identity must be deployed locally first - see INTERNET_IDENTITY_SETUP.md
# After deploying, get the canister ID with: dfx canister id internet_identity
# VITE_INTERNET_IDENTITY_URL=http://localhost:4943?canisterId=<your-actual-canister-id>

# For production
# VITE_ICP_NETWORK=ic
# VITE_INTERNET_IDENTITY_URL=https://identity.ic0.app
# VITE_CANISTER_ID_REWARDS=your-rewards-canister-id
# VITE_CANISTER_ID_LENDING=your-lending-canister-id
# VITE_CANISTER_ID_PORTFOLIO=your-portfolio-canister-id

# Validation Cloud Bitcoin API (Optional - for enhanced Bitcoin queries)
# Get your API key from https://validationcloud.io/
# VITE_VALIDATION_CLOUD_API_KEY=your_validation_cloud_api_key
# VITE_BITCOIN_NETWORK=testnet  # or 'mainnet' for production
```

**Note:** For local development, you must deploy Internet Identity first. See `INTERNET_IDENTITY_SETUP.md` for detailed instructions. Alternatively, you can use Bitcoin wallet authentication which doesn't require Internet Identity.

### 3. Start Local ICP Network (Development)

Start the local Internet Computer network:

```bash
dfx start --clean
```

For Bitcoin integration, start with Bitcoin support:

```bash
dfx start --enable-bitcoin --background
```

### 4. Deploy Canisters (Optional - For Backend Development)

If you have backend canisters ready:

```bash
dfx deploy
```

This will deploy:
- `rewards_canister` - Handles shopping rewards tracking
- `lending_canister` - Manages crypto lending operations
- `portfolio_canister` - Tracks user portfolios

### 5. Run the Development Server

Start the Vite development server:

```bash
npm run dev
```

The application will be available at `http://localhost:5173`

## Development Workflow

### Running in Development Mode

```bash
# Terminal 1: Start ICP network
dfx start

# Terminal 2: Run frontend
npm run dev
```

### Building for Production

```bash
npm run build
```

This creates optimized production files in the `dist/` directory.

### Deploying to ICP

**Note:** ICP has only two deployment options:
- **Local** (`dfx start`) - Free, for development
- **Mainnet** (`dfx deploy --network ic`) - Requires cycles (costs ICP)

There is no free ICP testnet. See `MAINNET_DEPLOYMENT.md` for complete deployment guide.

1. Build the frontend:
   ```bash
   npm run build
   ```

2. Deploy to ICP mainnet:
   ```bash
   dfx deploy --network ic shopping_rewards_frontend
   ```

3. Get the frontend canister URL:
   ```bash
   dfx canister --network ic id shopping_rewards_frontend
   ```

## Project Architecture

### Frontend (React + TypeScript)

- **Components**: Reusable UI components following React best practices
- **Hooks**: Custom hooks for data fetching and state management
- **Services**: ICP authentication and canister interaction services
- **Types**: TypeScript interfaces for type safety

### ICP Integration

- **Internet Identity**: User authentication using ICP's identity provider
- **Canister Actors**: Type-safe interfaces for backend canister communication
- **Agent Management**: HTTP agent for making authenticated canister calls

### Current Implementation Status

- ✅ Frontend UI complete
- ✅ Internet Identity authentication setup
- ✅ Type-safe canister interfaces defined
- ⚠️ Mock data in use (canister integration pending)
- ⚠️ Backend canisters need to be implemented

## Backend Canisters Implemented ✅

The project now includes four Motoko canisters:

1. **Rewards Canister** (`src/canisters/rewards/`)
   - Store management and purchase tracking
   - Bitcoin reward calculation and distribution
   - User reward address generation (placeholder)
   - Reward claiming with Bitcoin transaction support (pending full Bitcoin library)

2. **Lending Canister** (`src/canisters/lending/`)
   - Asset management (BTC, ETH, SOL)
   - Deposit and withdrawal functionality
   - Bitcoin custody and UTXO management
   - Dynamic APY tracking

3. **Portfolio Canister** (`src/canisters/portfolio/`)
   - Cross-canister data aggregation
   - Portfolio balance calculation
   - USD value conversion

4. **Swap Canister** (`src/canisters/swap/`) 🆕
   - Chain-Key Token swaps (ckBTC, ckETH, ICP)
   - Automated Market Maker (AMM) pools
   - Real-time price quotes with slippage protection
   - Swap history tracking
   - ckBTC deposit/withdrawal via ICP Bitcoin integration

## Next Steps

To complete the full implementation:

1. **Install Bitcoin Libraries**:
   ```bash
   mops install
   ```
   Note: Bitcoin libraries are currently stubbed pending publication of motoko-bitcoin packages

2. **Connect Frontend to Canisters**:
   - Replace mock data in hooks with actual canister calls
   - Update `useRewards`, `useLending`, and `usePortfolio` hooks
   - Add error handling and loading states

3. **Complete Bitcoin Integration**:
   - Implement full Bitcoin address generation
   - Add ECDSA signing and verification
   - Integrate with ICP Bitcoin API
   - Implement transaction building and broadcasting

4. **Deploy and Test**:
   - See DEPLOYMENT.md for detailed deployment instructions
   - Test on Bitcoin regtest network
   - Add comprehensive error handling

## Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

## Technology Stack

- **Frontend Framework**: React 18 with TypeScript
- **Build Tool**: Vite
- **Styling**: Tailwind CSS + Next UI
- **ICP Integration**: @dfinity/agent, @dfinity/auth-client
- **Bitcoin Integration**: Validation Cloud RPC API (optional)
- **Icons**: Lucide React

## Validation Cloud Integration

The application includes optional Validation Cloud integration for enhanced Bitcoin queries from the frontend. Validation Cloud provides:

- **Bitcoin RPC API**: Access to Bitcoin mainnet/testnet via RPC
- **Blockbook Indexer**: Enhanced blockchain data queries
- **Esplora API**: Additional Bitcoin data access

### Usage

Validation Cloud is used for:
- Frontend Bitcoin balance and transaction queries
- Address validation
- Block height monitoring
- Transaction details lookup

**Note**: For canister-side Bitcoin operations, continue using ICP's Bitcoin API.

### Example Usage

```typescript
import { getValidationCloudClient } from '@/services/validationcloud'
import { useBitcoinBlockHeight, useBitcoinAddressValidation } from '@/hooks/useBitcoin'

// In a component
function MyComponent() {
  const { height, loading } = useBitcoinBlockHeight()
  const { isValid } = useBitcoinAddressValidation('bc1q...')
  
  // Or use the client directly
  const client = getValidationCloudClient()
  const info = await client.getBlockchainInfo()
}
```

## Contributing

This project follows React and TypeScript best practices:

- Use functional components with TypeScript interfaces
- Follow the RORO (Receive an Object, Return an Object) pattern
- Use named exports for components
- Implement proper error handling and loading states

## License

BSD 3-Clause License - See LICENSE file for details

## Resources

- [Internet Computer Documentation](https://internetcomputer.org/docs/current/developer-docs/)
- [ICP React Quickstart](https://internetcomputer.org/docs/current/developer-docs/quickstart/hello10mins)
- [Internet Identity Guide](https://internetcomputer.org/docs/current/developer-docs/integrations/internet-identity/)
- [Vite Documentation](https://vitejs.dev/)
- [React Documentation](https://react.dev/)

