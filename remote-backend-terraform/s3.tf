resource "aws_s3_bucket" "terraform-state-bucket" {
  bucket = "subhadeep-terraform-state-bucket"
  tags = {
    name = "subhadeep-terraform-state-bucket-learn"
  }
}