# IRSA module: scoped IAM role assumed by the app's Kubernetes ServiceAccount
# via the cluster's OIDC provider. Grants exactly one Secrets Manager path —
# this is what replaces broad node-level IAM permissions.

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.app_namespace}:${var.app_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.cluster_name}-app-irsa"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_iam_policy_document" "secrets_read" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/app/*"]
  }
}

resource "aws_iam_role_policy" "secrets_read" {
  name   = "${var.cluster_name}-app-secrets-read"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.secrets_read.json
}
