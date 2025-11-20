import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  optimizeDeps: {
    exclude: ['ic-siwb-identity'],
  },
  ssr: {
    noExternal: ['ic-use-siwb-identity'],
  },
  server: {
    port: 5173,
    host: true,
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          // Vendor chunks - split large dependencies
          if (id.includes('node_modules')) {
            // Dfinity packages
            if (id.includes('@dfinity/')) {
              return 'dfinity'
            }
            // NextUI
            if (id.includes('@nextui-org')) {
              return 'nextui'
            }
            // React core
            if (id.includes('react') || id.includes('react-dom') || id.includes('react/jsx-runtime')) {
              return 'react-vendor'
            }
            // Framer Motion (used by NextUI)
            if (id.includes('framer-motion')) {
              return 'nextui'
            }
            // Other large vendor libraries
            if (id.includes('lucide-react')) {
              return 'icons'
            }
            // Everything else from node_modules
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

