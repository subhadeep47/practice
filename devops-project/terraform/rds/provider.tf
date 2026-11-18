provider "aws" {
  region = var.aws_region

  # Everything Terraform does in AWS happens as this role, not as the identity that started
  # the run (the AWX credential only has the right to assume it).
  assume_role {
    role_arn     = var.terraform_role_arn
    session_name = "terraform-${var.environment}-rds"
  }

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
    }
  }
}
