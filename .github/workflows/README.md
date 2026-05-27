# CI Pipeline Manual Guide

Guide này dùng để hiểu pipeline trong `.github/workflows/ci.yml` trước khi để GitHub Actions tự làm toàn bộ sau mỗi lần `git push`.

Ý chính: CI không phải là một "lệnh thần kỳ". CI chỉ tự động chạy lại những việc mà developer có thể làm thủ công trên máy hoặc trên một runner sạch:

```text
checkout code
install dependencies
lint
test + coverage
scan dependency / secret / source code
build Docker image
scan Docker image
push image lên registry
update config repo để GitOps deploy
```

Trong repo này, workflow `ci.yml` đang phục vụ app monolith ở:

```text
app/mono/backend
app/mono/frontend
```

Repo cũng có thư mục `app/micro`, nhưng pipeline hiện tại chưa chạy CI cho phần microservice.

## 0. CI đang thay thế việc gì?

Nếu chưa dùng GitHub Actions, sau mỗi lần sửa code bạn phải tự làm các việc này:

```bash
cd ~/NT548-DevOps

# Backend
cd app/mono/backend
npm ci
npm run lint
npm test

# Frontend
cd ../frontend
npm ci
npm test

# Build image
cd ~/NT548-DevOps
docker build -t nt548-backend:local ./app/mono/backend
docker build -t nt548-frontend:local ./app/mono/frontend \
  --build-arg VITE_API_URL=/api

# Scan image, push image, rồi update config repo nếu mọi thứ pass
```

Vấn đề khi làm thủ công:

- Dễ quên một bước, ví dụ chỉ test backend nhưng quên test frontend.
- Máy local có thể khác môi trường thật, ví dụ đã có dependency cũ trong `node_modules`.
- Developer có thể push image chưa được test.
- Image tag trong config repo có thể không khớp với commit app repo.
- Security scan dễ bị bỏ qua vì chạy lâu hoặc không quen tool.

CI giải quyết bằng cách chạy cùng một quy trình trên GitHub runner sạch, có log, có trạng thái pass/fail, và gắn trực tiếp với commit.

## 1. Trigger: khi nào CI chạy?

Workflow hiện tại chạy khi:

```yaml
on:
  push:
    branches: [main, develop, vantai]
  pull_request:
    branches: [main]
  workflow_dispatch:
```

Nghĩa là:

- Push lên `main`, `develop`, `vantai` sẽ chạy CI.
- Mở pull request vào `main` sẽ chạy CI để kiểm tra trước khi merge.
- Có thể bấm chạy thủ công trong tab GitHub Actions bằng `workflow_dispatch`.

Workflow đang bỏ qua thay đổi chỉ liên quan đến markdown hoặc docs:

```yaml
paths-ignore:
  - '**.md'
  - 'docs/**'
```

Lý do: sửa tài liệu không cần build Docker image hoặc scan app.

## 2. Concurrency: vì sao hủy run cũ?

Workflow có:

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

Nếu bạn push liên tục nhiều commit lên cùng một branch, GitHub sẽ hủy run cũ và giữ run mới nhất.

Lý do:

- Tiết kiệm phút CI.
- Tránh push Docker image từ commit cũ.
- Tránh update config repo bằng image tag cũ.

Với CI/CD, commit mới nhất trên branch mới là thứ cần kiểm tra và promote.

## 3. Backend lint và test

Manual equivalent:

```bash
cd ~/NT548-DevOps/app/mono/backend
npm ci
npm run lint
npm test
```

Trong workflow:

```text
backend-test
```

Bước này làm 3 việc chính:

```text
npm ci       -> cài dependency đúng theo package-lock.json
npm run lint -> kiểm tra code style và lỗi tĩnh bằng ESLint
npm test     -> chạy Jest và tạo coverage
```

Vì sao dùng `npm ci` thay vì `npm install`?

`npm ci` dùng cho CI vì nó cài chính xác theo `package-lock.json` và fail nếu lockfile không khớp. Điều này giúp runner dựng môi trường lặp lại được.

Backend test cần một số biến môi trường giả:

```yaml
NODE_ENV: test
JWT_SECRET: ci-test-secret-not-used-in-prod
DATABASE_URL: postgres://fake:fake@localhost:5432/fake
PORT: 3000
```

Lý do: test cần app khởi động trong môi trường test, nhưng không được dùng secret thật hoặc database production.

Sau test, workflow upload coverage:

```text
backend-coverage
```

Coverage này được job SonarCloud dùng ở bước sau.

## 4. Frontend test

Manual equivalent:

```bash
cd ~/NT548-DevOps/app/mono/frontend
npm ci
npm test
```

Trong workflow:

```text
frontend-test
```

Frontend dùng Vitest:

```json
"test": "vitest run --coverage"
```

Job này cũng upload coverage:

```text
frontend-coverage
```

Vì sao frontend và backend test tách thành 2 job?

- Chạy song song nhanh hơn.
- Backend fail thì biết lỗi nằm ở backend.
- Frontend fail thì biết lỗi nằm ở frontend.
- Build backend chỉ cần đợi backend test, build frontend chỉ cần đợi frontend test.

## 5. SCA scan: quét dependency và filesystem

Manual equivalent nếu đã cài Trivy:

```bash
cd ~/NT548-DevOps
trivy fs . \
  --format sarif \
  --output trivy-fs-results.sarif \
  --severity CRITICAL,HIGH
```

Trong workflow:

```text
sca-scan
```

SCA là Software Composition Analysis. Mục tiêu là quét dependency, lockfile, secret pattern, và misconfiguration cơ bản trong source tree.

Job này chạy song song với test vì nó không cần đợi build.

Workflow đang để:

```yaml
exit-code: '0'
```

Nghĩa là report-only mode. Có finding thì upload report lên GitHub Security, nhưng chưa chặn pipeline.

Lý do hợp lý trong giai đoạn học hoặc thesis:

- Nhìn được vấn đề bảo mật trước.
- Không làm pipeline fail liên tục khi project còn đang hoàn thiện.
- Sau khi baseline ổn, có thể đổi sang `exit-code: '1'` để block merge nếu có HIGH/CRITICAL.

## 6. SAST scan: SonarCloud

Manual equivalent thường là:

```bash
cd ~/NT548-DevOps
sonar-scanner
```

Nhưng để chạy được cần cấu hình `sonar-project.properties` và token:

```bash
export SONAR_TOKEN=<token>
export SONAR_HOST_URL=https://sonarcloud.io
```

Trong workflow:

```text
sast-scan
needs: [backend-test, frontend-test]
```

SAST là Static Application Security Testing. SonarCloud phân tích source code để tìm:

- bug;
- vulnerability;
- code smell;
- duplicate code;
- coverage;
- maintainability issue.

Vì sao job này cần `backend-test` và `frontend-test`?

SonarCloud cần coverage report từ Jest và Vitest. Nếu chạy Sonar trước khi có coverage, dashboard sẽ thiếu dữ liệu test coverage.

Workflow download artifact:

```text
backend-coverage
frontend-coverage
```

rồi mới scan.

## 7. Build backend image

Manual equivalent:

```bash
cd ~/NT548-DevOps
docker build \
  -t nt548-backend:scan \
  -f ./app/mono/backend/Dockerfile \
  ./app/mono/backend
```

Trong workflow:

```text
build-backend
needs: backend-test
```

Backend image chỉ được build sau khi backend lint/test pass.

Lý do:

- Không tốn thời gian build image nếu test đã fail.
- Không scan hoặc push image từ code chưa đạt kiểm tra tối thiểu.
- Tách backend và frontend để lỗi bên này không chặn build bên kia nếu không liên quan.

Workflow build image local trước:

```yaml
push: false
load: true
tags: nt548-backend:scan
```

Image `nt548-backend:scan` là tag tạm trong runner, dùng để scan trước khi push.

## 8. Scan backend image

Manual equivalent:

```bash
trivy image nt548-backend:scan \
  --format sarif \
  --output trivy-image-backend.sarif \
  --severity CRITICAL,HIGH
```

Trong workflow:

```text
Trivy image scan
```

Filesystem scan và image scan khác nhau:

```text
trivy fs     -> quét source tree, lockfile, config
trivy image  -> quét image sau khi build, gồm base image + OS packages + app dependencies
```

Cần cả hai vì có lỗi chỉ xuất hiện sau khi build image, ví dụ base image có CVE.

Workflow cũng đang để image scan ở report-only mode:

```yaml
exit-code: '0'
```

## 9. Build và scan frontend image

Manual equivalent:

```bash
cd ~/NT548-DevOps
docker build \
  -t nt548-frontend:scan \
  -f ./app/mono/frontend/Dockerfile \
  --build-arg VITE_API_URL=/api \
  ./app/mono/frontend

trivy image nt548-frontend:scan \
  --format sarif \
  --output trivy-image-frontend.sarif \
  --severity CRITICAL,HIGH
```

Trong workflow:

```text
build-frontend
needs: frontend-test
```

Frontend cần build arg:

```text
VITE_API_URL=/api
```

Lý do: Vite inject biến build-time vào bundle frontend. Nếu build sai API URL, image chạy được nhưng frontend gọi sai backend.

## 10. Push image lên Docker Hub

Manual equivalent:

```bash
docker login

SHORT_SHA=$(git rev-parse --short HEAD)

docker tag nt548-backend:scan  <dockerhub-user>/nt548-backend:$SHORT_SHA
docker tag nt548-frontend:scan <dockerhub-user>/nt548-frontend:$SHORT_SHA

docker push <dockerhub-user>/nt548-backend:$SHORT_SHA
docker push <dockerhub-user>/nt548-frontend:$SHORT_SHA
```

Trong workflow, bước push chỉ chạy khi push vào `main`:

```yaml
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

Lý do:

- Pull request chỉ để kiểm tra, không nên publish image production/dev.
- Branch feature hoặc develop có thể chưa sẵn sàng deploy.
- `main` là source để promote qua GitOps.

Workflow dùng secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
```

Các tag được tạo bằng `docker/metadata-action`:

```text
latest
short sha
branch name
semver tag nếu có git tag version
```

Trong GitOps, tag quan trọng nhất là short SHA, vì nó trỏ về đúng commit.

## 11. Secret scan bằng Gitleaks

Manual equivalent nếu đã cài Gitleaks:

```bash
cd ~/NT548-DevOps
gitleaks detect --source . --verbose --redact
```

Trong workflow:

```text
secret-scan
```

Gitleaks quét git history và working tree để tìm secret bị commit nhầm, ví dụ:

- token;
- private key;
- AWS key;
- password;
- JWT secret.

Vì sao cần quét secret riêng dù Trivy fs cũng có secret scan?

- Gitleaks mạnh ở quét git history.
- Trivy mạnh ở dependency, image, misconfig.
- Hai tool overlap một phần nhưng không thay thế hoàn toàn cho nhau.

Nếu Gitleaks phát hiện secret thật, việc cần làm không chỉ là xóa dòng đó khỏi commit mới. Secret đã từng vào git history thì nên rotate secret.

## 12. Update config repo: bước GitOps promotion

Manual equivalent:

```bash
cd ~/nt548-config

SHORT_SHA=<short-sha-cua-commit-app>

yq eval -i ".backend.image.tag = \"$SHORT_SHA\"" \
  charts/task-manager/values-aws-dev.yaml

yq eval -i ".frontend.image.tag = \"$SHORT_SHA\"" \
  charts/task-manager/values-aws-dev.yaml

git diff charts/task-manager/values-aws-dev.yaml
git add charts/task-manager/values-aws-dev.yaml
git commit -m "ci(dev): promote image to $SHORT_SHA"
git push origin main
```

Trong workflow:

```text
update-config-repo
needs: [build-backend, build-frontend]
if: push vào main
```

Bước này checkout repo khác:

```text
Devop-Projects/nt548-config
```

rồi update:

```text
charts/task-manager/values-aws-dev.yaml
```

Đây là phần quan trọng của GitOps:

```text
App repo build image
        |
        v
Docker Hub có image tag mới
        |
        v
Config repo đổi image.tag sang short SHA mới
        |
        v
ArgoCD thấy config repo thay đổi
        |
        v
Cluster sync deployment mới
```

CI không dùng `kubectl apply` trực tiếp vào cluster. CI chỉ cập nhật GitOps config repo. ArgoCD mới là thành phần apply vào Kubernetes.

Lý do làm vậy:

- Git là source of truth cho trạng thái cluster.
- Có audit trail rõ ràng: commit nào đổi image tag nào.
- Rollback dễ hơn bằng cách revert config repo.
- CI không cần cầm kubeconfig production.
- Tách trách nhiệm: CI build artifact, GitOps deploy artifact.

## 13. Secrets và variables cần có trên GitHub

Trong repository GitHub, vào:

```text
Settings -> Secrets and variables -> Actions
```

Cần cấu hình:

```text
Secrets:
  DOCKERHUB_USERNAME
  DOCKERHUB_TOKEN
  SONAR_TOKEN
  CONFIG_REPO_TOKEN

Variables:
  NODE_VERSION
```

`NODE_VERSION` có fallback:

```yaml
NODE_VERSION: ${{ vars.NODE_VERSION || '20' }}
```

Nên vẫn chạy được nếu chưa set variable, nhưng set rõ trong GitHub giúp team biết version Node chính thức đang dùng.

`CONFIG_REPO_TOKEN` cần quyền push vào config repo. Nếu token thiếu quyền, bước update config repo sẽ fail dù build image đã thành công.

## 14. Thứ tự dependency giữa các job

Pipeline hiện tại có thể hiểu như sau:

```text
backend-test  ─────> build-backend  ──┐
                                      ├──> update-config-repo
frontend-test ─────> build-frontend ──┘

backend-test + frontend-test ────────> sast-scan

sca-scan và secret-scan chạy độc lập
```

Vì sao không cho tất cả chạy tuần tự?

Chạy tuần tự dễ hiểu nhưng chậm. CI tốt nên song song hóa các bước không phụ thuộc nhau:

- Backend test không cần đợi frontend test.
- SCA scan không cần đợi test.
- Secret scan không cần đợi build.
- Backend image chỉ cần backend pass.
- Frontend image chỉ cần frontend pass.
- Update config repo phải đợi cả hai image build/push xong.

## 15. Khi push code, thực tế chuyện gì xảy ra?

Ví dụ bạn chạy:

```bash
git add app/mono/backend/src/controllers/task.controller.js
git commit -m "fix task update validation"
git push origin main
```

GitHub Actions sẽ:

1. Tạo một workflow run cho commit mới.
2. Checkout code ở đúng commit đó.
3. Chạy backend lint/test.
4. Chạy frontend test.
5. Chạy Trivy filesystem scan.
6. Upload coverage.
7. Chạy SonarCloud scan.
8. Build backend image và frontend image.
9. Scan hai image bằng Trivy.
10. Login Docker Hub.
11. Push image với tag tương ứng commit.
12. Checkout config repo.
13. Sửa image tag trong `values-aws-dev.yaml`.
14. Commit và push config repo.
15. ArgoCD phát hiện config repo thay đổi và sync app lên cluster.

Nếu một bước fail, các bước phụ thuộc sau nó sẽ không chạy.

Ví dụ:

- Backend lint fail -> không build backend image.
- Frontend test fail -> không build frontend image.
- Build image fail -> không update config repo.
- Push config repo fail -> image đã có trên Docker Hub nhưng cluster chưa được promote qua GitOps.

## 16. Checklist trước khi tin CI/CD tự chạy hết

Trước khi phụ thuộc hoàn toàn vào `git push -> deploy`, nên kiểm tra:

```bash
# Backend local
cd ~/NT548-DevOps/app/mono/backend
npm ci
npm run lint
npm test

# Frontend local
cd ~/NT548-DevOps/app/mono/frontend
npm ci
npm test

# Docker build local
cd ~/NT548-DevOps
docker build -t nt548-backend:local ./app/mono/backend
docker build -t nt548-frontend:local ./app/mono/frontend \
  --build-arg VITE_API_URL=/api
```

Trên GitHub kiểm tra:

```text
Actions tab:
  CI workflow pass

Security tab:
  Trivy/SARIF findings đã upload

Docker Hub:
  nt548-backend có tag short SHA
  nt548-frontend có tag short SHA

Config repo:
  values-aws-dev.yaml đã đổi image tag

ArgoCD:
  app sync đúng commit config repo mới
```

## 17. Khi nào nên tách workflow thành nhiều file?

Hiện tại để một `ci.yml` vẫn hợp lý vì các bước đang tạo thành một flow:

```text
test -> scan -> build -> push image -> update config repo
```

Nên tách thành nhiều workflow khi:

- `app/mono` và `app/micro` đều được phát triển/deploy riêng.
- Secret scan muốn chạy theo lịch riêng.
- Deploy muốn chạy thủ công sau khi CI pass.
- Security scan muốn có policy riêng.
- File CI quá dài và khó review.

Một cấu trúc hợp lý sau này:

```text
.github/workflows/
  mono-ci.yml
  micro-ci.yml
  secret-scan.yml
  iac-security.yml
  deploy-dev.yml
```

Nhưng không nên tách chỉ vì "file dài". GitHub Actions không hỗ trợ `needs` trực tiếp giữa các workflow file độc lập. Nếu tách sai, pipeline có thể khó nối trạng thái hơn.

## 18. Tóm tắt tư duy

CI trong repo này làm 3 nhiệm vụ:

```text
Validate  -> code có đạt chất lượng tối thiểu không?
Package   -> build image có chạy được không?
Promote   -> cập nhật GitOps config để deploy image mới
```

GitHub Actions không thay thế việc hiểu hệ thống. Nó chỉ tự động hóa một chuỗi bước phải chạy nhất quán sau mỗi commit.

Khi đọc `ci.yml`, nên đọc theo câu hỏi:

```text
Job này bảo vệ rủi ro gì?
Job này cần output của job nào trước đó?
Job này có được phép chạy trên pull request không?
Job này có được phép push artifact hoặc deploy không?
Nếu job này fail thì ảnh hưởng tới bước nào?
```

Trả lời được các câu hỏi đó thì sẽ hiểu vì sao pipeline được viết như hiện tại.
