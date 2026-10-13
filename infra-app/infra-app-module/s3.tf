resource "aws_s3_bucket" "infra-app-bucket" {
  bucket = "${var.env}-infra-app-bucket"

  tags = {
    name = "${var.env}-infra-app-bucket"
    environment = var.env
  }
}

resource "aws_s3_bucket_public_access_block" "infra-app-bucket" {
  bucket = aws_s3_bucket.infra-app-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}