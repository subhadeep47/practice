resource "aws_dynamodb_table" "my_app_table" {
  name         = "terraform-lock-db"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "lockId"

  attribute {
    name = "lockId"
    type = "S"
  }

  tags = {
    name        = "terraform-lock-db"
  }
}