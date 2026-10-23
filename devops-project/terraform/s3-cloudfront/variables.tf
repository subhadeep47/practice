variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "bucket_name_prefix" {
  type        = string
  description = "Prefix for the frontend S3 bucket name"
  default     = "app-frontend-assets"
}