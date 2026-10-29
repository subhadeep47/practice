# All values come from Ansible (ansible/inventories/<env>/group_vars). Nothing here has a
# default on purpose: a missing value must fail the run instead of silently using a guess.

variable "environment" {
  type        = string
  description = "Environment name, used in resource names and tags"
}

variable "project" {
  type        = string
  description = "Project name, applied as the Project tag on every resource"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets (EKS & RDS), one per availability zone"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets (Load Balancers), one per availability zone"
}

variable "single_nat_gateway" {
  type        = bool
  description = "true = one shared NAT gateway (cheaper); false = one NAT gateway per public subnet (resilient)"
}
