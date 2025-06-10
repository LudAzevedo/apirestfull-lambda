# Define o provedor AWS
provider "aws" {
  region = "us-east-1" # Certifique-se de que esta região corresponde à região do seu módulo S3
}

# Módulo para criar um bucket S3 básico
module "s3_bucket" {
  source = "../../" # Caminho para o módulo S3 raiz

  # Especifique o nome do bucket. Lembre-se que deve ser globalmente único.
  bucket_name = "meu-bucket-exemplo-12345abc" # Substitua por um nome de bucket único

  # Opcional: Habilitar versionamento (padrão é false)
  # enable_versioning = true

  # Você pode adicionar tags personalizadas aqui, se necessário
  # tags = {
  #   Environment = "Development"
  # }
}

# Outputs do módulo S3 (opcional, mas útil para referência)
output "s3_bucket_id" {
  description = "ID (nome) do bucket S3 criado."
  value       = module.s3_bucket.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN do bucket S3 criado."
  value       = module.s3_bucket.bucket_arn
}
