import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

import { affiliateCatalog } from './src/config/affiliate-catalog'

export default defineConfig(({ mode, command }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_')
  affiliateCatalog({
    Amazon: env.VITE_AMAZON_AFFILIATE_LINK,
    Walmart: env.VITE_WALMART_AFFILIATE_LINK,
    eBay: env.VITE_EBAY_AFFILIATE_LINK,
  })
  if (command === 'build' && mode === 'production') {
    if (env.VITE_ICP_NETWORK && env.VITE_ICP_NETWORK !== 'ic') {
      throw new Error('Production builds require the ic network. Use --mode development for local builds.')
    }
    if (env.VITE_INTERNET_IDENTITY_URL && ![
      'https://identity.ic0.app', 'https://id.ai',
    ].includes(env.VITE_INTERNET_IDENTITY_URL)) {
      throw new Error('Use the default Internet Identity provider for production builds.')
    }
  }
  return {
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
      dedupe: ['react', 'react-dom'],
    },
    optimizeDeps: {
      include: [
        'react',
        'react-dom',
        '@dfinity/agent',
        '@dfinity/auth-client',
        '@dfinity/candid',
        '@dfinity/principal',
      ],
    },
    server: {
      port: 5173,
      host: true,
    },
    build: {
      commonjsOptions: {
        include: [/node_modules/],
        transformMixedEsModules: true,
      },
      chunkSizeWarningLimit: 600, // Increase limit slightly to reduce warnings
    },
  }
})
