# Output para o IP público da instância EC2
output "public_ip" {
  description = "O endereço IP público da instância EC2."
  value       = aws_instance.example_instance.public_ip
}

# Output para o ID da instância EC2
output "instance_id" {
  description = "O ID da instância EC2."
  value       = aws_instance.example_instance.id
}
