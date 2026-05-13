# envs/eks/variables.tf

# ─── Common ──────────────────────────────────────────
variable "project" {
  type    = string
  default = "devops"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "owner" {
  type    = string
  default = "vantai"
}

# ⭐ Bucket name cho remote_state lookup
variable "tfstate_bucket" {
  description = "S3 bucket name cho remote state (network state)"
  type        = string
}

# ─── EKS ─────────────────────────────────────────────
variable "kubernetes_version" {
  description = "K8s version"
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "IP whitelist cho public API access (CHỈ IP của bạn!)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ─── Node Group ──────────────────────────────────────
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium", "t3a.medium"]
}

variable "node_capacity_type" {
  type    = string
  default = "SPOT"

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
