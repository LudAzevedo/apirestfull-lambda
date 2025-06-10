# Output para o ID da VPC
output "vpc_id" {
  description = "O ID da VPC criada."
  value       = aws_vpc.main_vpc.id
}

# Output para o ID da sub-rede pública
output "public_subnet_id" {
  description = "O ID da sub-rede pública criada."
  value       = aws_subnet.public_subnet.id
}

# Output para o ID da sub-rede privada
output "private_subnet_id" {
  description = "O ID da sub-rede privada criada."
  value       = aws_subnet.private_subnet.id
}

# Output para o ID do NAT Gateway (útil para referência)
output "nat_gateway_id" {
  description = "O ID do NAT Gateway criado."
  value       = aws_nat_gateway.nat_gw.id
}

# Output para o IP público do NAT Gateway (EIP)
output "nat_gateway_public_ip" {
  description = "O endereço IP público associado ao NAT Gateway."
  value       = aws_eip.nat_eip.public_ip
}
