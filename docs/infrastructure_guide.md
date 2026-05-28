# Hướng dẫn chi tiết triển khai hạ tầng AWS (Terraform)

Tài liệu này hướng dẫn từng bước để bạn thiết lập hạ tầng đám mây cho dự án NT548 Task Manager trên AWS.

---

## 1. Chuẩn bị (Prerequisites)

Trước khi bắt đầu, hãy đảm bảo bạn đã cài đặt các công cụ sau:
- **AWS CLI v2** & cấu hình quyền: `aws configure`
- **Terraform** >= 1.5
- **kubectl** & **helm**
- **yq** (để xử lý file YAML trong script)
- **Make**

Ngoài ra, bạn cần:
- **Domain & Route53:** Một tên miền đã có **Hosted Zone** trên Route53. 
    - *Tại sao?* Để Terraform có thể tự động tạo bản ghi xác thực SSL (ACM) và trỏ Load Balancer về domain ngay khi triển khai. Nếu bạn chưa có Hosted Zone, hãy tạo nó trước trên AWS Console và trỏ Name Servers từ nhà đăng ký (GoDaddy, Namecheap...) về AWS.
- **Github Token:** Một Github Token (Personal Access Token) có quyền repo để CI/CD có thể đẩy code qua config repo.

---

## 2. Cấu hình thông tin dự án

Bạn **BẮT BUỘC** phải chỉnh sửa các file sau để phù hợp với tài khoản AWS của mình:

### Step 2.1: Cấu hình chung
Mở file `infrastructure/common.tfvars`:
```hcl
project        = "devops"          # Tên dự án (dùng để đặt tên resource)
environment    = "dev"             # Môi trường (dev/staging/prod)
region         = "ap-southeast-1"  # Region bạn muốn triển khai
owner          = "yourname"        # Tên người sở hữu (để gắn tag)
tfstate_bucket = "thesis-tfstate-<YOUR_ACCOUNT_ID>" # Tên bucket cho TF state (sẽ tạo ở bước sau)
```

### Step 2.2: Cấu hình DNS
Mở file `infrastructure/envs/dns/terraform.tfvars`:
```hcl
domain_name        = "yourdomain.com" # Tên miền của bạn
subdomain          = "task-manager"   # Subdomain cho app (task-manager.yourdomain.com)
create_hosted_zone = false            # Set true nếu chưa có Hosted Zone, false nếu đã có
alb_exists         = false            # MẶC ĐỊNH là false khi bắt đầu deploy
```

### Step 2.3: Cấu hình Remote State Backend
Mở file `infrastructure/backend-config.hcl`:
```hcl
bucket         = "thesis-tfstate-<YOUR_ACCOUNT_ID>" # Trùng với common.tfvars
region         = "ap-southeast-1"
dynamodb_table = "thesis-tfstate-locks"
encrypt        = true
```

---

## 3. Khởi tạo Backend (Bootstrap)

Hạ tầng này dùng S3 làm nơi lưu trữ file `.tfstate` và DynamoDB để lock (tránh 2 người cùng sửa 1 lúc).

1. Mở terminal tại thư mục gốc của dự án.
2. Chạy lệnh:
   ```bash
   make bootstrap
   ```
   *Lệnh này sẽ tạo S3 bucket và DynamoDB table dựa trên cấu hình bạn vừa sửa.*

---

## 4. Triển khai hạ tầng từng bước (hoặc tự động)

Bạn có 2 lựa chọn:

### Cách 1: Chạy tự động toàn bộ (Khuyên dùng)
```bash
make deploy
```
*Lệnh này sẽ chạy ~35-40 phút, thực hiện toàn bộ 7 Stage từ tạo mạng, cụm EKS, Database cho đến cài đặt ArgoCD.*

### Cách 2: Triển khai thủ công từng phần để kiểm soát
Nếu muốn đi từng bước, hãy chạy:

1. **Mạng (VPC):**
   ```bash
   cd infrastructure/envs/dev && terraform init -backend-config=../../backend-config.hcl -backend-config="key=dev/network/terraform.tfstate"
   terraform apply -auto-approve
   ```

2. **Cụm EKS:**
   ```bash
   cd ../eks && terraform init -backend-config=../../backend-config.hcl -backend-config="key=dev/eks/terraform.tfstate"
   terraform apply -auto-approve
   ```

3. **Cơ sở dữ liệu (RDS):**
   ```bash
   cd ../rds && terraform init -backend-config=../../backend-config.hcl -backend-config="key=dev/rds/terraform.tfstate"
   terraform apply -auto-approve
   ```

4. **Secrets (Lưu trữ mật khẩu):**
   ```bash
   cd ../secrets && terraform init -backend-config=../../backend-config.hcl -backend-config="key=dev/secrets/terraform.tfstate"
   terraform apply -auto-approve
   ```

5. **DNS Phase 1 (Tạo Certificate SSL):**
   ```bash
   cd ../dns && terraform init -backend-config=../../backend-config.hcl -backend-config="key=dev/dns/terraform.tfstate"
   terraform apply -auto-approve
   ```

---

## 5. Kết nối kubectl với EKS

Sau khi EKS tạo xong, bạn cần cấu hình để máy tính có thể điều khiển cụm:
```bash
aws eks update-kubeconfig --region <REGION> --name <CLUSTER_NAME>
# Ví dụ: aws eks update-kubeconfig --region ap-southeast-1 --name devops-dev
```

Kiểm tra kết nối:
```bash
kubectl get nodes
```

---

## 6. Tổng kết các tài nguyên được tạo
- **VPC:** 1 mạng riêng với 2 subnet public, 2 subnet private.
- **EKS:** Cụm Kubernetes bản 1.30, sử dụng Spot Instance để tiết kiệm 70% chi phí.
- **RDS:** 1 Database PostgreSQL instance loại `t3.micro`.
- **Secrets Manager:** Lưu trữ tự động mật khẩu DB, JWT Secret.
- **ACM:** Chứng chỉ SSL miễn phí từ AWS cho domain của bạn.

**Tiếp theo:** Sau khi hạ tầng sẵn sàng, hãy chuyển sang bước **Cài đặt hệ thống & GitOps**.
