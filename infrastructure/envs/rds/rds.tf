# envs/rds/rds.tf

# ─── Security Group cho RDS ───────────────────────
# Pattern: SG-to-SG reference (không hardcode IP)
# RDS chỉ accept từ EKS worker SG — không từ Internet, không từ admin
resource "aws_security_group" "rds" {
  name_prefix = "${local.db_identifier}-sg-"
  description = "RDS security group - only EKS workers can connect"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # Inbound: chỉ MySQL từ EKS workers
  ingress {
    description     = "MySQL from EKS workers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    # security_groups = [data.terraform_remote_state.eks.outputs.node_security_group_id]
  }

  # Outbound: tất cả (RDS không khởi tạo connection ra ngoài)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true # Tránh downtime khi rename SG
  }

  tags = merge(local.common_tags, {
    Name = "${local.db_identifier}-sg"
  })
}

# ─── DB Subnet Group ──────────────────────────────
# Tận dụng private subnets của VPC (Phần 2.2)
resource "aws_db_subnet_group" "main" {
  name        = "${local.db_identifier}-subnet-group"
  description = "RDS subnet group for private subnets"
  subnet_ids  = data.terraform_remote_state.network.outputs.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.db_identifier}-subnet-group"
  })
}

# ─── DB Parameter Group ───────────────────────────
# Config tuning cho MySQL
resource "aws_db_parameter_group" "main" {
  name        = "${local.db_identifier}-params"
  family      = "mysql8.0"
  description = "MySQL 8.0 parameter group"

  # Performance tuning examples
  parameter {
    name  = "max_connections"
    value = "100" # Default 151 cho t3.micro, tune theo workload
  }

  parameter {
    name  = "slow_query_log"
    value = "1" # Enable slow query log
  }

  parameter {
    name  = "long_query_time"
    value = "2" # Log query > 2s
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ─── KMS key cho encryption at rest ───────────────
resource "aws_kms_key" "rds" {
  description             = "RDS encryption key — ${local.db_identifier}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.db_identifier}-encryption"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.db_identifier}-encryption"
  target_key_id = aws_kms_key.rds.key_id
}

# ─── RDS Instance ⭐ ───────────────────────────────
resource "aws_db_instance" "main" {
  # Identity
  identifier = local.db_identifier

  # Engine
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # ─── Database ───
  db_name  = var.db_name
  username = var.db_username

  # ─── Password — MAGIC IS HERE ────────────────────
  # AWS auto-generate password + lưu Secrets Manager
  # Pod đọc password qua External Secrets Operator (Phase 6)
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds.arn

  # ─── Network ───
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # PRIVATE only — defense in depth

  # ─── Parameter group ───
  parameter_group_name = aws_db_parameter_group.main.name

  # ─── HA ───
  multi_az = var.db_multi_az # Dev: false, prod: true

  # ─── Backup ───
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00" # UTC = 10-11am Vietnam
  maintenance_window      = "Sun:04:00-Sun:05:00"

  # ─── Monitoring ───
  performance_insights_enabled          = false # Dev: false. Prod: true (tốn tiền)
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60 # Enhanced monitoring 60s
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn

  # ─── Logs ───
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  # ─── Lifecycle ───
  # Production: skip_final_snapshot = false (LUÔN snapshot trước destroy)
  # Dev: true cho tiện destroy
  skip_final_snapshot      = true
  delete_automated_backups = true
  deletion_protection      = false # Dev: false. Prod: TRUE!

  # ─── Misc ───
  apply_immediately          = false # Apply trong maintenance window (an toàn hơn)
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true

  tags = merge(local.common_tags, {
    Name = local.db_identifier
  })
}

# ─── IAM role cho RDS Enhanced Monitoring ─────────
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.db_identifier}-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}