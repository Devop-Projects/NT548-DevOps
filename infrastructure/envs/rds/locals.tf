# envs/rds/locals.tf

locals {
  db_identifier = "${var.project}-${var.environment}-db"

  common_tags = {
    Component = "rds"
  }
}