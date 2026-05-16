#!/bin/bash
# ============================================================================
# scripts/update-helm-values.sh
# ============================================================================
# Extract Terraform outputs and update Helm values file in config repo.
#
# Why this script exists:
# Sau mỗi `make tf-apply-*`, các identifier thay đổi:
#   - RDS endpoint (DB_HOST)
#   - RDS secret name (dbSecretName)
#   - ACM cert ARN (certificateArn)
#
# Trước đây phải edit thủ công, dễ sai. Script này:
#   1. Extract outputs từ TF state
#   2. Update values-aws-dev.yaml in config repo
#   3. Commit + push (optional, gated by --commit flag)
#
# Usage:
#   ./scripts/update-helm-values.sh           # Update + show diff (no commit)
#   ./scripts/update-helm-values.sh --commit  # Update + commit + push
#   ./scripts/update-helm-values.sh --check   # Just show what would change
#
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
APP_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_REPO="${CONFIG_REPO:-$HOME/nt548-config}"
ENVS_DIR="$APP_REPO/infrastructure/envs"
VALUES_FILE="$CONFIG_REPO/charts/task-manager/values-aws-dev.yaml"

# Flags
COMMIT=false
CHECK_ONLY=false
SKIP_CONFIRM=false

# ─── Parse arguments ────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --commit) COMMIT=true ;;
    --check) CHECK_ONLY=true ;;
    --yes|-y) SKIP_CONFIRM=true ;;
    --help|-h)
      echo "Usage: $0 [--commit] [--check] [--yes]"
      echo "  --commit  : Update values, commit, and push to config repo"
      echo "  --check   : Show what would change without modifying file"
      echo "  --yes|-y  : Skip confirmation prompts"
      exit 0
      ;;
    *) echo -e "${RED}Unknown argument: $arg${NC}"; exit 1 ;;
  esac
done

# ─── Pre-flight checks ─────────────────────────────────
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Update Helm Values from Terraform Outputs${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Check yq installed
if ! command -v yq &> /dev/null; then
  echo -e "${RED}✗ yq not installed${NC}"
  echo "Install: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
  exit 1
fi

# Check config repo exists
if [ ! -d "$CONFIG_REPO" ]; then
  echo -e "${RED}✗ Config repo not found at: $CONFIG_REPO${NC}"
  echo "Set env var: export CONFIG_REPO=/path/to/nt548-config"
  exit 1
fi

# Check values file exists
if [ ! -f "$VALUES_FILE" ]; then
  echo -e "${RED}✗ Values file not found: $VALUES_FILE${NC}"
  exit 1
fi

echo -e "${BLUE}► Config repo: ${NC}$CONFIG_REPO"
echo -e "${BLUE}► Values file: ${NC}$VALUES_FILE"
echo ""

# ─── Extract Terraform outputs ─────────────────────────
echo -e "${BLUE}► Extracting Terraform outputs...${NC}"

# 1. RDS endpoint (DB_HOST)
echo -n "  Reading RDS endpoint... "
RDS_ENDPOINT=$(cd "$ENVS_DIR/rds" && terraform output -raw db_address 2>/dev/null || echo "")
if [ -z "$RDS_ENDPOINT" ]; then
  echo -e "${RED}FAIL${NC}"
  echo -e "${RED}    Could not read db_address. Is RDS state applied?${NC}"
  echo -e "${YELLOW}    Run: make tf-apply-rds${NC}"
  exit 1
fi
echo -e "${GREEN}OK${NC}"
echo "    → $RDS_ENDPOINT"

# 2. RDS secret name (extract from ARN)
echo -n "  Reading RDS secret name... "
RDS_SECRET_ARN=$(cd "$ENVS_DIR/rds" && terraform output -raw db_master_user_secret_arn 2>/dev/null || echo "")
if [ -z "$RDS_SECRET_ARN" ]; then
  echo -e "${RED}FAIL${NC}"
  exit 1
fi
# ARN format: arn:aws:secretsmanager:region:account:secret:rds!db-uuid-xxxxxxx
# We need the part after "secret:" minus the trailing -xxxxxxx suffix
RDS_SECRET_NAME=$(echo "$RDS_SECRET_ARN" | awk -F: '{print $NF}' | sed 's/-[A-Za-z0-9]*$//')
echo -e "${GREEN}OK${NC}"
echo "    → $RDS_SECRET_NAME"

# 3. ACM cert ARN
echo -n "  Reading ACM cert ARN... "
ACM_CERT_ARN=$(cd "$ENVS_DIR/dns" && terraform output -raw acm_certificate_arn 2>/dev/null | tr -d '\000-\010\013\014\016-\037' || echo "")
if [ -z "$ACM_CERT_ARN" ]; then
  echo -e "${RED}FAIL${NC}"
  echo -e "${YELLOW}    Did you run 'make tf-apply-dns-phase1'?${NC}"
  exit 1
fi
echo -e "${GREEN}OK${NC}"
echo "    → $ACM_CERT_ARN"

# 4. App FQDN (for verification)
echo -n "  Reading app FQDN... "
APP_FQDN=$(cd "$ENVS_DIR/dns" && terraform output -raw full_fqdn 2>/dev/null | tr -d '\000-\010\013\014\016-\037' || echo "")
echo -e "${GREEN}OK${NC}"
echo "    → $APP_FQDN"

# 5. DB name & user (usually stable, but read for safety)
DB_NAME=$(cd "$ENVS_DIR/rds" && terraform output -raw db_name 2>/dev/null || echo "appdb")
DB_USER=$(cd "$ENVS_DIR/rds" && terraform output -raw db_username 2>/dev/null || echo "appuser")

echo ""

# ─── Read CURRENT values from values file ───────────────
echo -e "${BLUE}► Reading current values from config repo...${NC}"

CURRENT_DB_HOST=$(yq eval '.backend.config.DB_HOST' "$VALUES_FILE")
CURRENT_DB_SECRET=$(yq eval '.backend.externalSecret.dbSecretName' "$VALUES_FILE")
CURRENT_CERT_ARN=$(yq eval '.ingress.alb.certificateArn' "$VALUES_FILE")

# ─── Show diff ──────────────────────────────────────────
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Diff Preview${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"

CHANGES=0

check_diff() {
  local label="$1"
  local current="$2"
  local new="$3"
  if [ "$current" != "$new" ]; then
    echo -e "${YELLOW}  $label${NC}"
    echo -e "    ${RED}- $current${NC}"
    echo -e "    ${GREEN}+ $new${NC}"
    CHANGES=$((CHANGES + 1))
  else
    echo -e "${GREEN}  ✓ $label (unchanged)${NC}"
  fi
}

check_diff "DB_HOST" "$CURRENT_DB_HOST" "$RDS_ENDPOINT"
check_diff "dbSecretName" "$CURRENT_DB_SECRET" "$RDS_SECRET_NAME"
check_diff "certificateArn" "$CURRENT_CERT_ARN" "$ACM_CERT_ARN"

echo ""

if [ "$CHANGES" -eq 0 ]; then
  echo -e "${GREEN}✓ All values already up-to-date. Nothing to do.${NC}"
  exit 0
fi

echo -e "${YELLOW}► $CHANGES field(s) need update${NC}"
echo ""

# ─── Check-only mode: exit here ─────────────────────────
if [ "$CHECK_ONLY" = true ]; then
  echo -e "${BLUE}► Check mode: no changes made${NC}"
  exit 0
fi

# ─── Confirmation ──────────────────────────────────────
if [ "$SKIP_CONFIRM" = false ]; then
  echo -ne "${YELLOW}Apply these changes to $VALUES_FILE? [y/N] ${NC}"
  read -r CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo -e "${RED}Aborted by user${NC}"
    exit 1
  fi
fi

# ─── Apply changes via yq ──────────────────────────────
echo -e "${BLUE}► Applying changes...${NC}"

yq eval -i ".backend.config.DB_HOST = \"$RDS_ENDPOINT\"" "$VALUES_FILE"
echo -e "${GREEN}  ✓ Updated DB_HOST${NC}"

yq eval -i ".backend.externalSecret.dbSecretName = \"$RDS_SECRET_NAME\"" "$VALUES_FILE"
echo -e "${GREEN}  ✓ Updated dbSecretName${NC}"

yq eval -i ".ingress.alb.certificateArn = \"$ACM_CERT_ARN\"" "$VALUES_FILE"
echo -e "${GREEN}  ✓ Updated certificateArn${NC}"

# ─── Show git diff ─────────────────────────────────────
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Git Diff${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
cd "$CONFIG_REPO"
git --no-pager diff "$VALUES_FILE"

# ─── Commit & push (optional) ──────────────────────────
echo ""
if [ "$COMMIT" = true ]; then
  if [ "$SKIP_CONFIRM" = false ]; then
    echo -ne "${YELLOW}Commit and push to config repo? [y/N] ${NC}"
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
      echo -e "${YELLOW}Skipped commit. Values updated locally only.${NC}"
      exit 0
    fi
  fi

  cd "$CONFIG_REPO"
  git add "$VALUES_FILE"

  # Generate commit message
  COMMIT_MSG="chore(infra): sync values-aws-dev with new TF outputs

Updated after infrastructure recreate:
- DB_HOST: $RDS_ENDPOINT
- dbSecretName: $RDS_SECRET_NAME
- certificateArn: ${ACM_CERT_ARN:0:80}...

Auto-generated by scripts/update-helm-values.sh"

  git commit -m "$COMMIT_MSG"
  git push origin main

  echo ""
  echo -e "${GREEN}✓ Committed and pushed to config repo${NC}"
  echo -e "${BLUE}  ArgoCD will sync within 3 min${NC}"
else
  echo -e "${YELLOW}► Values updated locally. To commit + push:${NC}"
  echo -e "  cd $CONFIG_REPO && git add . && git commit -m 'chore: sync values' && git push"
  echo -e "  ${YELLOW}Or run with --commit flag${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Done. App will be at: https://$APP_FQDN${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
