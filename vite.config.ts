import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [
    react(),
    // Plugin to ensure react-vendor loads before vendor
    {
      name: 'ensure-react-first',
      generateBundle(options, bundle) {
        // Find react-vendor and vendor chunks
        const reactVendorChunk = Object.keys(bundle).find(key => 
          key.includes('react-vendor') && key.endsWith('.js')
        )
        const vendorChunk = Object.keys(bundle).find(key => 
          key.includes('vendor') && !key.includes('react-vendor') && key.endsWith('.js')
        )
        
        // Note: Chunk dependencies are handled automatically by Rollup based on imports
        // This plugin ensures proper chunk organization
      },
      transformIndexHtml(html) {
        // Reorder modulepreload links to ensure react-vendor loads first
        return html.replace(
          /<link rel="modulepreload"[^>]*href="[^"]*react-vendor[^"]*"[^>]*>/,
          (match) => {
            // Remove it from current position and we'll add it first
            return ''
          }
        ).replace(
          /(<head[^>]*>)/,
          (match) => {
            // Find react-vendor link in the HTML
            const reactVendorLink = html.match(/<link rel="modulepreload"[^>]*href="[^"]*react-vendor[^"]*"[^>]*>/)?.[0]
            if (reactVendorLink) {
              return match + '\n    ' + reactVendorLink
            }
            return match
          }
        )
      },
    },
  ],
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
        chunkFileNames: 'assets/[name]-[hash].js',
        manualChunks(id, { getModuleInfo }) {
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
            // ic-use-siwb-identity might use React, move it to react-vendor to be safe
            if (id.includes('ic-use-siwb-identity') || id.includes('ic-siwb')) {
              return 'react-vendor'
            }
            // Check if this module depends on React
            const moduleInfo = getModuleInfo(id)
            if (moduleInfo) {
              // Check if this module is imported by React-dependent code
              const importedByReact = moduleInfo.importers?.some(importer => 
                importer.includes('react') || importer.includes('@radix-ui') || importer.includes('@nextui-org') || 
                importer.includes('/src/') // Our source code uses React
              ) || false
              
              // Check if this module is dynamically imported by anything that uses React
              // This catches transitive dependencies
              const hasReactDependency = moduleInfo.dynamicImporters?.some(importer => 
                importer.includes('react') || importer.includes('@radix-ui') || importer.includes('@nextui-org') ||
                importer.includes('/src/')
              ) || false
              
              // If this module is used by React code, put it in react-vendor
              if (importedByReact || hasReactDependency) {
                return 'react-vendor'
              }
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
            // ULTIMATE FIX: Move ALL other vendor code to react-vendor to ensure React is available
            // This prevents any vendor code from trying to access React before it's loaded
            // Only @dfinity stays in vendor chunk
            return 'react-vendor'
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

