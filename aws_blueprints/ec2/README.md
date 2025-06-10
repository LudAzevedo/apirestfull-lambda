# Módulo Terraform AWS EC2

## Descrição

Este módulo Terraform provisiona uma instância Amazon EC2 básica na AWS. Ele permite configurar o tipo de instância e a Amazon Machine Image (AMI) a ser utilizada.

## Variáveis de Entrada (Inputs)

| Nome            | Descrição                                                 | Tipo   | Padrão   | Obrigatório |
|-----------------|-----------------------------------------------------------|--------|----------|-------------|
| `instance_type` | O tipo da instância EC2 (ex: t2.micro, m5.large).         | `string` | `t2.micro` | não         |
| `ami`           | O ID da AMI para usar na instância EC2.                   | `string` | N/A      | sim         |
| `tags`          | Um mapa de tags a serem aplicadas à instância EC2.          | `map(string)` | `{ Name = "ExampleInstance" }` | não         |

*Nota: A tag `Name` é definida por padrão como "ExampleInstance" dentro do `main.tf` do módulo, mas pode ser sobrescrita ou complementada pela variável `tags`.*

## Saídas (Outputs)

| Nome        | Descrição                             |
|-------------|---------------------------------------|
| `public_ip` | O endereço IP público da instância EC2. |
| `instance_id` | O ID da instância EC2.                |

## Exemplo de Uso

O exemplo abaixo demonstra como usar este módulo para criar uma instância EC2. O código completo do exemplo pode ser encontrado em `examples/ec2_basic/main.tf`.

```terraform
provider "aws" {
  region = "us-east-1" # Ou sua região de preferência
}

module "ec2_instance" {
  source = "../../" # Ou o caminho para este módulo

  # ID da AMI desejado (exemplo para Ubuntu 20.04 LTS em us-east-1)
  ami = "ami-0c55b31ad1eba91b6"

  instance_type = "t2.micro" # Opcional, o padrão é t2.micro

  tags = {
    Environment = "Development"
    Project     = "MyEC2Project"
  }
}

output "instance_public_ip" {
  description = "IP público da instância EC2 criada."
  value       = module.ec2_instance.public_ip
}

output "instance_id" {
  description = "ID da instância EC2 criada."
  value       = module.ec2_instance.instance_id
}
```

Lembre-se de executar `terraform init` para baixar o módulo e `terraform apply` para provisionar os recursos.
Para encontrar AMIs adequadas, consulte a documentação da AWS ou o console EC2.
