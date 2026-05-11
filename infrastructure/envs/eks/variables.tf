# envs/eks/variables.tf

# ─── Common ──────────────────────────────────────────
variable "project" {
  type    = string
  default = "devops-thesis"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

# ─── EKS ─────────────────────────────────────────────
variable "kubernetes_version" {
  description = "K8s version"
  type        = string
  default     = "1.30" # Latest stable EKS-supported version
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "IP whitelist cho public API access (CHỈ IP của bạn!)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # ⚠️ Tạm — sẽ siết lại

  # ⚠️ KHUYÊN: Set IP của bạn:
  # default = ["1.2.3.4/32"]   ← thay 1.2.3.4 bằng IP thật
}

# ─── Node Group ──────────────────────────────────────
variable "node_instance_types" {
  description = "EC2 instance types cho worker"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"] # Multi-type for spot resilience
}

variable "node_capacity_type" {
  description = "ON_DEMAND hoặc SPOT"
  type        = string
  default     = "SPOT" # Tiết kiệm 70%, OK cho dev

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "Phải là ON_DEMAND hoặc SPOT."
  }
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "node_desired_size" {
  type    = number
  default = 2
}