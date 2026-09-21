# EKS module: managed control plane + two managed node groups (system + app),
# OIDC provider for IRSA, and cluster-level encryption of secrets via KMS.

resource "aws_kms_key" "eks" {
  description             = "EKS secrets encryption for ${var.cluster_name}"
  deletion_window_in_days = 7
  tags                    = var.tags
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = var.tags
}

# OIDC provider — the foundation of IRSA (IAM Roles for Service Accounts)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# System node group: small, always-on, runs CoreDNS / Argo CD / Prometheus / Kyverno
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "system"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.system_instance_types
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.system_desired_size
    min_size     = var.system_min_size
    max_size     = var.system_max_size
  }

  labels = { role = "system" }

  update_config {
    max_unavailable = 1
  }

  tags = var.tags
}

# App node group: autoscaled, can use Spot in dev/staging to cut cost
resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "app"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.app_instance_types
  capacity_type   = var.app_capacity_type

  scaling_config {
    desired_size = var.app_desired_size
    min_size     = var.app_min_size
    max_size     = var.app_max_size
  }

  labels = { role = "app" }

  update_config {
    max_unavailable_percentage = 25
  }

  tags = var.tags
}
