# This will create a s3 bucket, We need to have aws cli installed in our machine so that it can have aws credentials to create the resources
resource "aws_s3_bucket" "my_bucket" {
  bucket = "subhadeep-terraform-bucket"
  tags = {
    name = "terraform-learn"
  }
}