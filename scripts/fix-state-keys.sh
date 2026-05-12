#!/usr/bin/env bash
# ============================================================================
# scripts/fix-state-keys.sh
# ============================================================================
# Sửa lỗi state key mismatch:
#   Network state đang ghi vào `dev/dev/terraform.tfstate` (sai)
#   Phải là `dev/network/terraform.tfstate` (đúng — match remote_state lookup)
#
# Strategy: move state trong S3 + re-init local
# ============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

BUCKET="thesis-tfstate-954692413669"
WRONG_KEY="dev/dev/terraform.tfstate"
RIGHT_KEY="dev/network/terraform.tfstate"

echo -e "${BLUE}═══ Step 1: Kiểm tra state hiện tại trên S3 ═══${RESET}"
aws s3 ls "s3://${BUCKET}/dev/" --recursive 2>&1 || {
  echo -e "${RED}✗ Không liệt kê được bucket. Check AWS credentials.${RESET}"
  exit 1
}

echo ""
echo -e "${BLUE}═══ Step 2: Verify state cũ có tồn tại không ═══${RESET}"
if aws s3api head-object --bucket "$BUCKET" --key "$WRONG_KEY" >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ Tìm thấy state ở vị trí sai: s3://${BUCKET}/${WRONG_KEY}${RESET}"
  HAS_WRONG=true
else
  echo -e "${GREEN}✓ Không có state ở vị trí sai. Có thể bỏ qua step 3-4.${RESET}"
  HAS_WRONG=false
fi

if aws s3api head-object --bucket "$BUCKET" --key "$RIGHT_KEY" >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ Đã có state ở vị trí đúng: s3://${BUCKET}/${RIGHT_KEY}${RESET}"
  echo -e "${YELLOW}  → Bạn cần quyết định: dùng state mới hay state cũ?${RESET}"
fi

if [[ "$HAS_WRONG" == "false" ]]; then
  echo ""
  echo -e "${GREEN}═══ Không cần migrate. Chỉ cần init lại với Makefile mới ═══${RESET}"
  echo "  cd ~/NT548-DevOps"
  echo "  make tf-init-all"
  exit 0
fi

echo ""
echo -e "${BLUE}═══ Step 3: Move state cũ → vị trí đúng ═══${RESET}"
read -p "Type 'move' để confirm di chuyển state: " confirm
if [[ "$confirm" != "move" ]]; then
  echo "Aborted."
  exit 1
fi

# Backup state cũ về local (safety)
echo "  Backup state cũ về /tmp/network-state-backup.tfstate ..."
aws s3 cp "s3://${BUCKET}/${WRONG_KEY}" /tmp/network-state-backup.tfstate

# Copy sang key mới
echo "  Copy: s3://${BUCKET}/${WRONG_KEY} → s3://${BUCKET}/${RIGHT_KEY}"
aws s3 cp "s3://${BUCKET}/${WRONG_KEY}" "s3://${BUCKET}/${RIGHT_KEY}"

# Xóa key cũ
echo "  Xóa state cũ..."
aws s3 rm "s3://${BUCKET}/${WRONG_KEY}"

# Cleanup local .terraform của network state (force re-init)
echo "  Cleanup local .terraform của network..."
rm -rf ~/NT548-DevOps/infrastructure/envs/dev/.terraform
rm -f  ~/NT548-DevOps/infrastructure/envs/dev/.terraform.lock.hcl

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${RESET}"
echo -e "${GREEN}  ✓ State migrated${RESET}"
echo -e "${GREEN}═══════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BLUE}Next steps:${RESET}"
echo "  1. Apply Makefile mới (v2.1) — đã đính kèm"
echo "  2. cd ~/NT548-DevOps"
echo "  3. make tf-init-all          # Init lại với key đúng"
echo "  4. cd infrastructure/envs/dev && terraform plan"
echo "     → Phải báo 'No changes' (state đã match với code)"
echo "  5. Nếu OK: make tf-apply-eks"
echo ""
echo -e "${YELLOW}Backup local: /tmp/network-state-backup.tfstate${RESET}"