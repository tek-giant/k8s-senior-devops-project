output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "app_irsa_role_arn" {
  value = module.irsa.app_irsa_role_arn
}

output "db_secret_arn" {
  value = module.rds.db_secret_arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
