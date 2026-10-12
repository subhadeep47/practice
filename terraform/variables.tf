# defining variable to use in actual resource files such as in ec2 file
variable "ec2_instance_type" {
  default = "t3.micro"
  type = string
}

variable "ec2_ami_id" {
  default = "ami-0aba19e56f3eaec05"
  type = string
}

variable "ec2_root_storage" {
  default = 15 # In GB
  type = number
}
