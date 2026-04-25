# Stage 1: Build React app thành file HTML/CSS/JS tĩnh
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
# Truyền URL backend vào lúc build — Vite sẽ nhúng vào code
ARG VITE_API_URL=http://localhost:3000/api
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

# Stage 2: Dùng Nginx nhẹ để serve file tĩnh
# Không cần Node.js ở production — image cuối chỉ ~25MB
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html

# Cấu hình Nginx cho React Router (SPA)
RUN echo 'server { \
  listen 80; \
  location / { \
    root /usr/share/nginx/html; \
    try_files $uri $uri/ /index.html; \
  } \
  location /api { \
    proxy_pass http://backend:3000; \
  } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]