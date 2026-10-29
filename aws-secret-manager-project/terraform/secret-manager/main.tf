provider "aws" {
  region = var.aws_region
}

resource "aws_secretsmanager_secret" "db_secret" {
  name = var.secret_name
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = var.db_password
}
