variable "environment" {
  type        = string
  description = "Deployment environment (e.g., dev, prod)"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance size"
}

variable "allocated_storage" {
  type        = number
  description = "Initial storage in GB"
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

variable "db_password" {
  type        = string
  description = "Database master password"
  sensitive   = true
}

variable "aws_region" { 
  type = string
  default = "us-east-1" 
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets for RDS DB Subnet Group"
}