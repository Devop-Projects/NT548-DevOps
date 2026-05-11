# envs/rds/rds.tf
#
# RDS PostgreSQL 15 với:
# - Secrets Manager auto-managed password
# - Encryption at rest (KMS)
# - Multi-AZ (toggle qua var)
# - Enhanced Monitoring + CloudWatch logs
#
# Design decisions:
# - Performance Insights: DISABLED cho dev (tiết kiệm ~$8/month)
# - apply_immediately: TRUE cho dev (fast feedback)
# - Multi-AZ: FALSE cho dev (single AZ tiết kiệm 50%)

# ─── Security Group cho RDS ───────────────────────
# Pattern: SG-to-SG reference (không hardcode IP)
# Why? IP của EKS workers thay đổi khi scale → SG-to-SG luôn match
resource "aws_security_group" "rds" {
  name_prefix = "${local.db_identifier}-sg-"
  description = "RDS PostgreSQL security group - only EKS workers can connect"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # Inbound: PostgreSQL 5432 từ EKS workers
  ingress {
    description     = "PostgreSQL from EKS worker nodes"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.eks.outputs.node_security_group_id]
  }

  # Outbound: tất cả (RDS không initiate connection ra ngoài, nhưng để default cho safety)
  egress {
    description = "Allow all outbound (RDS does not initiate connections)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.db_identifier}-sg"
  })
}

# ─── DB Subnet Group ──────────────────────────────
# RDS phải nằm trong private subnets (defense in depth)
resource "aws_db_subnet_group" "main" {
  name        = "${local.db_identifier}-subnet-group"
  description = "RDS subnet group - private subnets only"
  subnet_ids  = data.terraform_remote_state.network.outputs.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.db_identifier}-subnet-group"
  })
}

# ─── DB Parameter Group ───────────────────────────
# PostgreSQL parameters (KHÁC MySQL):
# - log_statement: log gì? (none/ddl/mod/all)
# - log_min_duration_statement: log query > N ms
resource "aws_db_parameter_group" "main" {
  name        = "${local.db_identifier}-params"
  family      = "postgres15"
  description = "PostgreSQL 15 parameter group"

  # Log mọi DDL (CREATE TABLE, ALTER...) — useful cho audit
  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  # Log slow query > 2000ms = 2s
  parameter {
    name  = "log_min_duration_statement"
    value = "2000"
  }

  # Log connection events (audit trail)
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
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
  # ─── Identity ─────────────────────────────────
  identifier = local.db_identifier

  # ─── Engine ───────────────────────────────────
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  port           = var.db_port

  # ─── Storage ──────────────────────────────────
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # ─── Database ─────────────────────────────────
  db_name  = var.db_name
  username = var.db_username

  # ─── Password — AWS-managed (Secrets Manager) ─
  # AWS auto-generate strong password, lưu Secrets Manager
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds.arn

  # ─── Network ──────────────────────────────────
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # ─── Parameter group ──────────────────────────
  parameter_group_name = aws_db_parameter_group.main.name

  # ─── HA ───────────────────────────────────────
  multi_az = var.db_multi_az

  # ─── Backup ───────────────────────────────────
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"          # UTC = 10-11am Vietnam (low traffic)
  maintenance_window      = "Sun:04:00-Sun:05:00"  # UTC

  # ─── Performance Insights — DISABLED cho dev ──
  # ⚠️ Khi disabled, KHÔNG được set kms_key_id và retention_period
  # AWS RDS API sẽ reject với InvalidParameterCombination
  performance_insights_enabled = false

  # ─── Enhanced Monitoring (basic CloudWatch) ──
  monitoring_interval = 60  # OS-level metrics mỗi 60s
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # ─── CloudWatch Logs Export ───────────────────
  # PostgreSQL log types: postgresql (general), upgrade (version upgrade events)
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # ─── Lifecycle ────────────────────────────────
  skip_final_snapshot      = true   # Dev: true cho tiện destroy. ⚠️ Prod: PHẢI false
  delete_automated_backups = true
  deletion_protection      = false  # ⚠️ Prod: PHẢI true

  # ─── Misc ─────────────────────────────────────
  apply_immediately          = true   # Dev: true cho fast feedback. Prod: false
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