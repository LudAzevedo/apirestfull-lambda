# Output para o endpoint (endereço) da instância de banco de dados RDS
output "db_instance_address" {
  description = "O endpoint (endereço) da instância de banco de dados RDS."
  value       = aws_db_instance.example_db_instance.address
}

# Output para a porta da instância de banco de dados RDS
output "db_instance_port" {
  description = "A porta da instância de banco de dados RDS."
  value       = aws_db_instance.example_db_instance.port
}
