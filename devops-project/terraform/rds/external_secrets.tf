# Gives the External Secrets Operator (running in the cluster) read access to this database's
# secret in Secrets Manager, through EKS Pod Identity. No credentials or annotations are
# involved: the association below says "the service account <namespace>/<name> of this cluster
# gets this role", and the Pod Identity agent (installed by terraform/eks) hands the pods that
# use it temporary credentials.
#
# It lives in this stack because the permission is "read THIS database's secret" and the secret
# is created here. The cluster is found by its name (LOOKUP CONTRACT with terraform/eks), so the
# eks stack must be applied first.

locals {
  # Must match the cluster name created in terraform/eks (app-cluster-<env>).
  cluster_name = "app-cluster-${var.environment}"

  # Must match where the External Secrets Operator runs and the service account it uses
  # (README step 4A installs it with exactly these names).
  external_secrets_namespace = "external-secrets"

  external_secrets_service_account = "external-secrets"
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_iam_policy_document" "external_secrets_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${local.cluster_name}-external-secrets"
  description        = "External Secrets Operator: read the database secret (EKS Pod Identity)"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume.json
}

# Read access to this one secret and nothing else.
data "aws_iam_policy_document" "external_secrets_read" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_db_instance.postgresql.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "external_secrets_read" {
  name   = "read-db-secret"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets_read.json
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = data.aws_eks_cluster.this.name
  namespace       = local.external_secrets_namespace
  service_account = local.external_secrets_service_account
  role_arn        = aws_iam_role.external_secrets.arn
}
