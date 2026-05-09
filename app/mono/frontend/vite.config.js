import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test-setup.js',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],   // ← THÊM 'lcov'
      exclude: ['node_modules/', 'dist/', '**/*.config.js'],
    },
  },
})