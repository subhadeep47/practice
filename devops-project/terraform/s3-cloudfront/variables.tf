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
  description = "Prefix for the frontend S3 bucket name (S3 names are global; make it unique to you)"
  default     = "app-frontend-assets"
}

variable "price_class" {
  type        = string
  description = "CloudFront price class (PriceClass_100 = US, Canada, Europe)"
  default     = "PriceClass_100"
}
