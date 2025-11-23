import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
    dedupe: ['react', 'react-dom'],
  },
  optimizeDeps: {
    exclude: ['ic-siwb-identity'],
    include: [
      'react',
      'react-dom',
      '@dfinity/agent',
      '@dfinity/auth-client',
      '@dfinity/candid',
      '@dfinity/principal',
    ],
  },
  ssr: {
    noExternal: ['ic-use-siwb-identity'],
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
    rollupOptions: {
      output: {
        // Ensure proper chunk loading order
        // Vendor must load before dfinity to avoid initialization errors
        chunkFileNames: 'assets/[name]-[hash].js',
        manualChunks(id) {
          // Vendor chunks - split large dependencies
          if (id.includes('node_modules')) {
            // CRITICAL: React MUST load first before any other vendor code
            // React core libraries go to react-vendor chunk
            if (id.includes('react') || id.includes('react-dom') || id.includes('react/jsx-runtime')) {
              return 'react-vendor'
            }
            // React-dependent UI libraries must load after React
            // @radix-ui packages use React hooks, so they need React to be available
            if (id.includes('@radix-ui')) {
              return 'react-vendor' // Put with React to ensure React is available
            }
            // NextUI (depends on React, so loads after react-vendor)
            if (id.includes('@nextui-org')) {
              return 'nextui'
            }
            // Framer Motion (used by NextUI)
            if (id.includes('framer-motion')) {
              return 'nextui'
            }
            // Other large vendor libraries
            if (id.includes('lucide-react')) {
              return 'icons'
            }
            // CRITICAL FIX: Combine @dfinity with vendor to avoid initialization order issues
            // The dfinity packages call into vendor utilities that need to be initialized first
            // By keeping them together, we ensure proper initialization order
            if (id.includes('@dfinity/')) {
              return 'vendor' // Put dfinity in vendor chunk to avoid initialization race
            }
            // Everything else from node_modules goes to vendor
            // This now includes @dfinity packages to ensure proper initialization
            // Vendor loads after react-vendor, so React is available
            return 'vendor'
          }
          
          // Split our own code into logical chunks
          if (id.includes('/src/services/')) {
            return 'services'
          }
          if (id.includes('/src/hooks/')) {
            return 'hooks'
          }
          if (id.includes('/src/components/')) {
            // Components will be lazy-loaded, so they'll be in their own chunks
            return undefined
          }
        },
      },
    },
    chunkSizeWarningLimit: 600, // Increase limit slightly to reduce warnings
  },
})

