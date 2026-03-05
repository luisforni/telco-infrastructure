terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
  backend "s3" {
    bucket         = "telco-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "telco-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "telco"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

variable "aws_region"   { default = "us-east-1" }
variable "environment"  { default = "prod" }
variable "cluster_name" { default = "telco-prod" }
variable "vpc_cidr"     { default = "10.0.0.0/16" }

module "vpc" {
  source = "../../modules/vpc"
  name         = "${var.environment}-telco"
  cidr         = var.vpc_cidr
  environment  = var.environment
}

module "eks" {
  source          = "../../modules/eks"
  cluster_name    = var.cluster_name
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  environment     = var.environment
}

module "kafka" {
  source         = "../../modules/kafka"
  cluster_name   = "${var.environment}-telco-kafka"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  environment    = var.environment
}

module "rds" {
  source         = "../../modules/rds"
  identifier     = "${var.environment}-telco-analytics"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  environment    = var.environment
}

module "elasticache" {
  source         = "../../modules/elasticache"
  cluster_id     = "${var.environment}-telco-redis"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  environment    = var.environment
}

module "s3_recordings" {
  source         = "../../modules/s3"
  bucket_name    = "${var.environment}-telco-recordings"
  environment    = var.environment
  kms_key_alias  = "alias/${var.environment}-telco-recordings"
  lifecycle_days = 2555  
}

output "eks_cluster_endpoint" { value = module.eks.cluster_endpoint }
output "kafka_bootstrap_brokers" { value = module.kafka.bootstrap_brokers }
output "rds_endpoint" { value = module.rds.endpoint }
output "redis_endpoint" { value = module.elasticache.endpoint }
output "recordings_bucket" { value = module.s3_recordings.bucket_name }
