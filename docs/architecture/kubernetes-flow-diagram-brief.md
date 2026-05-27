# Kubernetes Flow Diagram Brief

File này dùng để chuẩn bị nội dung vẽ diagram/slide cho phần Kubernetes của đồ án. Mục tiêu là giải thích luồng hoạt động và các thành phần quan trọng, không phải copy toàn bộ manifest YAML.

Nguồn manifest chính nằm ở config repo:

```text
/home/vantai/nt548-config
```

Các phần quan trọng:

```text
platform/argocd/apps/task-manager-dev.yaml
bootstrap/root-app.yaml
charts/task-manager/
charts/task-manager/values.yaml
charts/task-manager/values-aws-dev.yaml
```

## 1. Thông điệp chính của slide

Thông điệp nên truyền đạt:

```text
Kubernetes không chỉ chạy container.
Trong đồ án này, Kubernetes là runtime platform cho app,
ArgoCD là cơ chế GitOps để đồng bộ manifest,
Helm là cách template hóa environment,
và các controller như ALB Controller, External Secrets, Argo Rollouts,
Prometheus cùng phối hợp để tạo một flow production-like.
```

Câu ngắn để đặt ở đầu slide:

```text
Kubernetes runs the application, but GitOps controls the desired state.
```

Hoặc bản tiếng Việt:

```text
Kubernetes chạy workload, còn GitOps quyết định trạng thái mong muốn của hệ thống.
```

## 2. Nên vẽ tổng quan như thế nào?

Nên vẽ thành 2 luồng song song:

```text
Deployment flow:
App repo -> CI -> Docker Hub -> Config repo -> ArgoCD -> Kubernetes

Runtime request flow:
User -> DNS/ALB -> Ingress -> frontend/backend Service -> Pods -> RDS
```

Layout gợi ý:

```text
┌────────────┐     ┌──────────────┐     ┌──────────────┐
│ App Repo   │ --> │ GitHub CI    │ --> │ Docker Hub   │
└────────────┘     └──────────────┘     └──────┬───────┘
                                                │ image tag
                                                v
┌────────────┐     ┌──────────────┐     ┌──────────────┐
│ Config Repo│ --> │ ArgoCD       │ --> │ EKS Cluster  │
└────────────┘     └──────────────┘     └──────┬───────┘
                                                │
                                                v
                         ┌──────────────────────────────────┐
                         │ task-manager-dev namespace        │
                         │ Ingress -> Services -> Pods -> RDS │
                         └──────────────────────────────────┘
```

Nếu chỉ có một slide, ưu tiên vẽ luồng:

```text
User -> ALB Ingress -> Frontend Service -> Frontend Pods
                  └-> /api -> Backend Service -> Backend Pods -> RDS
```

Rồi thêm bên trên:

```text
ArgoCD continuously syncs this state from nt548-config.
```

## 3. Luồng GitOps deployment

Đây là luồng làm nổi bật đồ án vì nó nối CI/CD với Kubernetes một cách đúng DevOps.

Nên vẽ:

```text
GitHub Actions
  builds Docker images
  tags images by short SHA
  pushes to Docker Hub
  updates values-aws-dev.yaml in config repo

ArgoCD
  watches nt548-config
  renders Helm chart
  applies resources to EKS
  self-heals drift
```

Text ngắn trên diagram:

```text
CI does not kubectl apply.
CI only updates GitOps config.
ArgoCD reconciles Kubernetes state.
```

Ý nghĩa để thuyết trình:

```text
CI chỉ build artifact và cập nhật image tag trong config repo.
Cluster không nhận lệnh deploy trực tiếp từ CI.
ArgoCD theo dõi config repo và tự đồng bộ cluster về đúng trạng thái khai báo trong Git.
```

Điểm đáng nói:

- Config repo là source of truth.
- Có audit trail qua Git commit.
- Rollback bằng cách revert config repo.
- CI không cần kubeconfig production.
- ArgoCD có `automated.prune` và `selfHeal`.

Manifest liên quan:

```text
platform/argocd/apps/task-manager-dev.yaml
bootstrap/root-app.yaml
charts/task-manager/values-aws-dev.yaml
```

## 4. App-of-apps: Root Application

Nên vẽ một block nhỏ:

```text
Root App
  path: platform/argocd/apps
  creates ArgoCD Applications
```

Ý nghĩa:

```text
Chỉ cần apply root app ban đầu.
Sau đó các ArgoCD Application khác được quản lý qua Git.
Đây là pattern app-of-apps.
```

Điểm nổi bật:

- `root-app.yaml` là manifest bootstrap.
- Nó đọc folder `platform/argocd/apps`.
- Các app như `task-manager-dev`, monitoring, argo-rollouts có thể được quản lý tập trung.

Text ngắn cho slide:

```text
App-of-apps pattern:
one root ArgoCD app manages all platform/application apps.
```

## 5. Helm chart và values theo môi trường

Nên vẽ:

```text
Helm chart: charts/task-manager
  templates/
  values.yaml
  values-aws-dev.yaml
```

Ý nghĩa:

```text
Helm giúp dùng chung template Kubernetes,
còn values file quyết định khác biệt giữa local/dev/prod.
```

Trong `values-aws-dev.yaml`, các điểm đáng vẽ:

```text
global.environment = dev
namespace = task-manager-dev
backend.image.tag = CI updated short SHA
frontend.image.tag = CI updated short SHA
postgres.enabled = false
backend connects to AWS RDS
ingress.className = alb
externalSecret.enabled = true
backend.rollout.enabled = true
```

Điểm làm nổi bật:

- Cùng một chart có thể chạy local hoặc AWS dev.
- AWS dev dùng RDS thay vì Postgres in-cluster.
- Image tag được CI update tự động.
- Feature flags bật/tắt component như monitoring, rollout, HPA, PDB.

## 6. Runtime request flow

Đây là phần quan trọng nhất để thầy hiểu app chạy như thế nào.

Nên vẽ:

```text
User
  |
  v
Route53 / domain
  |
  v
AWS ALB
  |
  v
Kubernetes Ingress
  |-- /      -> frontend Service -> frontend Pods
  |-- /api   -> backend Service  -> backend Pods -> AWS RDS PostgreSQL
```

Trong manifest:

```text
Ingress host: task-manager.vantai.click
Path /api -> backend:3000
Path /    -> frontend:80
```

Ý nghĩa:

```text
ALB là entrypoint public.
Ingress định tuyến traffic theo path.
Service tạo DNS nội bộ ổn định.
Pod là nơi container thật sự chạy.
Backend kết nối database RDS bên ngoài cluster.
```

Text ngắn trên diagram:

```text
/api -> backend
/    -> frontend
backend -> RDS
```

## 7. Ingress + AWS ALB

Nên vẽ một block:

```text
Ingress class: alb
AWS Load Balancer Controller
internet-facing ALB
TLS via ACM certificate
healthcheck: /health/ready
```

Ý nghĩa:

```text
Kubernetes Ingress chỉ là khai báo routing.
AWS Load Balancer Controller đọc Ingress và tạo ALB thật trên AWS.
```

Điểm nổi bật:

- Dùng `ingressClassName: alb`.
- ALB public internet-facing.
- TLS được xử lý bằng ACM certificate ARN.
- ALB healthcheck gọi `/health/ready`.
- `/api` đi backend, `/` đi frontend.

Text ngắn cho slide:

```text
Ingress is declarative.
AWS Load Balancer Controller turns it into a real ALB.
```

## 8. Namespace và resource governance

Nên vẽ ở góc cluster:

```text
Namespace: task-manager-dev
ResourceQuota
LimitRange
PodSecurity audit/warn
```

Ý nghĩa:

```text
Namespace tách app khỏi các workload khác.
ResourceQuota giới hạn tổng tài nguyên trong namespace.
LimitRange đặt request/limit mặc định để tránh pod chạy không kiểm soát.
PodSecurity audit/warn giúp phát hiện workload không đạt baseline security.
```

Điểm nổi bật:

- Có governance ở cấp namespace.
- Không chỉ deploy app, mà còn kiểm soát tài nguyên và chính sách.
- Đây là điểm nên nói để đồ án nhìn giống production hơn.

Không cần vẽ toàn bộ thông số quota, chỉ cần ghi:

```text
Quota: CPU, memory, pods, services, secrets, configmaps
Limits: default request/limit per container
```

## 9. Backend workload

Trong AWS dev, backend dùng Argo Rollouts thay vì Deployment thường.

Nên vẽ:

```text
Backend Rollout
  image: doanvantai/nt548-backend:<sha>
  config: ConfigMap
  secrets: ExternalSecret -> K8s Secret
  probes: startup, liveness, readiness
  serviceAccount: backend-sa
  securityContext: non-root, read-only fs, drop capabilities
```

Ý nghĩa:

```text
Backend là API service chính.
Nó lấy config không nhạy cảm từ ConfigMap,
lấy secret từ Kubernetes Secret do External Secrets Operator tạo,
và kết nối tới RDS.
```

Điểm đáng nói:

- `readinessProbe /health/ready`: chỉ nhận traffic khi app và dependency ready.
- `livenessProbe /health/live`: restart nếu app bị treo.
- `startupProbe /health/live`: cho app thời gian khởi động.
- `preStop sleep`: graceful shutdown trước khi pod bị terminate.
- `checksum/config`: config đổi thì pod rollout lại.
- `automountServiceAccountToken: false`: app không cần gọi Kubernetes API.
- `readOnlyRootFilesystem: true`, `drop: ALL`, `runAsNonRoot`.

Text ngắn trên diagram:

```text
Backend: Rollout + probes + non-root + config/secrets
```

## 10. Frontend workload

Nên vẽ:

```text
Frontend Deployment
  image: doanvantai/nt548-frontend:<sha>
  Nginx container
  Service port 80 -> targetPort 8080
  readiness/liveness on /
  non-root nginx user
```

Ý nghĩa:

```text
Frontend là static web app chạy bằng Nginx.
Service frontend là endpoint nội bộ để Ingress route path / vào.
```

Điểm đáng nói:

- Frontend không connect database.
- Frontend nhận traffic từ Ingress/ALB.
- Có probes để Kubernetes biết pod có sẵn sàng không.
- Runtime security context giống backend: non-root, no privilege escalation, drop capabilities.
- Vì read-only filesystem, mount `emptyDir` cho `/var/cache/nginx`, `/var/run`, `/tmp`.

Text ngắn:

```text
Frontend: Nginx static runtime + Service + probes
```

## 11. Service: vì sao cần Service?

Nên vẽ Service nằm giữa Ingress và Pod:

```text
Ingress -> Service -> Pods
```

Ý nghĩa:

```text
Pod có thể bị thay thế và IP thay đổi.
Service cung cấp DNS/IP ổn định để các thành phần khác gọi vào.
```

Các service quan trọng:

```text
frontend Service
  port 80 -> pod targetPort 8080

backend Service
  port 3000 -> pod targetPort 3000

backend-preview Service
  dùng cho Argo Rollouts blue-green preview
```

Điểm làm nổi bật:

- Service không chạy app, nó load-balance tới Pods.
- Với Argo Rollouts, active service và preview service giúp chuyển traffic giữa phiên bản cũ/mới.

## 12. Database flow: AWS RDS thay vì Postgres trong cluster

Trong AWS dev:

```text
postgres.enabled = false
backend.config.DB_HOST = RDS endpoint
DB_SSL = true
```

Nên vẽ:

```text
Backend Pods -> AWS RDS PostgreSQL
```

Ý nghĩa:

```text
Database không chạy trong Kubernetes ở môi trường AWS dev.
Kubernetes chạy application workload, còn database dùng managed service RDS.
```

Điểm làm nổi bật:

- Tách stateful database khỏi cluster app.
- RDS quản lý storage, backup, availability tốt hơn so với tự chạy Postgres trong dev/prod AWS.
- Secret DB lấy từ AWS Secrets Manager qua External Secrets.

Nếu có slide local/dev riêng, có thể nói:

```text
Local mode can use in-cluster Postgres StatefulSet.
AWS dev mode uses RDS and disables in-cluster Postgres.
```

## 13. Migration Job

Nên vẽ migration như một Job chạy trước/độc lập với backend:

```text
Migration Job
  uses backend image
  runs node src/scripts/migrate.js
  connects to RDS
  completes then exits
```

Ý nghĩa:

```text
Migration là one-off task, không phải service chạy lâu dài.
Nó đảm bảo schema database được cập nhật trước khi backend phiên bản mới phục vụ traffic.
```

Điểm nổi bật:

- Job name chứa image tag rút gọn:

```text
task-manager-migrate-<image-tag>
```

- Khi image tag đổi, Job name đổi, migration có thể chạy lại cho release mới.
- `ttlSecondsAfterFinished`: tự dọn Job sau khi xong.
- `backoffLimit`, `activeDeadlineSeconds`: kiểm soát retry và timeout.

Text ngắn:

```text
DB migration is a Kubernetes Job, not a long-running Pod.
```

## 14. External Secrets flow

Đây là điểm rất đáng làm nổi bật.

Nên vẽ:

```text
AWS Secrets Manager
        |
        v
External Secrets Operator
        |
        v
Kubernetes Secret
        |
        v
Backend Pod env vars
```

Secrets chính:

```text
backend-secrets
  JWT_SECRET
  JWT_REFRESH_SECRET

db-credentials
  DB_USERNAME
  DB_PASSWORD
```

Ý nghĩa:

```text
Secret thật nằm ở AWS Secrets Manager.
Kubernetes chỉ nhận bản sync thành Secret để Pod sử dụng.
Manifest Git không chứa secret value.
```

Điểm nổi bật:

- Không commit password/JWT secret vào Git.
- External Secrets refresh theo interval.
- Dùng `ClusterSecretStore` trỏ tới AWS Secrets Manager.
- ServiceAccount của External Secrets dùng AWS auth.

Text ngắn:

```text
No secret values in Git.
Secrets are synced from AWS Secrets Manager.
```

## 15. Argo Rollouts blue-green deployment

Đây là phần rất mạnh để làm nổi bật đồ án.

Nên vẽ:

```text
Backend Rollout
  activeService: backend
  previewService: backend-preview

Current version (blue)  -> receives production traffic
New version (green)    -> preview + analysis
```

Luồng:

```text
1. ArgoCD syncs new image tag.
2. Argo Rollouts creates new ReplicaSet.
3. backend-preview points to new version.
4. prePromotionAnalysis checks /health/ready.
5. If analysis passes, promote manually or by policy.
6. backend active service switches to new version.
7. old version scales down after delay.
```

Trong `values-aws-dev.yaml`:

```text
backend.rollout.enabled = true
strategy = blueGreen
activeService = backend
previewService = backend-preview
autoPromotionEnabled = false
prePromotionAnalysis = success-rate-web
```

Ý nghĩa:

```text
Blue-green giúp triển khai phiên bản mới mà không thay ngay traffic production.
Có preview service để kiểm tra phiên bản mới trước khi promote.
```

Điểm nổi bật:

- Có progressive delivery, không chỉ rolling update cơ bản.
- Có analysis trước promotion.
- `autoPromotionEnabled: false` phù hợp demo vì cho phép thầy thấy bước manual promotion.
- `scaleDownDelaySeconds`: giữ bản cũ một thời gian trước khi dọn.

Text ngắn:

```text
Progressive delivery:
new backend version is verified before becoming active.
```

## 16. AnalysisTemplate

Nên vẽ như một check nhỏ cạnh Rollout:

```text
AnalysisTemplate: success-rate-web
GET backend-preview/health/ready
successCondition: status == ready
```

Ý nghĩa:

```text
Trước khi promote bản mới, Argo Rollouts gọi endpoint health của preview service.
Nếu app không ready quá số lần cho phép, rollout bị abort.
```

Điểm đáng nói:

- Provider hiện tại là `web`, đơn giản để demo.
- Khi có Prometheus đầy đủ, có thể thay bằng PromQL để đo error rate/latency.
- Đây là bước kiểm chứng tự động trong progressive delivery.

Text ngắn:

```text
Pre-promotion analysis protects production traffic.
```

## 17. Observability: ServiceMonitor, PrometheusRule, Grafana

Nên vẽ một nhánh monitoring:

```text
Backend /metrics
    |
ServiceMonitor
    |
Prometheus
    |
PrometheusRule RED metrics
    |
Grafana dashboards
```

Ý nghĩa:

```text
Backend expose metrics.
Prometheus scrape metrics qua ServiceMonitor.
PrometheusRule tạo recording rules cho RED method:
Rate, Errors, Duration.
Grafana dùng metrics này để hiển thị dashboard.
```

Điểm nổi bật:

- Có monitoring stack, không chỉ deploy app.
- Có RED method cho backend:

```text
Rate: request rate
Errors: 5xx ratio
Duration: p50/p95/p99 latency
```

- ServiceMonitor có label `release: kube-prometheus-stack` để Prometheus nhận diện.

Text ngắn:

```text
Observability path:
backend /metrics -> Prometheus -> RED dashboards
```

## 18. NetworkPolicy

Nên vẽ một lớp security quanh namespace:

```text
Default deny
Allow DNS
Allow ingress controller -> frontend/backend
Allow Prometheus -> backend /metrics
```

Ý nghĩa:

```text
NetworkPolicy chuyển network từ mặc định mở sang mô hình allow-list.
Chỉ những luồng cần thiết mới được mở.
```

Điểm nổi bật:

- Có `default-deny-all`.
- Có `allow-dns-egress` để pod resolve DNS.
- Có rule cho ingress controller gọi frontend/backend.
- Có rule cho Prometheus scrape backend.

Lưu ý kỹ thuật nên ghi trong speaker notes:

```text
Nếu CNI enforce NetworkPolicy đầy đủ và backend dùng AWS RDS bên ngoài cluster,
cần kiểm tra/bổ sung egress rule cho backend tới RDS endpoint/port 5432.
```

Không nhất thiết đưa cảnh báo này lên slide chính, nhưng nên biết để trả lời nếu thầy hỏi.

## 19. Security context và hardening

Nên vẽ icon shield trên backend/frontend pods:

```text
runAsNonRoot
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
drop ALL capabilities
seccomp RuntimeDefault
automountServiceAccountToken: false
```

Ý nghĩa:

```text
Pod vẫn có thể chạy app, nhưng bị giới hạn quyền tối đa.
Nếu app bị khai thác, attacker khó leo thang quyền hơn.
```

Điểm nổi bật:

- Backend chạy UID 1000.
- Frontend Nginx chạy UID 101.
- App không mount token Kubernetes API nếu không cần.
- Read-only root filesystem buộc app chỉ ghi vào các mount tạm như `/tmp`.

Text ngắn:

```text
Runtime hardening is applied at Pod and container level.
```

## 20. Probes và lifecycle

Nên vẽ cạnh Pod:

```text
startupProbe -> app has time to boot
livenessProbe -> restart if stuck
readinessProbe -> receive traffic only when ready
preStop -> graceful shutdown
```

Ý nghĩa:

```text
Kubernetes không tự biết app healthy hay chưa.
Probes cung cấp tín hiệu để restart, route traffic, và rollout an toàn.
```

Backend:

```text
/health/live
/health/ready
```

Frontend:

```text
/
```

Điểm đáng nói:

- Readiness quan trọng hơn liveness trong traffic routing.
- ALB healthcheck cũng dùng `/health/ready`.
- PreStop sleep giúp pod ngừng nhận traffic trước khi process bị kill.

## 21. HPA và PDB

Trong `values-aws-dev.yaml`, HPA/PDB đang tắt cho dev:

```text
autoscaling.enabled = false
podDisruptionBudget.enabled = false
```

Nhưng chart có template cho prod:

```text
HorizontalPodAutoscaler
PodDisruptionBudget
```

Nên đưa vào slide phụ hoặc ghi là "production-ready hooks":

```text
HPA: scale backend by CPU/memory
PDB: keep minimum pods available during disruption
```

Ý nghĩa:

```text
Dev environment tắt để tiết kiệm chi phí/tài nguyên.
Prod có thể bật để tăng availability và autoscaling.
```

Không nên làm người nghe hiểu nhầm rằng dev hiện đang autoscale nếu values đang tắt.

## 22. Những thành phần nên làm nổi bật trong đồ án

Nếu thầy hỏi "đồ án có gì hơn deploy YAML cơ bản?", nên nhấn mạnh:

```text
1. GitOps with ArgoCD
   Cluster syncs from Git, not manual kubectl.

2. Helm chart with environment values
   Same templates, different local/aws/prod configs.

3. AWS ALB Ingress
   Public traffic is managed declaratively from Kubernetes.

4. External Secrets
   Secrets come from AWS Secrets Manager, not Git.

5. Argo Rollouts blue-green
   New backend version is verified before promotion.

6. Migration Job
   Database schema update is separated from app runtime.

7. Observability
   ServiceMonitor + PrometheusRule + Grafana RED dashboards.

8. Security hardening
   NetworkPolicy, non-root pods, read-only fs, no service account token.

9. Resource governance
   Namespace, ResourceQuota, LimitRange.
```

## 23. Slide chính nên vẽ những block nào?

Slide 1: K8s Runtime Flow

```text
User
  -> Route53 / ALB
  -> Ingress
  -> frontend Service -> frontend Pods
  -> /api backend Service -> backend Rollout Pods
  -> AWS RDS
```

Thêm nhánh:

```text
External Secrets -> K8s Secrets -> backend env
Prometheus -> ServiceMonitor -> backend /metrics
```

Slide 2: GitOps Deployment Flow

```text
GitHub Actions
  -> Docker Hub image tag
  -> nt548-config values-aws-dev.yaml
  -> ArgoCD Application
  -> Helm render
  -> EKS resources
```

Slide 3: Progressive Delivery

```text
Backend Rollout
  active service: backend
  preview service: backend-preview
  prePromotionAnalysis: /health/ready
  manual promotion
```

Nếu chỉ có một slide, kết hợp slide 1 và GitOps mini-banner bên trên.

## 24. Những gì không nên đưa quá nhiều vào slide

Không nên nhồi:

- Full YAML.
- Toàn bộ values file.
- Tất cả annotation ALB.
- Toàn bộ ResourceQuota/LimitRange numbers.
- Tất cả PromQL.
- Toàn bộ NetworkPolicy YAML.
- Cả Kustomize base và Helm chart cùng lúc nếu không giải thích mục đích.

Thay vào đó, chỉ vẽ:

```text
Component -> role -> why it matters
```

Ví dụ:

```text
ExternalSecret -> sync secret from AWS -> no secrets in Git
```

## 25. Text ngắn đặt cạnh diagram

Có thể đặt ở cạnh phải slide:

```text
Key Kubernetes decisions

GitOps:
  ArgoCD syncs cluster from config repo

Traffic:
  ALB Ingress routes / and /api

Runtime:
  frontend Deployment, backend Rollout

State:
  backend uses AWS RDS, not in-cluster DB

Secrets:
  External Secrets syncs AWS Secrets Manager

Safety:
  probes, NetworkPolicy, non-root containers

Observability:
  Prometheus scrapes /metrics and powers RED dashboards
```

## 26. Speaker notes ngắn

Có thể nói khi thuyết trình:

```text
Ở phần Kubernetes, em không deploy thủ công bằng kubectl cho từng manifest.
Em dùng GitOps: CI build image và cập nhật image tag trong config repo,
sau đó ArgoCD tự sync Helm chart vào EKS.

Traffic bên ngoài đi qua domain và AWS ALB.
Ingress route path / vào frontend service và /api vào backend service.
Frontend chạy như Nginx static app, backend chạy API Node.js và kết nối AWS RDS.

Secret không được commit vào Git.
External Secrets Operator lấy JWT secret và database credential từ AWS Secrets Manager,
rồi tạo Kubernetes Secret để backend dùng.

Backend dùng Argo Rollouts blue-green.
Khi có image mới, phiên bản mới được tạo ở preview service,
AnalysisTemplate kiểm tra /health/ready trước khi promote sang active service.

Ngoài ra, namespace có ResourceQuota/LimitRange,
pod chạy non-root, read-only filesystem, drop capabilities,
có NetworkPolicy, probes, ServiceMonitor và Prometheus RED metrics.
```

## 27. Checklist khi vẽ diagram

Khi tự vẽ trong draw.io, kiểm tra diagram có đủ các câu trả lời này:

```text
Ai tạo ALB? -> AWS Load Balancer Controller đọc Ingress.
Traffic / đi đâu? -> frontend Service.
Traffic /api đi đâu? -> backend Service.
Backend kết nối DB nào? -> AWS RDS.
Secret lấy từ đâu? -> AWS Secrets Manager qua External Secrets.
Image tag ai cập nhật? -> GitHub Actions cập nhật values-aws-dev.yaml.
Ai apply vào cluster? -> ArgoCD sync Helm chart.
Phiên bản backend mới được kiểm tra thế nào? -> Argo Rollouts + AnalysisTemplate.
Metrics đi đâu? -> backend /metrics -> ServiceMonitor -> Prometheus -> Grafana.
Security hardening nằm ở đâu? -> NetworkPolicy + securityContext + no SA token.
```

Nếu diagram trả lời được các câu này, phần K8s của bạn đủ rõ cho slide và vấn đáp.
