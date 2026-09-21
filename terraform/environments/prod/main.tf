locals {
  tags = {
    Environment = "prod"
    Cluster     = var.cluster_name
  }
}

module "vpc" {
  source             = "../../modules/vpc"
  cluster_name       = var.cluster_name
  vpc_cidr           = "10.30.0.0/16"
  single_nat_gateway = false # prod: one NAT gateway per AZ for AZ-fault isolation
  tags               = local.tags
}

module "iam" {
  source       = "../../modules/iam"
  cluster_name = var.cluster_name
}

module "eks" {
  source               = "../../modules/eks"
  cluster_name         = var.cluster_name
  kubernetes_version   = "1.30"
  cluster_role_arn     = module.iam.cluster_role_arn
  node_role_arn        = module.iam.node_role_arn
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  public_access_cidrs  = ["203.0.113.0/24"] # replace with real office/VPN CIDR - never leave 0.0.0.0/0 in prod

  system_desired_size = 3
  app_capacity_type   = "ON_DEMAND"
  app_desired_size    = 5
  app_min_size        = 3
  app_max_size        = 20

  tags = local.tags
}

module "irsa" {
  source              = "../../modules/irsa"
  cluster_name        = var.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  app_namespace       = "app"
  app_service_account = "app-sa"
}

module "rds" {
  source                   = "../../modules/rds"
  cluster_name             = var.cluster_name
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  node_security_group_id   = module.eks.cluster_security_group_id
  instance_class           = "db.r6g.large"
  multi_az                 = true  # prod: automatic failover to standby in another AZ
  backup_retention_period  = 30
  skip_final_snapshot      = false
  deletion_protection      = true
  tags                     = local.tags
}
