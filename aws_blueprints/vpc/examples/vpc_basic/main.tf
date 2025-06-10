# Define o provedor AWS
provider "aws" {
  region = "us-east-1" # Certifique-se de que esta região corresponde à região do seu módulo VPC
}

# Módulo para criar uma VPC básica com sub-redes pública e privada
module "vpc_setup" {
  source = "../../" # Caminho para o módulo VPC raiz

  # Opcional: Personalize os blocos CIDR e a zona de disponibilidade
  # vpc_cidr_block            = "10.10.0.0/16"
  # public_subnet_cidr_block  = "10.10.1.0/24"
  # private_subnet_cidr_block = "10.10.2.0/24"
  # availability_zone         = "us-east-1b" # Verifique as AZs disponíveis na sua região

  # Você pode adicionar tags personalizadas aqui, se necessário
  # tags = {
  #   Environment = "Development"
  #   Project     = "MyProject"
  # }
}

# Outputs do módulo VPC (opcional, mas útil para referência)
output "vpc_id" {
  description = "ID da VPC criada."
  value       = module.vpc_setup.vpc_id
}

output "public_subnet_id" {
  description = "ID da sub-rede pública."
  value       = module.vpc_setup.public_subnet_id
}

output "private_subnet_id" {
  description = "ID da sub-rede privada."
  value       = module.vpc_setup.private_subnet_id
}

output "nat_gateway_public_ip" {
  description = "IP público do NAT Gateway."
  value       = module.vpc_setup.nat_gateway_public_ip
}
