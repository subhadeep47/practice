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

variable "bucket_name_prefix" {
  type        = string
  description = "Prefix for the frontend S3 bucket name; the environment is appended. S3 names are global, so make it unique to you."
}

variable "price_class" {
  type        = string
  description = "CloudFront price class (PriceClass_100 = US, Canada, Europe)"
}
