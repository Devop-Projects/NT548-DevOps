import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: true, // Bắt buộc khi chạy trong Docker
    allowedHosts: ['frontend', 'localhost'] // Cho phép tên miền nội bộ của Nginx đi qua
  }
})