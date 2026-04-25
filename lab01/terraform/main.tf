terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  public_subnet_cidr_2  = var.public_subnet_cidr_2
  private_subnet_cidr   = var.private_subnet_cidr
  private_subnet_cidr_2 = var.private_subnet_cidr_2
}

module "security_group" {
  source = "./modules/security_group"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  my_ip        = var.my_ip
  app_port     = var.app_port
}

module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id
  bastion_sg_id     = module.security_group.bastion_sg_id
  app_sg_id         = module.security_group.app_sg_id
  instance_type     = var.instance_type
  key_name          = var.key_name
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  alb_sg_id         = module.security_group.alb_sg_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_port          = var.app_port
}

module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  rds_sg_id          = module.security_group.rds_sg_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
}

module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  db_username  = var.db_username
  db_password  = var.db_password
  db_host      = module.rds.db_host
  db_name      = var.db_name
  jwt_secret   = var.jwt_secret

  depends_on = [module.rds]
}

module "ecs" {
  source = "./modules/ecs"

  project_name       = var.project_name
  aws_region         = var.aws_region
  ecs_sg_id          = module.security_group.ecs_sg_id
  private_subnet_ids = module.vpc.private_subnet_ids
  target_group_arn   = module.alb.target_group_arn
  listener_arn       = module.alb.listener_arn
  container_image    = var.container_image
  container_port     = var.app_port
  db_host            = module.rds.db_host
  db_name            = var.db_name
  db_username        = var.db_username
  db_url_secret_arn  = module.secrets.db_url_secret_arn
  jwt_secret_arn     = module.secrets.jwt_secret_arn
  secret_arns        = [
    module.secrets.db_url_secret_arn,
    module.secrets.jwt_secret_arn,
  ]
  desired_count      = var.ecs_desired_count
  depends_on         = [module.secrets]
}