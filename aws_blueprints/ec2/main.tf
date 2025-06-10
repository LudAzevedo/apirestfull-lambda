# Define o provedor AWS
provider "aws" {
  region = "us-east-1" # Exemplo de região, pode ser alterado conforme necessário
}

# Define o recurso da instância EC2
resource "aws_instance" "example_instance" {
  ami           = var.ami
  instance_type = var.instance_type

  tags = {
    Name = "ExampleInstance"
  }
}
