resource "aws_dynamodb_table" "infra_app_table" {
  name         = "${var.env}-infra-app-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    name        = "${var.env}-infra-app-table"
    environment = var.env
  }
}