# syntax=docker/dockerfile:1.7

FROM node:18.19.0-alpine3.19 AS deps
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

FROM node:18.19.0-alpine3.19 AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG VITE_API_URL=http://localhost:8080/api
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

FROM nginx:1.31.1-alpine AS runtime


RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx/conf.d


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

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
