output "db_endpoint" {
  value       = aws_db_instance.postgresql.address
  description = "PostgreSQL database hostname"
}

output "db_name" {
  value       = var.db_name
  description = "Database name"
}