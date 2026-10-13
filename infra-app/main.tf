module "infra-app-dev" {
  source = "./infra-app-module"
  instance_count = 1
  instance_type = "t3.micro"
  env = "dev"
  ec2_root_storage = 10
  ami_id = "ami-0aba19e56f3eaec05" # Ubuntu
}

module "infra-app-stg" {
  source = "./infra-app-module"
  instance_count = 1
  instance_type = "t3.nano"
  env = "stg"
  ec2_root_storage = 10
  ami_id = "ami-0aba19e56f3eaec05" # Ubuntu
}

module "infra-app-prd" {
  source = "./infra-app-module"
  instance_count = 2
  instance_type = "t3.small"
  env = "prd"
  ec2_root_storage = 15
  ami_id = "ami-0aba19e56f3eaec05" # Ubuntu
}