resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "app-rds-subnet-group-${var.environment}"
  subnet_ids = var.subnet_ids

  tags = {
    Environment = var.environment
  }
}

resource "aws_db_instance" "postgresql" {
  identifier             = "app-postgres-${var.environment}"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = var.db_instance_class
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = 100
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  skip_final_snapshot    = var.environment == "dev" ? true : false
  publicly_accessible    = false

  tags = {
    Environment = var.environment
  }
}