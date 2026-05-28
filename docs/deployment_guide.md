# Hướng dẫn cài đặt hệ thống & GitOps (Application Deployment)

Tài liệu này hướng dẫn cách triển khai ứng dụng lên cụm EKS đã tạo ở bước trước bằng phương pháp GitOps với ArgoCD.

---

## 1. Chuẩn bị Config Repository

Dự án này sử dụng mô hình 2 repo:
1. **App Repo (Repo hiện tại):** Chứa code ứng dụng và Terraform.
2. **Config Repo (Ví dụ: `nt548-config`):** Chứa Helm Chart và manifests Kubernetes.

### Step 1.1: Clone Config Repo
Clone repo cấu hình về máy cùng cấp thư mục với repo hiện tại:
```bash
cd ..
git clone https://github.com/<YOUR_ORG>/nt548-config.git
export CONFIG_REPO=$(pwd)/nt548-config
```

---

## 2. Đồng bộ hóa thông số hạ tầng (Sync Helm Values)

Mỗi lần hạ tầng thay đổi (ví dụ: tạo lại DB mới có endpoint khác), bạn cần cập nhật thông số đó vào Helm chart.

1. Quay lại repo chính:
   ```bash
   cd NT548-DevOps
   ```
2. Chạy script đồng bộ:
   ```bash
   ./scripts/update-helm-values.sh --commit
   ```
   *Script này sẽ tự động đọc Output từ Terraform và ghi đè vào file `values-aws-dev.yaml` trong config repo, sau đó commit & push lên GitHub.*

---

## 3. Cài đặt ArgoCD & Bootstrap Hệ thống

Chúng ta sẽ sử dụng `Make` để tự động hóa việc cài đặt các thành phần nền tảng.

1. **Cài đặt ArgoCD:**
   ```bash
   make _install-argocd
   ```

2. **Cài đặt các dịch vụ nền (Monitoring, Rollouts, Secrets):**
   ```bash
   make _bootstrap-apps
   ```
   *Lệnh này sẽ cài đặt:*
   - **Prometheus & Grafana:** Để theo dõi sức khỏe hệ thống.
   - **Argo Rollouts:** Để triển khai Blue/Green deployment.
   - **External Secrets:** Tự động lấy mật khẩu từ AWS Secrets Manager đưa vào Pod.
   - **Ứng dụng chính (Task Manager):** Kéo Docker image và chạy app.

---

## 4. Hoàn tất cấu hình DNS (Phase 2)

Khi ứng dụng chạy, AWS Load Balancer Controller sẽ tạo ra một Load Balancer (ALB). Bạn cần lấy DNS của ALB này trỏ về domain của mình.

1. Kiểm tra xem ALB đã có DNS chưa:
   ```bash
   kubectl get ingress -n task-manager-dev
   ```
2. Cập nhật Route53:
   ```bash
   # Chỉnh sửa file infrastructure/envs/dns/terraform.tfvars
   # set alb_exists = true
   
   cd infrastructure/envs/dns
   terraform apply -auto-approve
   ```
   *(Hoặc đơn giản là chạy `make _stage-6-dns-phase2`)*

---

## 5. Truy cập hệ thống

Sau khi DNS propagate (1-2 phút), bạn có thể truy cập:
- **Ứng dụng:** `https://task-manager.yourdomain.com`
- **Grafana (Dashboard):** `https://grafana.yourdomain.com`
- **ArgoCD UI:**
  ```bash
  make argocd-ui
  # Truy cập http://localhost:8080 (User: admin)
  # Lấy pass: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

---

## 6. Quy trình phát triển (CI/CD Flow)

Khi bạn muốn cập nhật code ứng dụng:
1. Sửa code trong thư mục `app/mono`.
2. Push code lên repo GitHub.
3. **GitHub Action** sẽ tự động:
   - Chạy Test & Scan bảo mật.
   - Build Docker Image mới.
   - **Tự động cập nhật Tag image** vào config repo.
4. **ArgoCD** phát hiện config repo thay đổi và tự động cập nhật ứng dụng trên EKS (GitOps).

---

## 7. Tiết kiệm chi phí (Hibernate)

Nếu không sử dụng (ví dụ buổi tối), bạn có thể tạm dừng hệ thống để tiết kiệm 70% chi phí:
```bash
make hibernate
```
Khi cần dùng lại:
```bash
make wake
make wake-dns
```
