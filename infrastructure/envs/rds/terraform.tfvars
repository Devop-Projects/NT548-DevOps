# envs/rds/terraform.tfvars

project     = "devops-thesis"
environment = "dev"
region      = "ap-southeast-1"

# PostgreSQL config
db_engine         = "postgres"
db_engine_version = "15.17"
db_instance_class = "db.t3.micro"
db_port           = 5432

# Storage
db_allocated_storage     = 20
db_max_allocated_storage = 100

# Database
db_name     = "appdb"
db_username = "appuser" # KHÔNG dùng "admin" với PostgreSQL

# HA / Backup
db_multi_az                = false
db_backup_retention_period = 1