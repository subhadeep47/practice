environment         = "dev"
aws_region          = "us-east-1"
cluster_version     = "1.35"
node_instance_types = ["t3.medium"]
desired_size        = 2
min_size            = 1
max_size            = 3

# Remote state of the vpc stack (VPC and private subnets are read from here)
state_bucket = "subhadeep-terraform-state-bucket"
state_region = "eu-north-1"
