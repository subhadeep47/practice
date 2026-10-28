resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "app-rds-subnet-group-${var.environment}"
  subnet_ids = data.aws_subnets.private.ids

  tags = {
    Environment = var.environment
  }
}

# Only the EKS worker nodes (i.e. the Spring Boot pods) may reach PostgreSQL.
resource "aws_security_group" "rds" {
  name        = "app-rds-sg-${var.environment}"
  description = "Allow PostgreSQL from EKS worker nodes"
  vpc_id      = data.aws_vpc.this.id

  tags = {
    Name        = "app-rds-sg-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_eks_nodes" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = data.aws_security_group.eks_nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from EKS worker nodes"
}

resource "aws_db_instance" "postgresql" {
  identifier            = "app-postgres-${var.environment}"
  engine                = "postgres"
  engine_version        = var.engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = 100
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username

  # RDS generates the master password and stores it in AWS Secrets Manager.
  # No password lives in Terraform code, tfvars, or CLI args.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_period
  auto_minor_version_upgrade = true

  deletion_protection       = var.environment == "dev" ? false : true
  skip_final_snapshot       = var.environment == "dev" ? true : false
  final_snapshot_identifier = var.environment == "dev" ? null : "app-postgres-${var.environment}-final"

  tags = {
    Environment = var.environment
  }
}
