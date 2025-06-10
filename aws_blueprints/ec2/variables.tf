# Variável para o tipo de instância EC2
variable "instance_type" {
  description = "O tipo da instância EC2 (ex: t2.micro, m5.large)."
  type        = string
  default     = "t2.micro"
}

# Variável para o ID da Amazon Machine Image (AMI)
variable "ami" {
  description = "O ID da AMI para usar na instância EC2. Deve ser especificado pelo usuário."
  type        = string
  # Sem valor padrão, tornando esta variável obrigatória.
}
