# syntax=docker/dockerfile:1.7

# ============================================================================
# Stage 1: Dependencies — Cài đặt node_modules
# ============================================================================
FROM node:18.19.0-alpine3.19 AS deps
WORKDIR /app
COPY package*.json ./
# Sử dụng Cache Mount để tăng tốc build và giữ Image sạch rác
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# ============================================================================
# Stage 2: Builder — Biên dịch code React sang file tĩnh (dist)
# ============================================================================
FROM node:18.19.0-alpine3.19 AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Truyền biến môi trường lúc build (Vite cần cái này)
ARG VITE_API_URL=http://localhost:8080/api
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

# ============================================================================
# Stage 3: Runtime — Sử dụng Nginx (Non-root) để serve file
# ============================================================================
FROM nginx:1.25.3-alpine AS runtime

# Thiết lập quyền non-root cho Nginx (vì port 80 yêu cầu quyền root)
# Chúng ta sẽ chuyển sang chạy ở cổng 8080
RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx/conf.d

# Copy file đã build từ stage builder sang kho của Nginx
COPY --from=builder --chown=nginx:nginx /app/dist /usr/share/nginx/html

# Ghi đè file cấu hình Nginx (Chạy ở cổng 8080 và hỗ trợ SPA/Proxy)
RUN echo 'server { \
    listen 8080; \
    location / { \
        root /usr/share/nginx/html; \
        try_files $uri $uri/ /index.html; \
    } \
    location /api/ { \
        proxy_pass http://backend:3000/; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Chuyển sang user nginx (không có quyền root)
USER nginx

EXPOSE 8080

# Chạy Nginx ở chế độ foreground
CMD ["nginx", "-g", "daemon off;"]
