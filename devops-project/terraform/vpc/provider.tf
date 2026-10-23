provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "fullstack-app"
      Environment = var.environment
    }
  }
}