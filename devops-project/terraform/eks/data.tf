# Networking is looked up through the AWS API by tag, NOT through the vpc stack's Terraform
# state. This way this stack (and its pipeline role) never needs read access to another
# stack's state file, which holds every attribute of that stack's resources.
# The tags are defined in terraform/vpc/main.tf ("LOOKUP CONTRACT").
# The vpc stack must be applied first; otherwise plan fails with "no matching VPC".

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
      error_message = "Expected at least 2 private subnets tagged Tier=private in VPC app-vpc-${var.environment}. Has the vpc stack been applied?"
    }
  }
}
