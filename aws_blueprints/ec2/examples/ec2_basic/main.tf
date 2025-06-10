# Define o provedor AWS
provider "aws" {
  region = "us-east-1" # Certifique-se de que esta região corresponde à região do seu módulo EC2
}

# Módulo para criar uma instância EC2 básica
module "ec2_instance" {
  source = "../../" # Caminho para o módulo EC2 raiz

  # Especifique o ID da AMI desejado.
  # Você pode encontrar AMIs na documentação da AWS ou no console da AWS.
  # Exemplo: ami-0c55b31ad1eba91b6 (Ubuntu Server 20.04 LTS - us-east-1)
  ami = "ami-0c55b31ad1eba91b6" # Substitua pelo AMI ID desejado

  instance_type = "t2.micro" # Opcional, o padrão é t2.micro

  # Você pode adicionar tags personalizadas aqui, se necessário
  # tags = {
  #   Environment = "Development"
  # }
}

# Outputs do módulo EC2 (opcional, mas útil para referência)
output "instance_public_ip" {
  description = "IP público da instância EC2 criada."
  value       = module.ec2_instance.public_ip
}

output "instance_id" {
  description = "ID da instância EC2 criada."
  value       = module.ec2_instance.instance_id
}
