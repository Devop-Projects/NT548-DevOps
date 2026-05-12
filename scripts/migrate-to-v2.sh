#!/usr/bin/env bash
# ============================================================================
# scripts/migrate-to-v2.sh
# ============================================================================
# Tự động migrate từ cấu trúc cũ (hardcoded) sang v2 (partial backend + envsubst).
#
# Usage:
#   ./scripts/migrate-to-v2.sh --dry-run    # Xem sẽ làm gì, không thay đổi
#   ./scripts/migrate-to-v2.sh              # Thực thi
#
# Idempotent: chạy nhiều lần OK (kiểm tra trước khi đổi).
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Parse args
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo -e "${YELLOW}═══ DRY RUN MODE — không thay đổi gì ═══${RESET}"
fi

# Helper: run hoặc echo tùy DRY_RUN
run() {
  if $DRY_RUN; then
    echo -e "  ${BLUE}[DRY]${RESET} $*"
  else
    eval "$@"
  fi
}

# Helper: viết file
write_file() {
  local path="$1"
  local content="$2"
  if $DRY_RUN; then
    echo -e "  ${BLUE}[DRY]${RESET} Write $path"
  else
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "  ${GREEN}✓${RESET} Wrote $path"
  fi
}

# ─── Verify chạy từ project root ───
if [[ ! -d "infrastructure/envs" ]]; then
  echo -e "${RED}✗ Phải chạy từ project root (chứa thư mục infrastructure/)${RESET}"
  exit 1
fi

echo -e "${BLUE}═══ Phase A: Tạo file shared ═══${RESET}"

# A1. backend-config.hcl
if [[ -f infrastructure/backend-config.hcl ]]; then
  echo -e "  ${YELLOW}⚠${RESET} infrastructure/backend-config.hcl đã tồn tại — skip"
else
  # Extract bucket name từ file backend.tf cũ (nếu có)
  BUCKET=$(grep -h 'bucket' infrastructure/envs/dev/backend.tf 2>/dev/null | head -1 | grep -oP '"[^"]*"' | tr -d '"' || echo "thesis-tfstate-CHANGEME")
  write_file "infrastructure/backend-config.hcl" "bucket         = \"$BUCKET\"
region         = \"ap-southeast-1\"
dynamodb_table = \"thesis-tfstate-locks\"
encrypt        = true"
fi

# A2. common.tfvars
if [[ -f infrastructure/common.tfvars ]]; then
  echo -e "  ${YELLOW}⚠${RESET} infrastructure/common.tfvars đã tồn tại — skip"
else
  BUCKET=$(grep 'bucket' infrastructure/backend-config.hcl 2>/dev/null | grep -oP '"[^"]*"' | tr -d '"' || echo "thesis-tfstate-CHANGEME")
  write_file "infrastructure/common.tfvars" "project        = \"devops\"
environment    = \"dev\"
region         = \"ap-southeast-1\"
owner          = \"vantai\"
tfstate_bucket = \"$BUCKET\""
fi

echo -e "${BLUE}═══ Phase B: Đổi backend.tf thành partial ═══${RESET}"

for state in dev eks rds secrets dns; do
  backend_file="infrastructure/envs/$state/backend.tf"
  if [[ -f "$backend_file" ]]; then
    # Backup file cũ
    run "cp $backend_file $backend_file.bak"
    write_file "$backend_file" 'terraform {
  backend "s3" {}
}'
  fi
done

echo -e "${BLUE}═══ Phase C: Tạo symlinks common.auto.tfvars ═══${RESET}"

for state in dev eks rds secrets dns; do
  state_dir="infrastructure/envs/$state"
  if [[ -d "$state_dir" ]]; then
    link_path="$state_dir/common.auto.tfvars"
    if [[ -L "$link_path" ]]; then
      echo -e "  ${YELLOW}⚠${RESET} $link_path đã là symlink — skip"
    else
      run "ln -sf ../../common.tfvars $link_path"
    fi
  fi
done

echo -e "${BLUE}═══ Phase D: Đồng nhất project name = 'devops' ═══${RESET}"

# Tìm các file .tfvars và .tf có "devops-thesis", đổi thành "devops"
files_with_old_name=$(grep -rl 'devops-thesis' infrastructure/ 2>/dev/null | grep -v '\.bak$' || true)
if [[ -z "$files_with_old_name" ]]; then
  echo -e "  ${GREEN}✓${RESET} Không file nào còn 'devops-thesis'"
else
  while IFS= read -r f; do
    run "sed -i.bak 's/devops-thesis/devops/g' '$f'"
    echo -e "  ${GREEN}✓${RESET} Đổi project name trong $f"
  done <<< "$files_with_old_name"
fi

echo -e "${BLUE}═══ Phase E: Backup K8s overlays cũ → .tpl mới ═══${RESET}"

OVERLAY_DIR="k8s/overlays/aws"
for f in kustomization.yaml external-secret.yaml ingress-alb.yaml; do
  src="$OVERLAY_DIR/$f"
  tpl="$OVERLAY_DIR/${f}.tpl"
  if [[ -f "$src" ]]; then
    run "mv '$src' '${src}.bak'"
    echo -e "  ${GREEN}✓${RESET} Backup $src → ${src}.bak"
  fi
  if [[ ! -f "$tpl" ]]; then
    echo -e "  ${YELLOW}⚠${RESET} Cần tạo template thủ công: $tpl"
    echo -e "    (Xem hướng dẫn ở chat — tôi đã cung cấp content)"
  fi
done

echo -e "${BLUE}═══ Phase F: Update .gitignore ═══${RESET}"

GITIGNORE=".gitignore"
patterns=(
  "infrastructure/envs/*/common.auto.tfvars"
  "infrastructure/envs/*/*.bak"
  "k8s/overlays/aws/kustomization.yaml"
  "k8s/overlays/aws/external-secret.yaml"
  "k8s/overlays/aws/ingress-alb.yaml"
  "k8s/overlays/aws/*.bak"
)

if [[ -f "$GITIGNORE" ]]; then
  for p in "${patterns[@]}"; do
    if grep -qF "$p" "$GITIGNORE"; then
      echo -e "  ${YELLOW}⚠${RESET} $p đã có trong .gitignore"
    else
      if ! $DRY_RUN; then
        echo "$p" >> "$GITIGNORE"
      fi
      echo -e "  ${GREEN}✓${RESET} Add $p vào .gitignore"
    fi
  done
fi

# ─── Tổng kết ───
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${RESET}"
echo -e "${GREEN}  ✅ Migration complete${RESET}"
echo -e "${GREEN}═══════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BLUE}Next steps:${RESET}"
echo "  1. Copy template files (.tpl) tôi đã cung cấp vào k8s/overlays/aws/"
echo "  2. Verify: cat infrastructure/backend-config.hcl"
echo "  3. Verify: cat infrastructure/common.tfvars"
echo "  4. Verify symlink: ls -la infrastructure/envs/eks/common.auto.tfvars"
echo "  5. Test init: make tf-init-all"
echo "  6. Deploy: make deploy-all"
echo ""
if $DRY_RUN; then
  echo -e "${YELLOW}⚠ DRY RUN — chạy lại không có --dry-run để áp dụng${RESET}"
else
  echo -e "${YELLOW}⚠ Các file .bak đã được tạo. Sau khi verify, xóa với:${RESET}"
  echo "  find infrastructure k8s -name '*.bak' -delete"
fi
