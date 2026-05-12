# k8s/overlays/aws/kustomization.yaml.tpl
#
# ⭐ TEMPLATE — KHÔNG sửa file rendered (kustomization.yaml).
# Sửa file .tpl, rồi chạy `make k8s-render` để regenerate.
#
# Placeholders (envsubst sẽ thay):
#   ${RDS_ENDPOINT}    — từ rds output db_address
#   ${DB_NAME}         — từ rds output db_name
#   ${IMAGE_TAG}       — git short SHA
#   ${DOCKERHUB_USER}  — Docker Hub username

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: task-manager-dev

resources:
- ../../base
- secret-store.yaml
- external-secret.yaml
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
- target:
    kind: StatefulSet
    name: postgres
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 0
- target:
    kind: Ingress
    name: task-manager
  patch: |-
    $patch: delete
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: task-manager
      namespace: task-manager-dev

labels:
- pairs:
    environment: aws-dev
    cloud: aws
  includeSelectors: false
