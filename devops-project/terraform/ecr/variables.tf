# All values come from Ansible (ansible/inventories/<env>/group_vars). Nothing here has a
# default on purpose: a missing value must fail the run instead of silently using a guess.

variable "environment" {
  type        = string
  description = "Environment name, used in tags"
}

variable "project" {
  type        = string
  description = "Project name, applied as the Project tag on every resource"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "repository_name" {
  type        = string
  description = "ECR repository name for the backend image (slashes allowed, e.g. fullstack-app/backend-dev)"
}

variable "keep_last_images" {
  type        = number
  description = "How many tagged images to keep; older ones are expired by a lifecycle rule"
}

variable "force_delete" {
  type        = bool
  description = "true lets Terraform delete the repository even if it still holds images (dev). false protects the images (prod)."
}

variable "create_github_oidc_provider" {
  type        = bool
  description = "true creates the account's GitHub Actions OIDC identity provider. There can be only one per AWS account: set false if it already exists (it is then looked up)."
}

variable "github_oidc_subjects" {
  type        = list(string)
  description = "Which GitHub workflows may push images, as OIDC subject patterns, e.g. [\"repo:my-user/my-backend:ref:refs/heads/main\"]"
}
