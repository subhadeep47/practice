variable "environment" { 
  type = string 

}
variable "aws_region" { 
  type = string 
  default = "us-east-1" 
}

variable "cluster_version" { 
  type = string 
  default = "1.28"

}
variable "node_instance_types" { 
  type = list(string) 

}
variable "desired_size" { 
  type = number 

}
variable "max_size" { 
  type = number 
}

variable "min_size" { 
  type = number 
}

# Network integration variables
variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for EKS worker nodes"
}