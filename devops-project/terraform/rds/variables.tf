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

variable "db_instance_class" {
  type        = string
  description = "RDS instance size"
}

variable "allocated_storage" {
  type        = number
  description = "Initial storage in GB"
}

variable "max_allocated_storage" {
  type        = number
  description = "Upper limit in GB for storage autoscaling (must be larger than allocated_storage)"
}

variable "engine_version" {
  type        = string
  description = "PostgreSQL version. A major-only value (e.g. \"16\") lets RDS pick the latest minor."
}

variable "multi_az" {
  type        = bool
  description = "Deploy a standby in a second AZ"
}

variable "backup_retention_period" {
  type        = number
  description = "Days to keep automated backups (0 disables)"
}

variable "skip_final_snapshot" {
  type        = bool
  description = "true = no snapshot when the instance is destroyed (only for throwaway environments)"
}

variable "deletion_protection" {
  type        = bool
  description = "true = the instance cannot be deleted until this is switched off"
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name for Spring Boot"
}

variable "db_username" {
  type        = string
  description = "Database master username"
}
