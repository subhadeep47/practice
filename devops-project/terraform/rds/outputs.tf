output "db_endpoint" {
  value       = aws_db_instance.postgresql.address
  description = "PostgreSQL database hostname"
}

output "db_port" {
  value       = aws_db_instance.postgresql.port
  description = "PostgreSQL port"
}

output "db_name" {
  value       = var.db_name
  description = "Database name"
}

output "db_username" {
  value       = var.db_username
  description = "Database master username"
}

output "db_master_secret_arn" {
  value       = aws_db_instance.postgresql.master_user_secret[0].secret_arn
  description = "Secrets Manager secret holding the generated master credentials (JSON with username and password)"
}

output "db_security_group_id" {
  value       = aws_security_group.rds.id
  description = "Security group attached to the RDS instance"
}
