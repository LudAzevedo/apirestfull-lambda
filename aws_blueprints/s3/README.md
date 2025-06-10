# Módulo Terraform AWS S3

## Descrição

Este módulo Terraform provisiona um bucket Amazon S3 básico na AWS. Ele permite configurar o nome do bucket e habilitar o versionamento. Por padrão, o bucket é criado com ACL (Access Control List) privada.

## Variáveis de Entrada (Inputs)

| Nome                | Descrição                                                      | Tipo   | Padrão | Obrigatório |
|---------------------|----------------------------------------------------------------|--------|--------|-------------|
| `bucket_name`       | O nome do bucket S3. Deve ser globalmente único.               | `string` | N/A    | sim         |
| `enable_versioning` | Define se o versionamento deve ser habilitado para o bucket S3. | `bool`   | `false`  | não         |
| `tags`              | Um mapa de tags a serem aplicadas ao bucket S3.                 | `map(string)` | `{ Name = var.bucket_name }` | não         |

*Nota: A tag `Name` é definida por padrão com o valor da variável `bucket_name` dentro do `main.tf` do módulo, mas pode ser sobrescrita ou complementada pela variável `tags`.*

## Saídas (Outputs)

| Nome         | Descrição                        |
|--------------|----------------------------------|
| `bucket_id`  | O ID (nome) do bucket S3.        |
| `bucket_arn` | O ARN (Amazon Resource Name) do bucket S3. |

## Exemplo de Uso

O exemplo abaixo demonstra como usar este módulo para criar um bucket S3. O código completo do exemplo pode ser encontrado em `examples/s3_basic/main.tf`.

```terraform
provider "aws" {
  region = "us-east-1" # Ou sua região de preferência
}

module "s3_bucket" {
  source = "../../" # Ou o caminho para este módulo

  # Nome do bucket (deve ser globalmente único)
  bucket_name = "meu-bucket-unico-exemplo-12345"

  # Opcional: Habilitar versionamento
  # enable_versioning = true

  tags = {
    Environment = "Storage"
    Project     = "MyDataLake"
  }
}

output "s3_bucket_id" {
  description = "ID (nome) do bucket S3 criado."
  value       = module.s3_bucket.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN do bucket S3 criado."
  value       = module.s3_bucket.bucket_arn
}
```

Lembre-se de executar `terraform init` para baixar o módulo e `terraform apply` para provisionar os recursos.
Os nomes de bucket S3 devem ser globalmente únicos em toda a AWS.
