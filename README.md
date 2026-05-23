# 🚀 NT548 — DevOps Task Manager

> **Full-stack GitOps pipeline on AWS EKS** — CI/CD, Infrastructure as Code, Kubernetes, Observability, and Progressive Delivery.

[![CI](https://github.com/Devop-Projects/NT548-DevOps/actions/workflows/ci.yml/badge.svg)](https://github.com/Devop-Projects/NT548-DevOps/actions/workflows/ci.yml)
[![IaC Security](https://github.com/Devop-Projects/NT548-DevOps/actions/workflows/iac-security.yml/badge.svg)](https://github.com/Devop-Projects/NT548-DevOps/actions/workflows/iac-security.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Kubernetes & GitOps](#-kubernetes--gitops)
- [Infrastructure (Terraform)](#-infrastructure-terraform)
- [Observability](#-observability)
- [Progressive Delivery](#-progressive-delivery)
- [Security](#-security)
- [Operations](#-operations)
- [API Reference](#-api-reference)

---

## 🌟 Overview

NT548 Task Manager is a **production-grade three-tier web application** built as a university DevOps thesis project. It demonstrates end-to-end DevOps practices: from local development to fully automated AWS cloud deployment with GitOps.

**Live Demo:** `https://task-manager.vantai.click`

### Key Features

| Feature | Implementation |
|---|---|
| **GitOps Delivery** | ArgoCD + Helm + Kustomize — Git is the single source of truth |
| **Infrastructure as Code** | Terraform with multi-state remote backend (S3 + DynamoDB lock) |
| **CI/CD** | GitHub Actions — lint, test, SAST, SCA, image scan, cross-repo GitOps promotion |
| **Progressive Delivery** | Argo Rollouts — Blue/Green deployments with automated analysis |
| **Secrets Management** | AWS Secrets Manager + External Secrets Operator |
| **Observability** | Prometheus + Grafana + RED method dashboards |
| **Security** | Defense in depth: NetworkPolicy, PodSecurity, RBAC, Trivy, Gitleaks, tfsec |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Developer Machine                           │
│   git push → GitHub → CI Pipeline → Cross-repo GitOps promotion    │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ Config repo update
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    nt548-config repo (GitOps)                        │
│              ArgoCD watches this → auto-syncs to cluster            │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────── AWS EKS ─────────────────────────────────────┐
│                                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────┐  │
│  │ ArgoCD   │    │ Argo     │    │Prometheus│    │   Grafana    │  │
│  │ (GitOps) │    │ Rollouts │    │ (metrics)│    │  (dashboards)│  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────────┘  │
│                                                                     │
│  ┌─────────────────── task-manager-dev ────────────────────────┐   │
│  │   ALB Ingress → Frontend (nginx) → Backend (Node.js)        │   │
│  │                           ↕                                  │   │
│  │              AWS RDS PostgreSQL 15                            │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  External Secrets Operator ←→ AWS Secrets Manager                  │
│  AWS Load Balancer Controller → ALB auto-provisioning               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🛠 Tech Stack

### Application
| Layer | Technology |
|---|---|
| **Backend** | Node.js 18, Express 4, Sequelize ORM, PostgreSQL 15 |
| **Frontend** | React 18, Vite, Axios |
| **Database** | AWS RDS PostgreSQL 15 (production), in-cluster StatefulSet (local dev) |
| **Authentication** | JWT (jsonwebtoken), bcryptjs |
| **Logging** | Pino (structured JSON) |
| **Metrics** | prom-client (Prometheus exposition) |

### DevOps & Platform
| Category | Technology |
|---|---|
| **Containerization** | Docker (multi-stage builds), Docker Compose |
| **Orchestration** | Kubernetes (AWS EKS 1.30) |
| **Package Management** | Helm 3, Kustomize |
| **GitOps** | ArgoCD, Argo Rollouts |
| **IaC** | Terraform ≥ 1.5 (multi-state: network, EKS, RDS, secrets, DNS) |
| **CI/CD** | GitHub Actions |
| **Registry** | Docker Hub |
| **Secrets** | AWS Secrets Manager, External Secrets Operator |
| **Ingress** | AWS ALB (production), NGINX Ingress (local) |
| **DNS & TLS** | AWS Route 53, ACM |
| **Observability** | Prometheus, Grafana, kube-prometheus-stack |
| **Security Scanning** | Trivy, Gitleaks, tfsec, Checkov, SonarCloud |

---

## 📁 Project Structure

```
NT548-DevOps/                       ← App code + IaC (this repo)
│
├── app/mono/
│   ├── backend/                    ← Node.js Express API
│   │   ├── src/
│   │   │   ├── config/             ← Database, logger, metrics, validation
│   │   │   ├── controllers/        ← Auth, Task controllers
│   │   │   ├── middleware/         ← JWT auth, Prometheus metrics
│   │   │   ├── models/             ← Sequelize User, Task models
│   │   │   ├── routes/             ← Auth, Task routes
│   │   │   └── scripts/            ← DB migration script
│   │   └── tests/                  ← Unit + integration tests (Jest)
│   └── frontend/                   ← React SPA
│       └── src/
│           ├── pages/              ← Login, App views
│           └── services/           ← Axios API client
│
├── infrastructure/                 ← Terraform IaC
│   ├── bootstrap/                  ← S3 + DynamoDB for remote state
│   └── envs/
│       ├── dev/                    ← VPC, subnets, NAT
│       ├── eks/                    ← EKS cluster + addons (LBC, ESO)
│       ├── rds/                    ← RDS PostgreSQL
│       ├── secrets/                ← Secrets Manager entries
│       └── dns/                    ← Route53 + ACM certificate
│
├── .github/workflows/
│   ├── ci.yml                      ← Main CI pipeline
│   └── iac-security.yml            ← Terraform security scanning
│
├── scripts/
│   └── update-helm-values.sh       ← Sync Terraform outputs → Helm values
│
└── Makefile                        ← Top-level automation (deploy, destroy, hibernate)

nt548-config/                       ← GitOps config repo (separate)
│
├── apps/task-manager/
│   ├── base/                       ← Kustomize base manifests
│   └── overlays/
│       ├── dev/                    ← AWS dev overlay
│       └── prod/                   ← Production overlay
│
├── charts/task-manager/            ← Helm chart
│   ├── templates/                  ← K8s resource templates
│   ├── values.yaml                 ← Defaults
│   ├── values-aws-dev.yaml         ← AWS dev environment
│   └── values-prod.yaml            ← Production
│
└── platform/
    ├── argocd/apps/                ← ArgoCD Application CRDs
    └── monitoring/                 ← Prometheus rules, Grafana dashboards
```

---

## 🚀 Getting Started

### Prerequisites

```bash
# Required tools
node >= 18
docker & docker compose
kubectl
terraform >= 1.5
aws cli (configured)
helm
yq
```

### Local Development (Docker Compose)

```bash
git clone https://github.com/Devop-Projects/NT548-DevOps.git
cd NT548-DevOps/app/mono

# Set required environment variables
cp .env.example .env.local
# Edit .env.local:
#   POSTGRES_PASSWORD=<your-password>
#   JWT_SECRET=<min-32-chars-secret>

# Start full stack
docker compose up -d

# Run database migrations
docker compose run --rm migrate

# Access
# Frontend: http://localhost:8080
# Backend:  http://localhost:3000
# API docs: http://localhost:3000/health/ready
```

### Running Tests

```bash
# Backend (Jest + coverage)
cd app/mono/backend
npm ci
npm test

# Frontend (Vitest + coverage)
cd app/mono/frontend
npm ci
npm test
```

### AWS Deployment

```bash
# 1. First-time setup: bootstrap Terraform state backend
make bootstrap

# 2. Deploy everything (VPC → EKS → RDS → Secrets → DNS → ArgoCD → Apps)
make deploy        # ~35 minutes

# 3. Verify
make verify

# Cost saving: pause compute when not needed
make hibernate     # Scales EKS to 0, stops RDS
make wake          # Resumes everything
make wake-dns      # Updates Route53 after wake (new ALB DNS)

# Teardown
make destroy
```

---

## 🔄 CI/CD Pipeline

The GitHub Actions pipeline (`ci.yml`) runs on every push to `main`, `develop`, or `vantai`:

```
┌──────────────────────────────────────────────────────────────────────┐
│                         CI Pipeline                                  │
│                                                                      │
│  Stage 1 (parallel)                                                  │
│  ├── backend-test    → ESLint + Jest (coverage uploaded)             │
│  ├── frontend-test   → Vitest (coverage uploaded)                    │
│  ├── sca-scan        → Trivy filesystem (CVE in dependencies)        │
│  └── secret-scan     → Gitleaks (credentials in git history)         │
│                                                                      │
│  Stage 2 (after tests)                                               │
│  └── sast-scan       → SonarCloud (code quality + coverage)         │
│                                                                      │
│  Stage 3 (after tests)                                               │
│  ├── build-backend   → Docker build → Trivy image scan → Push       │
│  └── build-frontend  → Docker build → Trivy image scan → Push       │
│                                                                      │
│  Stage 4 (main branch only)                                          │
│  └── update-config-repo → yq update image tag → commit → push      │
│                          (ArgoCD auto-syncs within 3 minutes)        │
└──────────────────────────────────────────────────────────────────────┘
```

**Image tags** follow the pattern `<git-short-sha>` (e.g., `a1b2c3d`). The CI bot commits the new tag to the `nt548-config` config repo, triggering ArgoCD sync automatically.

---

## ☸️ Kubernetes & GitOps

### GitOps Flow

```
Developer pushes code
    → CI builds & pushes image
    → CI commits new image tag to nt548-config repo
    → ArgoCD detects config change (polls every 3 min)
    → ArgoCD syncs cluster to match desired state
    → Argo Rollouts orchestrates Blue/Green promotion
```

### ArgoCD Applications

| Application | Source | Namespace |
|---|---|---|
| `task-manager-dev` | `charts/task-manager` (Helm) | `task-manager-dev` |
| `kube-prometheus-stack` | Helm chart | `monitoring` |
| `argo-rollouts` | Helm chart | `argo-rollouts` |
| `monitoring-extras` | `platform/monitoring/` | `monitoring` |
| `grafana-dashboards` | `platform/monitoring/dashboards/` | `monitoring` |

### Accessing ArgoCD UI

```bash
make argocd-ui
# Opens https://localhost:8080 (username: admin)
```

### Namespace Governance

The `task-manager-dev` namespace includes:

- **ResourceQuota** — limits total CPU (4/8 cores), memory (4/8Gi), 20 pods
- **LimitRange** — default requests/limits for containers without explicit values
- **NetworkPolicy** — default-deny-all + explicit allow rules (DNS, ingress, DB)
- **PodSecurity** — `audit: restricted`, `warn: restricted`
- **RBAC** — ServiceAccounts with `automountServiceAccountToken: false`

---

## 🌐 Infrastructure (Terraform)

Infrastructure is split into **5 independent Terraform states**, each in `infrastructure/envs/<name>/`. All states share a common S3 remote backend with DynamoDB locking.

```
State dependency order (deploy in this sequence):
  dev (VPC)  →  eks  →  rds  →  secrets  →  dns
```

| State | Resources |
|---|---|
| `dev` | VPC, public/private subnets, NAT Gateway, route tables |
| `eks` | EKS 1.30, managed node group (SPOT t3.medium), AWS LBC, ESO |
| `rds` | RDS PostgreSQL 15, KMS encryption, Secrets Manager auto-password |
| `secrets` | JWT secret, Grafana credentials, KMS key |
| `dns` | ACM certificate, Route53 A records (2-phase: cert first, A records after ALB exists) |

### Shared Variables

```bash
# infrastructure/common.tfvars (symlinked as *.auto.tfvars in each state)
project     = "devops"
environment = "dev"
region      = "ap-southeast-1"
owner       = "vantai"
```

### IaC Security

Three tools scan Terraform on every PR touching `infrastructure/`:

- **tfsec** — fast, AWS-focused rules
- **Checkov** — ~1000 policies, multi-cloud
- **Trivy IaC** — unified scanning consistent with image scanning

All findings are uploaded as SARIF to GitHub Security → Code Scanning Alerts.

---

## 📊 Observability

### Metrics (RED Method)

The backend exposes Prometheus metrics at `/metrics`:

| Metric | Type | Description |
|---|---|---|
| `http_requests_total` | Counter | Request count by method, route, status_code |
| `http_request_duration_seconds` | Histogram | Request latency (p50/p95/p99) |
| `db_pool_connections_active` | Gauge | Active DB connections |
| `tasks_created_total` | Counter | Business metric |
| `auth_failures_total` | Counter | Auth failure reasons |

### Grafana Dashboard

**Backend — RED Method** dashboard (`uid: dfms9gk62639ce`) shows:

- Total request rate (req/s)
- Error rate (5xx %)
- p95 latency (stat + time series)
- Latency distribution heatmap
- DB pool saturation gauge

Access: `https://grafana.vantai.click` (credentials in AWS Secrets Manager `devops/dev/grafana`)

```bash
# Retrieve Grafana admin password
kubectl get secret grafana-admin-secret -n monitoring \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

---

## 🚢 Progressive Delivery

The backend deployment uses **Argo Rollouts** with a **Blue/Green strategy**:

```
New image pushed → Argo Rollouts creates "preview" (green) ReplicaSet
                → Pre-promotion analysis: HTTP probe /health/ready × 5 times
                → If analysis passes: manual or auto promotion
                → Traffic switches from blue → green
                → Blue scaled down after 30s
                → Automatic rollback if analysis fails
```

**Configuration** (in `values-aws-dev.yaml`):

```yaml
backend:
  rollout:
    enabled: true
    strategy: blueGreen
    blueGreen:
      activeService: backend
      previewService: backend-preview
      autoPromotionEnabled: false   # Manual promotion (safe for dev)
      prePromotionAnalysis:
        enabled: true
        templates:
          - success-rate-web
```

**Rollout operations:**

```bash
# Promote preview → active
kubectl argo rollouts promote backend -n task-manager-dev

# Abort and rollback
kubectl argo rollouts abort backend -n task-manager-dev

# Watch rollout status
kubectl argo rollouts get rollout backend -n task-manager-dev --watch
```

---

## 🔒 Security

Security is implemented as **defense in depth** across multiple layers:

### Container Security
- Non-root users (UID 1000 for Node.js, UID 101 for nginx, UID 70 for PostgreSQL)
- `readOnlyRootFilesystem: true` (with explicit `emptyDir` for writable paths)
- `allowPrivilegeEscalation: false`
- All Linux capabilities dropped (`capabilities.drop: ["ALL"]`)
- `seccompProfile: RuntimeDefault`
- `automountServiceAccountToken: false`

### Network Security
- Default-deny-all NetworkPolicy
- Explicit allow rules: ingress → frontend, ingress → backend, backend → postgres
- Postgres only accepts connections from backend and migration pods

### Secret Management

```
AWS Secrets Manager
    ↓ (External Secrets Operator, refreshInterval: 1h)
K8s Secret (backend-secrets, db-credentials)
    ↓ (injected via secretKeyRef)
Pod environment variables
```

Secrets are **never stored in Git**. Passwords are auto-generated by Terraform using `random_password`.

### Supply Chain Security

| Stage | Tool | What it checks |
|---|---|---|
| Git history | Gitleaks | Leaked credentials, API keys |
| Dependencies | Trivy (fs) | CVEs in package-lock.json |
| Source code | SonarCloud | Bugs, vulnerabilities, code smells |
| Docker image | Trivy (image) | OS + package CVEs in final image |
| Terraform | tfsec, Checkov, Trivy IaC | Misconfigurations |

---

## ⚙️ Operations

### Daily Commands

```bash
# Check system status
make status

# End-to-end health verification
make verify

# View backend logs
make logs-backend

# Open shell in backend pod
make shell-backend

# Check AWS costs
bash scripts/aws-cost-check.sh
```

### Cost Saving (Hibernate/Wake)

```bash
# Hibernate: delete ALBs, scale EKS to 0, stop RDS (~70% cost reduction)
make hibernate

# Wake: start RDS, scale EKS up, ArgoCD recreates Ingress/ALBs
make wake

# Update DNS to point to new ALBs (they get new hostnames after wake)
make wake-dns
```

> ⚠️ AWS automatically resumes stopped RDS instances after 7 days.

### Dependency Updates

Dependabot is configured for monthly updates across:
- Backend npm dependencies (grouped: production, dev)
- Frontend npm dependencies (grouped: production, dev)
- GitHub Actions versions
- Docker base images (backend + frontend)

Major versions of React and Express are excluded from auto-update and require manual review.

---

## 📡 API Reference

Base URL: `https://task-manager.vantai.click/api`

### Authentication

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `POST` | `/auth/register` | — | Register new user |
| `POST` | `/auth/login` | — | Login, receive JWT |

**Register:**
```bash
curl -X POST /api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@example.com","password":"secure123"}'
# → {"token":"<jwt>","user":{"id":"...","username":"alice","email":"..."}}
```

### Tasks (require `Authorization: Bearer <token>`)

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/tasks` | List all tasks for current user |
| `POST` | `/tasks` | Create a new task |
| `PUT` | `/tasks/:id` | Update task (title, description, status) |
| `DELETE` | `/tasks/:id` | Delete task |

**Task status values:** `todo` · `in_progress` · `done`

### Health

| Endpoint | Description |
|---|---|
| `GET /health/live` | Liveness probe — process alive |
| `GET /health/ready` | Readiness probe — DB connectivity |
| `GET /metrics` | Prometheus metrics exposition |

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

**NT548 — University of Technology and Education**  
DevOps & Cloud Infrastructure · Academic Year 2024–2025

*Built with ❤️ by Doan Van Tai*

</div>