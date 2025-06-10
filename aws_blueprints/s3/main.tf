# Define o provedor AWS
provider "aws" {
  region = "us-east-1" # Exemplo de região, pode ser alterado conforme necessário
}

# Define o recurso do bucket S3
resource "aws_s3_bucket" "example_bucket" {
  bucket = var.bucket_name

  # Configuração de versionamento baseada na variável enable_versioning
  versioning {
    enabled = var.enable_versioning
  }

  tags = {
    Name = var.bucket_name
  }
}

# ACL (Access Control List) opcional: define o bucket como privado
# Se você precisar de outras configurações de ACL, ajuste conforme necessário.
resource "aws_s3_bucket_acl" "example_bucket_acl" {
  bucket = aws_s3_bucket.example_bucket.id
  acl    = "private"
}
