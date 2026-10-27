terraform {
  required_version = ">= 1.10.0" # use_lockfile (S3 native state locking) needs 1.10+

  # Partial configuration: bucket/key/region come from
  #   terraform init -backend-config=environments/<env>.backend.hcl
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}
