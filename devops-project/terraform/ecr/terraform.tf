terraform {
  required_version = ">= 1.10.0" # use_lockfile (S3 native state locking) needs 1.10+

  # Partial configuration: bucket, key, region, encrypt and use_lockfile are passed by Ansible
  # (terraform init -backend-config=...) from ansible/inventories/<env>/group_vars.
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
