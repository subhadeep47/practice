environment             = "dev"
aws_region              = "us-east-1"
db_instance_class       = "db.t3.micro"
allocated_storage       = 20
engine_version          = "16"
multi_az                = false
backup_retention_period = 1

# Remote state of the vpc and eks stacks (subnets, VPC and node SG are read from here)
state_bucket = "subhadeep-terraform-state-bucket"
state_region = "eu-north-1"
