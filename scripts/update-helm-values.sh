#!/usr/bin/env bash
# ============================================================================
# scripts/update-helm-values.sh
# ============================================================================
# Sync Helm values + ArgoCD apps với Terraform outputs SAU MỖI LẦN RECREATE.
#
# Why script này?
# - RDS endpoint, ACM cert ARN, RDS secret name → đổi mỗi lần recreate
# - Không thể hardcode trong Git
# - Cũng không thể dùng Terraform để write file Git → vi phạm GitOps
# - Solution: script sync OUT-OF-BAND, commit nếu có thay đổi
#
# Usage:
#   ./scripts/update-helm-values.sh           # Update only (no commit)
#   ./scripts/update-helm-values.sh --commit  # Update + commit + push
#   ./scripts/update-helm-values.sh --check   # Check only (read-only)
# ============================================================================

set -euo pipefail
export GIT_PAGER=cat

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Paths ───
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infrastructure"
CONFIG_REPO="${CONFIG_REPO:-$HOME/nt548-config}"

VALUES_FILE="$CONFIG_REPO/charts/task-manager/values-aws-dev.yaml"
KPS_APP_FILE="$CONFIG_REPO/platform/argocd/apps/kube-prometheus-stack.yaml"

# ─── Args ───
COMMIT=false
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --commit) COMMIT=true; shift ;;
    --check)  CHECK_ONLY=true; shift ;;
    --help|-h)
      grep "^#" "$0" | head -25
      exit 0
      ;;
    *) echo -e "${RED}Unknown: $1${NC}"; exit 1 ;;
  esac
done

# ─── Pre-flight ───
if ! command -v yq >/dev/null; then
  echo -e "${RED}✗ yq not installed. Install: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq${NC}"
  exit 1
fi

if [ ! -d "$CONFIG_REPO" ]; then
  echo -e "${RED}✗ Config repo not found at $CONFIG_REPO${NC}"
  echo "  Set: export CONFIG_REPO=/path/to/nt548-config"
  exit 1
fi

# ─── Read Terraform outputs ───
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Reading Terraform outputs...${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

cd "$INFRA_DIR/envs/rds"
RDS_ENDPOINT=$(terraform output -raw db_address 2>/dev/null) || { echo -e "${RED}✗ RDS state not applied${NC}"; exit 1; }
RDS_SECRET_ARN=$(terraform output -raw db_master_user_secret_arn 2>/dev/null) || exit 1
DB_NAME=$(terraform output -raw db_name 2>/dev/null) || exit 1

cd "$INFRA_DIR/envs/dns"
ACM_CERT_ARN=$(terraform output -raw acm_certificate_arn 2>/dev/null) || { echo -e "${RED}✗ DNS state not applied${NC}"; exit 1; }

cd "$INFRA_DIR/envs/secrets"
BACKEND_SECRET_NAME=$(terraform output -raw backend_secret_name 2>/dev/null) || exit 1

echo "  RDS_ENDPOINT         = $RDS_ENDPOINT"
echo "  RDS_SECRET_ARN       = $RDS_SECRET_ARN"
echo "  BACKEND_SECRET_NAME  = $BACKEND_SECRET_NAME"
echo "  ACM_CERT_ARN         = $ACM_CERT_ARN"
echo ""

# ─── Read CURRENT values from config repo ───
CUR_DB_HOST=$(yq eval '.backend.config.DB_HOST' "$VALUES_FILE")
CUR_DB_SECRET=$(yq eval '.backend.externalSecret.dbSecretName' "$VALUES_FILE")
CUR_ACM=$(yq eval '.ingress.alb.certificateArn' "$VALUES_FILE")
CUR_KPS_ACM=$(grep 'certificate-arn:' "$KPS_APP_FILE" | head -1 | sed 's/.*"\(arn:[^"]*\|__[^"]*__\)".*/\1/')

# ─── Diff preview ───
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Diff Preview${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

CHANGED=0
print_diff() {
  local field="$1"; local old="$2"; local new="$3"
  if [ "$old" != "$new" ]; then
    echo -e "  ${YELLOW}~ $field${NC}"
    echo -e "    - $old"
    echo -e "    + $new"
    CHANGED=$((CHANGED + 1))
  else
    echo -e "  ${GREEN}✓ $field (unchanged)${NC}"
  fi
}

print_diff "values-aws-dev.yaml: DB_HOST"       "$CUR_DB_HOST"   "$RDS_ENDPOINT"
print_diff "values-aws-dev.yaml: dbSecretName"  "$CUR_DB_SECRET" "$RDS_SECRET_ARN"
print_diff "values-aws-dev.yaml: certArn"       "$CUR_ACM"       "$ACM_CERT_ARN"
print_diff "kube-prometheus-stack.yaml: certArn" "$CUR_KPS_ACM"  "$ACM_CERT_ARN"

echo ""

if [ $CHANGED -eq 0 ]; then
  echo -e "${GREEN}✓ All fields already in sync. Nothing to do.${NC}"
  exit 0
fi

if [ "$CHECK_ONLY" = true ]; then
  echo -e "${YELLOW}► $CHANGED field(s) out of sync. Run without --check to apply.${NC}"
  exit 1
fi

# ─── Apply changes ───
echo -e "${BLUE}► Applying $CHANGED change(s)...${NC}"

# values-aws-dev.yaml
yq eval -i ".backend.config.DB_HOST = \"$RDS_ENDPOINT\"" "$VALUES_FILE"
yq eval -i ".backend.externalSecret.dbSecretName = \"$RDS_SECRET_ARN\"" "$VALUES_FILE"
yq eval -i ".ingress.alb.certificateArn = \"$ACM_CERT_ARN\"" "$VALUES_FILE"

# kube-prometheus-stack.yaml — update cert ARN safely with yq
TEMP_VALUES=$(mktemp)

yq eval '.spec.source.helm.values' "$KPS_APP_FILE" > "$TEMP_VALUES"

yq eval -i ".grafana.ingress.annotations.\"alb.ingress.kubernetes.io/certificate-arn\" = \"$ACM_CERT_ARN\"" "$TEMP_VALUES"

yq eval -i ".spec.source.helm.values = load_str(\"$TEMP_VALUES\")" "$KPS_APP_FILE"

rm -f "$TEMP_VALUES"

echo -e "${GREEN}✓ Files updated${NC}"

# ─── Show git diff ───
cd "$CONFIG_REPO"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Git diff${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
git --no-pager diff --no-color

# ─── Commit + push ───
if [ "$COMMIT" = true ]; then
  echo ""
  echo -e "${BLUE}► Committing...${NC}"
  git add charts/task-manager/values-aws-dev.yaml platform/argocd/apps/kube-prometheus-stack.yaml
  git commit -m "chore(infra): sync values with TF outputs after recreate

- RDS endpoint:   $RDS_ENDPOINT
- ACM cert:       $ACM_CERT_ARN
- DB secret ARN:  $RDS_SECRET_ARN


[skip ci]"
  git push origin main
  echo -e "${GREEN}✓ Pushed to remote${NC}"
else
  echo ""
  echo -e "${YELLOW}► Not committed. Run with --commit to push, or commit manually.${NC}"
fi
