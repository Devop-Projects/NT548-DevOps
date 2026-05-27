# Docker Manual Guide

Guide này dùng để hiểu phần Docker của `app/mono` trước khi để CI build image tự động trong GitHub Actions.

Thư mục làm việc:

```bash
cd ~/NT548-DevOps/app/mono
```

Các file chính:

```text
docker-compose.yml
backend/Dockerfile
frontend/Dockerfile
database/init.sql
.env
.env.example
.env.local
```

Ý chính: Docker không chỉ là "đóng gói app". Trong project này Docker đang mô phỏng gần giống môi trường deploy thật:

```text
Postgres container
        |
        v
migration one-off container
        |
        v
backend container
        |
        v
frontend nginx container
```

Docker Compose giúp chạy toàn bộ stack bằng một file, còn Dockerfile mô tả cách build từng image.

## 0. Docker đang thay thế việc gì?

Nếu không dùng Docker, bạn phải tự làm thủ công:

```bash
# Terminal 1: chạy database
install postgres
create database taskdb
create user taskuser
set password

# Terminal 2: chạy backend
cd app/mono/backend
npm ci
npm run migrate
npm start

# Terminal 3: chạy frontend
cd app/mono/frontend
npm ci
npm run build
npm run preview
```

Vấn đề khi chạy thủ công:

- Máy mỗi người có version Node, Postgres, npm khác nhau.
- Dễ quên migration.
- Dễ dùng nhầm database local.
- Frontend gọi sai backend URL.
- Không giống môi trường CI/CD vì CI build Docker image chứ không chạy app trực tiếp bằng `npm start`.

Docker giải quyết bằng cách đóng gói runtime và dependency vào image, sau đó Compose nối các container lại thành một hệ thống.

## 1. Chuẩn bị biến môi trường

Trong `app/mono`, repo có:

```text
.env          -> default values không nhạy cảm
.env.local    -> secret local như POSTGRES_PASSWORD, JWT_SECRET
.env.example  -> mẫu để tạo .env.local
```

Docker Compose tự đọc file `.env`, nhưng không tự đọc `.env.local`.

Vì vậy khi chạy project này, dùng:

```bash
docker compose --env-file .env --env-file .env.local config
```

Lệnh `config` không chạy container. Nó chỉ render file Compose sau khi resolve biến môi trường.

Nếu thiếu secret, bạn sẽ thấy lỗi kiểu:

```text
POSTGRES_PASSWORD must be set
JWT_SECRET must be set
```

Tạo `.env.local` nếu chưa có:

```bash
cp .env.example .env.local
```

Sau đó sửa:

```text
POSTGRES_PASSWORD=<password-dev>
JWT_SECRET=<secret-it-nhat-32-ky-tu>
```

Không nên commit secret thật lên git.

## 2. Kiểm tra Compose file trước khi chạy

Manual command:

```bash
docker compose --env-file .env --env-file .env.local config
```

Lý do cần bước này:

- Bắt lỗi YAML trước khi tạo container.
- Bắt lỗi thiếu biến môi trường.
- Xem giá trị cuối cùng của port, network, volume, environment.

Nếu `config` pass, Compose file đã hợp lệ về mặt cú pháp và biến môi trường.

## 3. Build image thủ công

Trước khi chạy cả stack, có thể build từng image để hiểu Dockerfile.

Backend:

```bash
docker build \
  -t nt548-backend:local \
  -f backend/Dockerfile \
  ./backend
```

Frontend:

```bash
docker build \
  -t nt548-frontend:local \
  -f frontend/Dockerfile \
  --build-arg VITE_API_URL=/api \
  ./frontend
```

Kiểm tra image:

```bash
docker images | grep nt548
```

Trong CI, GitHub Actions cũng làm tương tự, nhưng tag image theo commit SHA và có thêm bước scan bằng Trivy.

## 4. Backend Dockerfile

File:

```text
backend/Dockerfile
```

Flow chính:

```text
deps stage
  |
  | npm ci --omit=dev
  v
runtime stage
  |
  | copy node_modules + package.json + src
  v
node src/app.js
```

Dockerfile dùng multi-stage build:

```dockerfile
FROM node:18.19.0-alpine3.19 AS deps
```

Stage `deps` chỉ dùng để cài dependency production:

```dockerfile
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev
```

Vì sao dùng `npm ci --omit=dev`?

- `npm ci` cài đúng theo `package-lock.json`.
- `--omit=dev` bỏ devDependencies khỏi image runtime.
- Image nhỏ hơn và ít surface bảo mật hơn.

Stage runtime:

```dockerfile
FROM node:18.19.0-alpine3.19 AS runtime
```

Chỉ copy những thứ cần để chạy app:

```text
node_modules
package*.json
src/
```

Dockerfile chạy bằng user không phải root:

```dockerfile
USER node
```

Lý do: nếu app bị khai thác, attacker không có quyền root bên trong container.

Backend expose port:

```dockerfile
EXPOSE 3000
```

và chạy:

```dockerfile
CMD ["node", "src/app.js"]
```

Healthcheck trong image:

```text
http://localhost:3000/health/live
```

Lý do: Docker có thể biết container còn sống không, thay vì chỉ biết process Node còn chạy.

## 5. Frontend Dockerfile

File:

```text
frontend/Dockerfile
```

Flow chính:

```text
deps stage
  |
  | npm ci
  v
builder stage
  |
  | npm run build
  v
runtime stage nginx
  |
  | serve static files + proxy /api
  v
nginx -g "daemon off;"
```

Frontend khác backend ở chỗ React/Vite không cần Node để chạy production. Sau khi build xong, output nằm ở:

```text
dist/
```

Runtime image dùng Nginx:

```dockerfile
FROM nginx:1.25.3-alpine AS runtime
```

Lý do:

- Nginx phục vụ static file tốt hơn Node dev server.
- Image runtime không cần source code và node_modules.
- Gần giống cách frontend thường chạy trong production.

Build arg:

```dockerfile
ARG VITE_API_URL=http://localhost:8080/api
ENV VITE_API_URL=$VITE_API_URL
```

Khi build bằng Compose:

```yaml
args:
  VITE_API_URL: ${VITE_API_URL:-http://localhost:3000/api}
```

Với Vite, biến `VITE_*` được inject ở build-time. Nghĩa là đổi `VITE_API_URL` sau khi image đã build không tự đổi bundle frontend. Muốn đổi URL, cần rebuild image.

Nginx config trong Dockerfile có 2 phần quan trọng:

```text
location /      -> serve React SPA, fallback về index.html
location /api/  -> proxy request API tới backend:3000
```

`backend` là tên service trong Docker Compose. Các container cùng network có thể gọi nhau bằng service name.

## 6. Network trong docker-compose.yml

Compose tạo 2 network:

```yaml
frontend-net:
  driver: bridge

backend-net:
  driver: bridge
  internal: true
```

Ý nghĩa:

```text
frontend-net -> frontend và backend cùng tham gia
backend-net  -> backend, migrate, postgres cùng tham gia
```

Postgres chỉ nằm trong `backend-net`. Network này có:

```yaml
internal: true
```

Lý do: database không cần internet và không nên public ra ngoài. Đây là defense in depth ở mức network.

Quan hệ network:

```text
Browser
  |
  v
frontend container
  |
  | /api proxy
  v
backend container
  |
  v
postgres container
```

Backend nằm ở cả 2 network vì nó là cầu nối giữa frontend và database.

## 7. Volume cho Postgres

Compose khai báo:

```yaml
volumes:
  postgres_data:
    name: ${COMPOSE_PROJECT_NAME:-mono}_postgres_data
```

Postgres mount:

```yaml
postgres_data:/var/lib/postgresql/data
```

Lý do: dữ liệu database phải sống lâu hơn container. Nếu container bị xóa mà volume còn, data vẫn còn.

Kiểm tra volume:

```bash
docker volume ls | grep postgres_data
```

Xóa container không xóa volume:

```bash
docker compose --env-file .env --env-file .env.local down
```

Xóa cả data:

```bash
docker compose --env-file .env --env-file .env.local down -v
```

Chỉ dùng `down -v` khi bạn chấp nhận mất database local.

## 8. Postgres service

Service:

```text
postgres
```

Image:

```yaml
image: postgres:15.5-alpine
```

Environment:

```text
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
```

`POSTGRES_PASSWORD` bắt buộc:

```yaml
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set}
```

Lý do: nếu thiếu password thì fail sớm, không chạy database với config rỗng hoặc sai.

Postgres có init script:

```yaml
./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
```

Script trong thư mục `/docker-entrypoint-initdb.d/` chỉ chạy khi database volume lần đầu được khởi tạo. Nếu volume đã tồn tại, script không chạy lại.

Vì vậy nếu sửa `database/init.sql` mà không thấy tác dụng, nguyên nhân thường là volume cũ vẫn còn.

## 9. Healthcheck của Postgres

Compose dùng:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-taskuser} -d ${POSTGRES_DB:-taskdb}"]
```

Lý do: `depends_on` mặc định chỉ đợi container start, không đợi database sẵn sàng nhận connection.

Với healthcheck, service khác có thể đợi:

```yaml
depends_on:
  postgres:
    condition: service_healthy
```

Điều này tránh lỗi backend hoặc migration chạy quá sớm khi Postgres chưa ready.

## 10. Migration container

Service:

```text
migrate
```

Command:

```yaml
command: npm run migrate
```

Migration là one-off task:

```yaml
restart: "no"
```

Nó chạy sau khi Postgres healthy:

```yaml
depends_on:
  postgres:
    condition: service_healthy
```

Vì sao migration tách khỏi backend?

- Migration là task chạy một lần rồi kết thúc.
- Backend là service chạy lâu dài.
- Nếu gộp migration vào startup backend, nhiều replica backend có thể cùng chạy migration.
- Tách riêng giúp quan sát lỗi schema rõ hơn.

Manual command để chạy riêng migration:

```bash
docker compose --env-file .env --env-file .env.local up migrate
```

Xem log migration:

```bash
docker logs task-migrate
```

Nếu muốn chạy lại migration trong lab:

```bash
docker compose --env-file .env --env-file .env.local rm -f migrate
docker compose --env-file .env --env-file .env.local up migrate
```

## 11. Backend service

Service:

```text
backend
```

Build:

```yaml
build:
  context: ./backend
  target: runtime
```

`target: runtime` nghĩa là Compose build đến stage runtime trong Dockerfile.

Backend cần:

```text
DATABASE_URL
JWT_SECRET
JWT_EXPIRES_IN
LOG_LEVEL
PORT
```

Trong Compose, backend connect database bằng service name:

```text
postgres://taskuser:<password>@postgres:5432/taskdb
```

Ở đây `postgres` không phải localhost. Nó là DNS name nội bộ của service Postgres trong Docker network.

Nếu chạy backend ngoài Docker thì dùng `localhost`. Nếu chạy backend trong Docker thì dùng `postgres`.

Backend publish port:

```yaml
ports:
  - "${BACKEND_PORT:-3000}:3000"
```

Nghĩa là:

```text
host port 3000 -> container port 3000
```

Truy cập từ máy local:

```bash
curl http://localhost:3000/health/live
curl http://localhost:3000/health/ready
```

## 12. Backend depends_on

Backend đợi:

```yaml
depends_on:
  postgres:
    condition: service_healthy
  migrate:
    condition: service_completed_successfully
```

Nghĩa là backend chỉ start khi:

```text
Postgres healthy
Migration complete success
```

Lý do:

- Backend cần database đã nhận connection.
- Backend cần schema đã tồn tại.
- Nếu migration fail, backend không nên nhận traffic.

Đây là cùng tư duy với Kubernetes:

```text
database ready -> migration job complete -> deployment rollout
```

## 13. Frontend service

Service:

```text
frontend
```

Build:

```yaml
build:
  context: ./frontend
  args:
    VITE_API_URL: ${VITE_API_URL:-http://localhost:3000/api}
```

Port:

```yaml
ports:
  - "${FRONTEND_PORT:-8080}:8080"
```

Truy cập từ máy local:

```text
http://localhost:8080
```

Frontend đợi backend healthy:

```yaml
depends_on:
  backend:
    condition: service_healthy
```

Lý do: frontend có thể serve static file mà không cần backend, nhưng trong full-stack demo, frontend chỉ được xem là ready khi API phía sau cũng ready.

## 14. Adminer dev profile

Service:

```text
adminer
```

Profile:

```yaml
profiles: ["dev"]
```

Mặc định Adminer không chạy. Muốn bật:

```bash
docker compose --env-file .env --env-file .env.local --profile dev up -d
```

Truy cập:

```text
http://localhost:8081
```

Kết nối database trong Adminer:

```text
System: PostgreSQL
Server: postgres
Username: taskuser
Password: giá trị POSTGRES_PASSWORD trong .env.local
Database: taskdb
```

Adminer chỉ dành cho dev. Không nên bật tool quản trị database trong production nếu không có auth/network policy phù hợp.

## 15. Chạy toàn bộ stack

Command chính:

```bash
cd ~/NT548-DevOps/app/mono

docker compose --env-file .env --env-file .env.local up -d --build
```

Ý nghĩa:

```text
--env-file .env        -> load default values
--env-file .env.local  -> load local secrets
up                     -> tạo/start services
-d                     -> chạy background
--build                -> build lại image nếu Dockerfile/source đổi
```

Kiểm tra container:

```bash
docker compose --env-file .env --env-file .env.local ps
```

Xem log toàn bộ:

```bash
docker compose --env-file .env --env-file .env.local logs -f
```

Xem log từng service:

```bash
docker logs taskdb
docker logs task-migrate
docker logs task-backend
docker logs task-frontend
```

Kiểm tra health:

```bash
curl http://localhost:3000/health/live
curl http://localhost:3000/health/ready
curl http://localhost:8080
```

## 16. Dừng stack

Dừng container nhưng giữ data:

```bash
docker compose --env-file .env --env-file .env.local down
```

Dừng và xóa volume database:

```bash
docker compose --env-file .env --env-file .env.local down -v
```

Xóa image local nếu cần build sạch:

```bash
docker image rm app-mono-backend app-mono-frontend
```

Tên image thực tế có thể khác tùy project name. Kiểm tra bằng:

```bash
docker images
```

## 17. Rebuild khi code thay đổi

Nếu sửa backend source:

```bash
docker compose --env-file .env --env-file .env.local up -d --build backend
```

Nếu sửa frontend source hoặc đổi `VITE_API_URL`:

```bash
docker compose --env-file .env --env-file .env.local up -d --build frontend
```

Nếu sửa Dockerfile hoặc package-lock:

```bash
docker compose --env-file .env --env-file .env.local build --no-cache backend
docker compose --env-file .env --env-file .env.local build --no-cache frontend
docker compose --env-file .env --env-file .env.local up -d
```

`--no-cache` chậm hơn nhưng hữu ích khi nghi ngờ cache Docker đang giữ layer cũ.

## 18. Docker cache hoạt động như thế nào?

Backend Dockerfile copy lockfile trước:

```dockerfile
COPY package*.json ./
RUN npm ci --omit=dev
```

rồi mới copy source:

```dockerfile
COPY src/ ./src/
```

Lý do: nếu chỉ sửa source code, layer `npm ci` có thể được cache lại. Build nhanh hơn.

Frontend cũng làm tương tự:

```dockerfile
COPY package*.json ./
RUN npm ci
```

sau đó mới:

```dockerfile
COPY . .
RUN npm run build
```

Trong CI, `docker/build-push-action` dùng cache GitHub Actions:

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

Tư duy giống nhau: dependency layer ít đổi, source layer đổi thường xuyên.

## 19. .dockerignore để làm gì?

Backend và frontend có:

```text
backend/.dockerignore
frontend/.dockerignore
```

Khi build Docker image, Docker gửi build context vào daemon. Nếu không ignore, context có thể chứa:

```text
node_modules
coverage
dist
.env
logs
```

Hậu quả:

- Build chậm.
- Image có thể chứa file không cần thiết.
- Dễ leak secret nếu `.env` bị copy vào image.

Kiểm tra build context bằng cách đọc `.dockerignore` trước khi build.

## 20. Logging và resource limit

Mỗi service có logging config:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Lý do: tránh log local tăng không giới hạn làm đầy disk.

Resource limit:

```yaml
deploy:
  resources:
    limits:
      memory: 256M
      cpus: '0.5'
```

Lưu ý: với Docker Compose local, support cho `deploy.resources` phụ thuộc phiên bản Docker Compose. Dù vậy nó vẫn thể hiện ý định vận hành: mỗi service nên có giới hạn tài nguyên.

## 21. Manual image scan giống CI

CI dùng Trivy scan image sau khi build. Chạy local tương tự:

```bash
trivy image nt548-backend:local \
  --severity CRITICAL,HIGH

trivy image nt548-frontend:local \
  --severity CRITICAL,HIGH
```

Nếu chưa cài Trivy, có thể chạy bằng container:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image nt548-backend:local
```

Lý do scan image:

- Base image có thể có CVE.
- OS packages trong image có thể lỗi thời.
- App dependencies có thể có vulnerability.

Scan source tree và scan image là hai lớp khác nhau.

## 22. Manual push image giống CI

CI chỉ push image khi push vào `main`. Làm thủ công tương tự:

```bash
docker login

SHORT_SHA=$(git rev-parse --short HEAD)
DOCKERHUB_USERNAME=<your-dockerhub-user>

docker tag nt548-backend:local  $DOCKERHUB_USERNAME/nt548-backend:$SHORT_SHA
docker tag nt548-frontend:local $DOCKERHUB_USERNAME/nt548-frontend:$SHORT_SHA

docker push $DOCKERHUB_USERNAME/nt548-backend:$SHORT_SHA
docker push $DOCKERHUB_USERNAME/nt548-frontend:$SHORT_SHA
```

Vì sao dùng short SHA làm tag?

- Biết image được build từ commit nào.
- Dễ rollback về commit cũ.
- Tránh tag `latest` bị ghi đè mà không biết nội dung thật là gì.

`latest` tiện cho demo, nhưng không đủ tốt để làm source of truth trong GitOps.

## 23. Liên hệ Docker với GitOps

Docker chỉ tạo artifact:

```text
source code -> Docker image
```

GitOps deploy artifact đó:

```text
Docker image tag -> config repo -> ArgoCD -> Kubernetes
```

Trong project này, sau khi image được push, CI update:

```text
nt548-config/charts/task-manager/values-aws-dev.yaml
```

với tag mới:

```yaml
backend:
  image:
    tag: <short-sha>

frontend:
  image:
    tag: <short-sha>
```

Kubernetes không build Docker image. Kubernetes chỉ pull image đã tồn tại trong registry.

## 24. Troubleshooting thường gặp

Kiểm tra service đang lỗi:

```bash
docker compose --env-file .env --env-file .env.local ps
```

Xem log:

```bash
docker compose --env-file .env --env-file .env.local logs postgres
docker compose --env-file .env --env-file .env.local logs migrate
docker compose --env-file .env --env-file .env.local logs backend
docker compose --env-file .env --env-file .env.local logs frontend
```

Lỗi thiếu secret:

```text
POSTGRES_PASSWORD must be set
JWT_SECRET must be set
```

Cách xử lý:

```bash
docker compose --env-file .env --env-file .env.local config
```

và kiểm tra `.env.local`.

Lỗi backend không connect database:

```text
ECONNREFUSED
getaddrinfo ENOTFOUND postgres
```

Kiểm tra:

```bash
docker compose --env-file .env --env-file .env.local ps postgres
docker logs taskdb
```

Nhớ rằng trong container, host database là:

```text
postgres
```

không phải:

```text
localhost
```

Lỗi migration không chạy lại:

```bash
docker compose --env-file .env --env-file .env.local rm -f migrate
docker compose --env-file .env --env-file .env.local up migrate
```

Lỗi sửa `init.sql` nhưng database không đổi:

```bash
docker compose --env-file .env --env-file .env.local down -v
docker compose --env-file .env --env-file .env.local up -d --build
```

Lý do: `/docker-entrypoint-initdb.d` chỉ chạy khi volume Postgres được tạo lần đầu.

Lỗi frontend gọi sai API:

- Kiểm tra `VITE_API_URL`.
- Rebuild frontend image.
- Kiểm tra Nginx proxy `/api/`.

```bash
docker compose --env-file .env --env-file .env.local up -d --build frontend
```

Lỗi container unhealthy:

```bash
docker inspect task-backend --format '{{json .State.Health}}' | jq
docker inspect task-frontend --format '{{json .State.Health}}' | jq
```

Nếu frontend unhealthy, kiểm tra healthcheck port có khớp với Nginx listen port không. Frontend image hiện expose/listen port `8080`.

## 25. Checklist trước khi đưa vào CI

Trước khi để GitHub Actions build/push image, nên chạy local:

```bash
cd ~/NT548-DevOps/app/mono

docker compose --env-file .env --env-file .env.local config
docker compose --env-file .env --env-file .env.local up -d --build
docker compose --env-file .env --env-file .env.local ps

curl http://localhost:3000/health/live
curl http://localhost:3000/health/ready
curl http://localhost:8080
```

Sau đó kiểm tra:

```text
postgres healthy
migrate exited 0
backend healthy
frontend reachable
backend log không có DB error
frontend gọi được /api
```

Nếu các bước này pass local, CI có xác suất pass cao hơn vì GitHub Actions cũng build từ cùng Dockerfile.

## 26. Tóm tắt tư duy

Docker trong repo này làm 4 nhiệm vụ:

```text
Package    -> đóng gói backend/frontend thành image
Isolate    -> mỗi service chạy trong container riêng
Connect    -> Compose nối service bằng network và DNS nội bộ
Reproduce  -> môi trường chạy lặp lại được trên local và CI
```

Khi đọc Dockerfile hoặc Compose file, nên đọc theo câu hỏi:

```text
Image này build từ base nào?
Dependency được cài ở stage nào?
Runtime image có chứa đúng những file cần thiết không?
Container có chạy bằng non-root user không?
Service này cần biến môi trường nào?
Service này nói chuyện với service khác qua network nào?
Data có nằm trong volume không?
Healthcheck đang kiểm tra đúng endpoint không?
Nếu container này fail thì service nào bị chặn?
```

Trả lời được các câu hỏi đó thì sẽ hiểu vì sao Docker layer nằm trước CI/CD và GitOps.
