# envs/rds/terraform.tfvars

project     = "devops"
environment = "dev"
region      = "ap-southeast-1"

db_engine_version = "8.0.40" # MySQL 8.0.40
db_instance_class = "db.t3.micro"

db_allocated_storage     = 20
db_max_allocated_storage = 100

db_name     = "appdb"
db_username = "admin"

db_multi_az                = false # Dev: single AZ
db_backup_retention_period = 1     # Dev: 1 day