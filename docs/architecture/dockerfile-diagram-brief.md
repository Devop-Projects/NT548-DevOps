# Dockerfile Diagram Brief

File này dùng để chuẩn bị nội dung vẽ diagram/slide cho phần Dockerfile của project. Mục tiêu không phải giải thích toàn bộ Docker Compose, mà là chọn đúng thông tin quan trọng để thầy hiểu:

- Dockerfile backend đang build image như thế nào.
- Dockerfile frontend đang build image như thế nào.
- Vì sao dùng multi-stage build.
- Image runtime cuối cùng chứa gì và chạy bằng gì.
- Những điểm thể hiện tư duy DevOps: nhỏ gọn, reproducible, non-root, healthcheck, tách build-time và runtime.

## 1. Thông điệp chính của slide

Thông điệp nên truyền đạt:

```text
Project không chạy app trực tiếp bằng npm trên server.
Project đóng gói backend và frontend thành Docker image riêng.
Mỗi image được build theo multi-stage để giảm kích thước, tăng bảo mật,
và tạo artifact ổn định cho CI/CD, Docker Hub, Kubernetes.
```

Nên để câu này ở đầu slide:

```text
Dockerfiles turn source code into deployable, reproducible runtime images.
```

Hoặc bản tiếng Việt:

```text
Dockerfile biến source code thành image runtime có thể deploy nhất quán.
```

## 2. Nên vẽ tổng quan như thế nào?

Vẽ 2 lane song song:

```text
Backend Dockerfile                         Frontend Dockerfile
Node.js runtime image                      Nginx static runtime image
```

Layout gợi ý:

```text
┌──────────────────────────┐        ┌──────────────────────────┐
│ Backend Dockerfile        │        │ Frontend Dockerfile       │
│ Node.js + Express API     │        │ React/Vite + Nginx        │
└─────────────┬────────────┘        └─────────────┬────────────┘
              │                                   │
              v                                   v
      deps stage                          deps stage
      npm ci --omit=dev                   npm ci
              │                                   │
              v                                   v
      runtime stage                       builder stage
      node src/app.js                     npm run build
                                                  │
                                                  v
                                          runtime stage
                                          nginx serves dist/
```

Phần cuối nên gom lại:

```text
Final images are pushed by CI to Docker Hub and later pulled by Kubernetes.
```

## 3. Backend Dockerfile: nội dung cần vẽ

File:

```text
app/mono/backend/Dockerfile
```

Mục tiêu:

```text
Build Docker image cho Node.js Express backend.
```

Nên vẽ thành 2 stage:

### Stage 1: deps

Text ngắn trên diagram:

```text
deps stage
node:18.19-alpine
npm ci --omit=dev
```

Ý nghĩa để thuyết trình:

```text
Stage này chỉ cài production dependencies từ package-lock.json.
npm ci giúp build lặp lại chính xác theo lockfile.
--omit=dev loại bỏ devDependencies để runtime image nhỏ hơn và ít rủi ro hơn.
```

Chi tiết kỹ thuật quan trọng:

```dockerfile
FROM node:18.19.0-alpine3.19 AS deps
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev
```

Điểm đáng nói:

- Dùng `node:18.19.0-alpine3.19`: base image nhẹ.
- Copy `package*.json` trước khi copy source: tận dụng Docker layer cache.
- Dùng BuildKit cache cho npm: build nhanh hơn trong local/CI.
- Chỉ cài dependency production: image cuối ít dư thừa hơn.

### Stage 2: runtime

Text ngắn trên diagram:

```text
runtime stage
copy node_modules + src
USER node
EXPOSE 3000
node src/app.js
```

Ý nghĩa để thuyết trình:

```text
Stage runtime chỉ chứa những thứ cần để chạy API:
node_modules production, package metadata và source code.
Container chạy bằng user node thay vì root.
```

Chi tiết kỹ thuật quan trọng:

```dockerfile
FROM node:18.19.0-alpine3.19 AS runtime
ENV NODE_ENV=production PORT=3000
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package*.json ./
COPY --chown=node:node src/ ./src/
USER node
EXPOSE 3000
CMD ["node", "src/app.js"]
```

Điểm đáng nói:

- `NODE_ENV=production`: app chạy theo mode production.
- `COPY --from=deps`: lấy dependency từ stage trước, không cài lại.
- `--chown=node:node`: file thuộc user `node`.
- `USER node`: giảm rủi ro nếu container bị khai thác.
- `EXPOSE 3000`: backend lắng nghe port 3000.
- `CMD ["node", "src/app.js"]`: process chính của container.

### Backend healthcheck

Text ngắn trên diagram:

```text
Healthcheck
/health/live
```

Ý nghĩa để thuyết trình:

```text
Image có healthcheck để Docker biết container còn sống không,
thay vì chỉ biết process Node còn chạy.
```

Chi tiết:

```dockerfile
HEALTHCHECK CMD wget --spider http://localhost:3000/health/live || exit 1
```

Nên vẽ icon nhỏ:

```text
heart/check icon -> /health/live
```

## 4. Frontend Dockerfile: nội dung cần vẽ

File:

```text
app/mono/frontend/Dockerfile
```

Mục tiêu:

```text
Build React/Vite frontend thành static files, sau đó serve bằng Nginx.
```

Nên vẽ thành 3 stage:

### Stage 1: deps

Text ngắn trên diagram:

```text
deps stage
node:18.19-alpine
npm ci
```

Ý nghĩa để thuyết trình:

```text
Stage này cài dependencies cần cho build frontend.
Frontend cần dev dependencies vì Vite build tool nằm ở devDependencies.
```

Chi tiết:

```dockerfile
FROM node:18.19.0-alpine3.19 AS deps
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
```

Điểm đáng nói:

- Dùng `npm ci` để build nhất quán theo lockfile.
- Không dùng `--omit=dev` vì cần Vite để build.
- Dùng cache npm để tăng tốc build.

### Stage 2: builder

Text ngắn trên diagram:

```text
builder stage
copy source
VITE_API_URL
npm run build
output: dist/
```

Ý nghĩa để thuyết trình:

```text
Stage builder biến source React/Vite thành static assets trong thư mục dist.
Biến VITE_API_URL được inject ở build-time, nên muốn đổi API URL thì cần rebuild image.
```

Chi tiết:

```dockerfile
FROM node:18.19.0-alpine3.19 AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ARG VITE_API_URL=http://localhost:8080/api
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build
```

Điểm đáng nói:

- Builder dùng Node vì cần chạy Vite build.
- `ARG VITE_API_URL`: cấu hình API URL tại thời điểm build.
- Output sau build là `dist/`.
- Source code và node_modules không cần xuất hiện trong runtime image cuối.

### Stage 3: runtime

Text ngắn trên diagram:

```text
runtime stage
nginx:1.25-alpine
copy dist/
serve on 8080
USER nginx
```

Ý nghĩa để thuyết trình:

```text
Runtime image không chạy Node.js.
Nó chỉ dùng Nginx để serve static files đã build.
Điều này làm image gọn hơn và gần với cách frontend chạy trong production.
```

Chi tiết:

```dockerfile
FROM nginx:1.25.3-alpine AS runtime
COPY --from=builder --chown=nginx:nginx /app/dist /usr/share/nginx/html
USER nginx
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
```

Điểm đáng nói:

- Runtime dùng Nginx, không dùng Vite dev server.
- Chỉ copy `dist/` từ builder stage.
- Chạy bằng user `nginx`, không chạy root.
- Expose port `8080`.
- `daemon off` giúp Nginx chạy foreground làm process chính của container.

### Nginx config cho SPA và API proxy

Text ngắn trên diagram:

```text
Nginx
/ -> React SPA
/api -> backend:3000
```

Ý nghĩa để thuyết trình:

```text
Nginx vừa serve React app, vừa proxy request /api tới backend service.
React Router cần fallback về index.html để refresh trang không bị 404.
```

Chi tiết quan trọng:

```nginx
location / {
  root /usr/share/nginx/html;
  try_files $uri $uri/ /index.html;
}

location /api/ {
  proxy_pass http://backend:3000/;
}
```

Điểm đáng nói:

- `try_files ... /index.html`: hỗ trợ SPA routing.
- `/api/ -> backend:3000`: frontend container gọi backend bằng service name.
- `backend` là DNS name trong Docker network hoặc service name trong môi trường deploy tương ứng.

## 5. Những gì nên đưa lên slide

Slide không nên đưa full Dockerfile. Nên đưa các block sau:

```text
Backend Image
1. deps: npm ci --omit=dev
2. runtime: copy src + production node_modules
3. security: USER node
4. health: /health/live
5. start: node src/app.js
```

```text
Frontend Image
1. deps: npm ci
2. builder: npm run build -> dist/
3. runtime: nginx serves dist/
4. proxy: /api -> backend:3000
5. security: USER nginx
```

```text
Why it matters
- Smaller runtime images
- Reproducible builds from lockfiles
- Faster builds using Docker cache
- Non-root containers
- Clear separation between build-time and runtime
- Images become artifacts for CI/CD and Kubernetes
```

## 6. Những gì không nên đưa lên slide này

Không nên đưa quá nhiều phần sau vào slide Dockerfile:

- Toàn bộ `docker-compose.yml`.
- Adminer.
- Resource limit.
- Logging driver.
- Volume Postgres.
- Tất cả biến môi trường trong Compose.
- Lệnh troubleshooting dài.

Các phần đó phù hợp với Docker Compose/Local Deployment slide riêng. Slide này chỉ nên giải thích Dockerfile và image build.

## 7. Diagram đề xuất cho slide

Vẽ theo dạng pipeline 2 hàng:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Backend Dockerfile                                                    │
│ Source + package-lock                                                 │
│      -> deps: npm ci --omit=dev                                       │
│      -> runtime: Node.js + src + production node_modules              │
│      -> USER node -> EXPOSE 3000 -> /health/live -> node src/app.js   │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ Frontend Dockerfile                                                   │
│ Source + package-lock                                                 │
│      -> deps: npm ci                                                  │
│      -> builder: VITE_API_URL + npm run build -> dist/                │
│      -> runtime: Nginx + dist/ -> / and /api proxy -> USER nginx      │
└──────────────────────────────────────────────────────────────────────┘

Both final images -> Docker Hub -> Kubernetes pulls image tags from GitOps config
```

## 8. Text ngắn đặt cạnh diagram

Có thể đặt bên phải slide:

```text
Key Dockerfile decisions

Multi-stage build:
  keep build tools out of runtime image

Lockfile-based install:
  reproducible dependency install with npm ci

Runtime hardening:
  run containers as non-root users

Production serving:
  backend uses Node.js
  frontend uses Nginx, not Vite dev server

CI/CD artifact:
  final images are scanned, tagged by commit SHA, and pushed to Docker Hub
```

## 9. Speaker notes ngắn

Có thể nói khi thuyết trình:

```text
Ở phần Dockerfile, em tách backend và frontend thành hai image riêng.
Backend là Node.js runtime image, chỉ chứa production dependencies và source code cần chạy API.
Frontend dùng multi-stage: Node chỉ dùng để build React/Vite, còn runtime cuối dùng Nginx để serve static files.

Cả hai image đều tránh chạy bằng root user.
Backend có healthcheck để kiểm tra endpoint /health/live.
Frontend có Nginx config để hỗ trợ SPA routing và proxy /api sang backend.

Sau khi CI build xong, image được scan bằng Trivy, tag theo commit SHA, push lên Docker Hub.
Kubernetes sau đó chỉ pull image đã build sẵn, không build trực tiếp trong cluster.
```

## 10. Nếu chỉ có 1 slide

Nếu chỉ được dùng một slide, ưu tiên vẽ:

```text
Source Code
   |
   v
Backend Dockerfile: deps -> runtime -> Node API image

Frontend Dockerfile: deps -> builder -> Nginx runtime image
   |
   v
Docker Hub images tagged by commit SHA
   |
   v
Kubernetes pulls images through GitOps config
```

Và chỉ ghi 4 keyword lớn:

```text
Multi-stage
Reproducible
Non-root
CI/CD artifact
```
