# Networking comes from the vpc stack, worker-node security group from the eks stack.
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "devops-project/${var.environment}/vpc/terraform.tfstate"
    region = var.state_region
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "devops-project/${var.environment}/eks/terraform.tfstate"
    region = var.state_region
  }
}
