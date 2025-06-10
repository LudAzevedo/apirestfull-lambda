# Variável para o bloco CIDR da VPC
variable "vpc_cidr_block" {
  description = "O bloco CIDR para a VPC."
  type        = string
  default     = "10.0.0.0/16"
}

# Variável para o bloco CIDR da sub-rede pública
variable "public_subnet_cidr_block" {
  description = "O bloco CIDR para a sub-rede pública."
  type        = string
  default     = "10.0.1.0/24"
}

# Variável para o bloco CIDR da sub-rede privada
variable "private_subnet_cidr_block" {
  description = "O bloco CIDR para a sub-rede privada."
  type        = string
  default     = "10.0.2.0/24"
}

# Variável para a zona de disponibilidade
variable "availability_zone" {
  description = "A zona de disponibilidade para as sub-redes (ex: us-east-1a, us-west-2b)."
  type        = string
  default     = "us-east-1a" # Escolha uma AZ padrão ou deixe em branco para exigir do usuário
}
