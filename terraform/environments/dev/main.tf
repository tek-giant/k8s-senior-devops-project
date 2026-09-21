locals {
  tags = {
    Environment = "dev"
    Cluster     = var.cluster_name
  }
}

module "vpc" {
  source             = "../../modules/vpc"
  cluster_name       = var.cluster_name
  vpc_cidr           = "10.10.0.0/16"
  single_nat_gateway = true # dev: cost-optimized, one NAT gateway
  tags               = local.tags
}

module "iam" {
  source       = "../../modules/iam"
  cluster_name = var.cluster_name
}

module "eks" {
  source              = "../../modules/eks"
  cluster_name        = var.cluster_name
  kubernetes_version  = "1.30"
  cluster_role_arn    = module.iam.cluster_role_arn
  node_role_arn       = module.iam.node_role_arn
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids

  # dev: small, Spot-capable app node group
  system_desired_size = 2
  app_capacity_type   = "SPOT"
  app_desired_size    = 2
  app_min_size        = 1
  app_max_size        = 5

  tags = local.tags
}

module "irsa" {
  source               = "../../modules/irsa"
  cluster_name         = var.cluster_name
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  app_namespace        = "app"
  app_service_account  = "app-sa"
}

module "rds" {
  source                  = "../../modules/rds"
  cluster_name            = var.cluster_name
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  node_security_group_id  = module.eks.cluster_security_group_id
  instance_class          = "db.t4g.medium"
  multi_az                = false # dev only; prod sets true
  deletion_protection     = false
  tags                    = local.tags
}
