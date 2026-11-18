provider "aws" {
  region = var.aws_region

  # Everything Terraform does in AWS happens as this role, not as the identity that started
  # the run (the AWX credential only has the right to assume it).
  assume_role {
    role_arn     = var.terraform_role_arn
    session_name = "terraform-${var.environment}-eks"
  }

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
    }
  }
}

# helm provider v3 syntax (kubernetes / exec are attributes, not blocks)
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    # --role-arn: ask for the token as the Terraform role too. That role is the cluster admin
    # (it created the cluster); the identity that started the run is not.
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--role-arn", var.terraform_role_arn]
    }
  }
}
