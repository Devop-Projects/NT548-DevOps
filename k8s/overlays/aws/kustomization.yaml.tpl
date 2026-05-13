# k8s/overlays/aws/kustomization.yaml.tpl
#
# ⭐ TEMPLATE — KHÔNG sửa file rendered (kustomization.yaml).
# Sửa file .tpl, rồi chạy `make k8s-render` để regenerate.
#
# Placeholders (envsubst sẽ thay):
#   ${RDS_ENDPOINT}          — từ rds output db_address
#   ${DB_NAME}               — từ rds output db_name
#   ${IMAGE_TAG}             — git short SHA
#   ${DOCKERHUB_USER}        — Docker Hub username
#   ${RDS_SECRET_NAME}       — extract từ rds output db_master_user_secret_arn
#   ${BACKEND_SECRET_NAME}   — từ secrets output backend_secret_name
#   ${ACM_CERT_ARN}          — từ dns output acm_certificate_arn
#   ${APP_FQDN}              — từ dns output full_fqdn

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: task-manager-dev

resources:
- ../../base
- secret-store.yaml              # ClusterSecretStore (1 cho cả cluster)
- external-secret.yaml           # ExternalSecret cho DB (rds!db-xxx)
- external-secret-backend.yaml   # ⭐ MỚI: ExternalSecret cho JWT
- ingress-alb.yaml

images:
- name: task-manager-backend
  newName: ${DOCKERHUB_USER}/nt548-backend
  newTag: ${IMAGE_TAG}
- name: task-manager-frontend
  newName: ${DOCKERHUB_USER}/nt548-frontend
  newTag: ${IMAGE_TAG}

configMapGenerator:
- name: backend-config
  behavior: merge
  literals:
  - DB_HOST=${RDS_ENDPOINT}
  - DB_PORT=5432
  - DB_NAME=${DB_NAME}
  - DB_USER=appuser
  - DB_SSL=true

patches:
- path: delete-nginx-ingress.yaml
- path: backend-deployment-patch.yaml
  target:
    kind: Deployment
    name: backend
- path: frontend-deployment-patch.yaml
  target:
    kind: Deployment
    name: frontend
- path: migrate-job-patch.yaml
  target:
    kind: Job
    name: db-migrate

# StatefulSet postgres → scale down 0 (vì dùng RDS thay thế)
- target:
    kind: StatefulSet
    name: postgres
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 0

# ⭐ MỚI: xóa postgres-secrets local — vì JWT đã có ESO, password đã có db-credentials


labels:
- pairs:
    environment: aws-dev
    cloud: aws
  includeSelectors: false
