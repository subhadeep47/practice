# Everything this stack needs from the vpc and eks stacks is looked up through the AWS API
# by tag, NOT through their Terraform state. This way this stack (and its pipeline role)
# never needs read access to another stack's state file, which holds every attribute of
# that stack's resources.
# Tags are defined in terraform/vpc/main.tf and terraform/eks/main.tf ("LOOKUP CONTRACT").
# The vpc and eks stacks must be applied first; otherwise plan fails with "no matching ...".

data "aws_vpc" "this" {
  tags = {
    Name = "app-vpc-${var.environment}"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  tags = {
    Tier = "private"
  }

  lifecycle {
    postcondition {
      condition     = length(self.ids) >= 2
      error_message = "Expected at least 2 private subnets tagged Tier=private in VPC app-vpc-${var.environment} (an RDS subnet group needs two AZs). Has the vpc stack been applied?"
    }
  }
}

# Security group of the EKS worker nodes (the Spring Boot pods run on these ENIs).
data "aws_security_group" "eks_nodes" {
  vpc_id = data.aws_vpc.this.id

  tags = {
    Role    = "eks-node"
    Cluster = "app-cluster-${var.environment}"
  }
}
