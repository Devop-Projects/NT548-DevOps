# envs/eks/versions.tf

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Helm + Kubernetes provider — sẽ dùng cho addons sau
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    # Lấy auth token cho EKS
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}