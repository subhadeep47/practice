# This is to install the aws provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  
  # This is to store the terraform state file in the remote backend which is a S3 bucket along with 
  # dynamoDB table to store the lockId. In DynamoDB, we only need one attribute lockId.
  backend "s3" {
    bucket = "subhadeep-terraform-state-bucket"
    dynamodb_table = "terraform-lock-db"
    key = "terraform.tfstate"
    region = "eu-north-1"
  }
}