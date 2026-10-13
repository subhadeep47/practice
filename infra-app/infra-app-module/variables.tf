variable "env" {
  description = "This is the environment variable"
  type = string
}

variable "instance_count" {
  description = "EC2 instance count"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instances"
  type        = string
}

variable "ec2_root_storage" {
  description = "root storage volumn for the EC2 instances"
  type        = number
}