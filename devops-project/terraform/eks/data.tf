# Networking comes from the vpc stack's remote state (terraform/vpc).
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "devops-project/${var.environment}/vpc/terraform.tfstate"
    region = var.state_region
  }
}
