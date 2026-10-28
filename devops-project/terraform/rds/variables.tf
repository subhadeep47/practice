variable "environment" {
  type        = string
  description = "Deployment environment (e.g., dev, prod)"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance size"
}

variable "allocated_storage" {
  type        = number
  description = "Initial storage in GB"
}

variable "engine_version" {
  type        = string
  description = "PostgreSQL version. A major-only value (e.g. 16) lets RDS pick the latest minor."
  default     = "16"
}

variable "multi_az" {
  type        = bool
  description = "Deploy a standby in a second AZ"
  default     = false
}

variable "backup_retention_period" {
  type        = number
  description = "Days to keep automated backups (0 disables)"
  default     = 7
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name for Spring Boot"
  default     = "appdb"
}

variable "db_username" {
  type        = string
  description = "Database master username"
  default     = "dbadmin"
}
