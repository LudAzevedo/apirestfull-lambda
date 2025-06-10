# Define o provedor AWS
provider "aws" {
  region = "us-east-1" # Exemplo de região, pode ser alterado conforme necessário
}

# Define o recurso da instância de banco de dados RDS
resource "aws_db_instance" "example_db_instance" {
  allocated_storage    = var.allocated_storage
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  db_name              = var.db_name
  username             = var.username
  password             = var.password
  skip_final_snapshot  = true # Recomendado para desenvolvimento/teste. Para produção, defina como false e configure final_snapshot_identifier.
  publicly_accessible = true  # Cuidado: Torna o DB acessível publicamente. Para produção, considere false e use VPC.

  tags = {
    Name = "${var.db_name}-instance"
  }
}
