# Modules are a reusable template to write our own configuration for a resource in a easy manner
module "vpc" {
  source = "terraform-aws-modules/vpc/aws" # Its important as terraform will get the actual resource block to create this vpc from this source

  name = "terraform-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-north-1a", "eu-north-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = var.env
  }
}