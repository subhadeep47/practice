locals {
  # Must match the cluster name created in terraform/eks (app-cluster-<env>).
  cluster_name = "app-cluster-${var.environment}"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "app-vpc-${var.environment}"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment == "dev" ? true : false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # LOOKUP CONTRACT: the eks and rds stacks find this VPC and its subnets through the AWS
  # API using these tags (no shared Terraform state). Do not rename them without updating
  # the data sources in terraform/eks/data.tf and terraform/rds/data.tf.
  #   VPC:     tag Name = app-vpc-<env>   (set by the module from `name`)
  #   Subnets: tag Tier = public | private, inside that VPC
  #
  # The kubernetes.io tags are what the AWS Load Balancer Controller / EKS use to discover subnets.
  public_subnet_tags = {
    "Tier"                                        = "public"
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "Tier"                                        = "private"
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = {
    Environment = var.environment
  }
}
