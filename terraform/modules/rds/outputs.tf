output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "db_endpoint" {
  value = aws_db_instance.this.address
}
