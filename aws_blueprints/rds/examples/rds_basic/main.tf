# Define o provedor AWS
provider "aws" {
  region = "us-east-1" # Certifique-se de que esta região corresponde à região do seu módulo RDS
}

# Módulo para criar uma instância RDS básica
module "rds_instance" {
  source = "../../" # Caminho para o módulo RDS raiz

  # Variáveis obrigatórias
  db_name  = "minhaaplicacaodb"    # Substitua pelo nome do seu banco de dados
  username = "adminuser"         # Substitua pelo nome de usuário desejado
  password = "PasswordSegura123!" # Substitua por uma senha forte e segura

  # Variáveis opcionais (usarão os padrões do módulo se não especificadas)
  # allocated_storage = 20
  # engine            = "mysql"
  # engine_version    = "8.0"
  # instance_class    = "db.t2.micro"

  # Você pode adicionar tags personalizadas aqui, se necessário
  # tags = {
  #   Environment = "Development"
  # }
}

# Outputs do módulo RDS (opcional, mas útil para referência)
output "rds_instance_address" {
  description = "Endpoint da instância RDS criada."
  value       = module.rds_instance.db_instance_address
}

output "rds_instance_port" {
  description = "Porta da instância RDS criada."
  value       = module.rds_instance.db_instance_port
}
