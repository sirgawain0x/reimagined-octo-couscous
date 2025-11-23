import { defineConfig } from 'vitest/config'
import path from 'path'

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      '**/e2e/**', // Exclude E2E tests (they require Playwright)
    ],
    env: {
      VITE_CANISTER_ID_REWARDS: process.env.VITE_CANISTER_ID_REWARDS || 'rrkah-fqaaa-aaaaa-aaaaq-cai',
      VITE_CANISTER_ID_PORTFOLIO: process.env.VITE_CANISTER_ID_PORTFOLIO || 'rrkah-fqaaa-aaaaa-aaaaq-cai',
      VITE_CANISTER_ID_SWAP: process.env.VITE_CANISTER_ID_SWAP || 'rrkah-fqaaa-aaaaa-aaaaq-cai',
      VITE_CANISTER_ID_LENDING: process.env.VITE_CANISTER_ID_LENDING || 'rrkah-fqaaa-aaaaa-aaaaq-cai',
    },
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'dist/',
        '**/*.d.ts',
        '**/*.config.*',
        '**/test/**',
        '**/__tests__/**',
      ],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  define: {
    'import.meta.env.VITE_CANISTER_ID_REWARDS': JSON.stringify(process.env.VITE_CANISTER_ID_REWARDS || 'rrkah-fqaaa-aaaaa-aaaaq-cai'),
    'import.meta.env.VITE_CANISTER_ID_PORTFOLIO': JSON.stringify(process.env.VITE_CANISTER_ID_PORTFOLIO || 'rrkah-fqaaa-aaaaa-aaaaq-cai'),
    'import.meta.env.VITE_CANISTER_ID_SWAP': JSON.stringify(process.env.VITE_CANISTER_ID_SWAP || 'rrkah-fqaaa-aaaaa-aaaaq-cai'),
    'import.meta.env.VITE_CANISTER_ID_LENDING': JSON.stringify(process.env.VITE_CANISTER_ID_LENDING || 'rrkah-fqaaa-aaaaa-aaaaq-cai'),
  },
})

