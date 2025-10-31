# ICP Shopping Rewards Platform

A decentralized shopping rewards platform built on the Internet Computer Protocol (ICP) that allows users to earn Bitcoin rewards while shopping and provides lending services for BTC, ETH, and SOL.

## Features

- 🛍️ **Shop & Earn**: Browse partner stores and earn Bitcoin rewards on purchases
- 💰 **Crypto Lending**: Lend Bitcoin, Ethereum, and Solana to earn interest
- 🔄 **Token Swaps**: Swap ckBTC, ckETH, and ICP with Chain-Key integration
- 📊 **Portfolio Dashboard**: Track your assets, rewards, and lending positions
- 🔐 **Authentication**: Sign in with Internet Identity or Bitcoin wallet (Sign-in with Bitcoin)
- 🎨 **Modern UI**: Built with React, TypeScript, Tailwind CSS, and Next UI

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
│   │   └── useSwap.ts
│   ├── services/           # ICP integration services
│   │   └── icp.ts
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

1. Build the frontend:
   ```bash
   npm run build
   ```

2. Deploy to ICP:
   ```bash
   dfx deploy shopping_rewards_frontend
   ```

3. Get the frontend canister URL:
   ```bash
   dfx canister id shopping_rewards_frontend
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
- **Icons**: Lucide React

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

