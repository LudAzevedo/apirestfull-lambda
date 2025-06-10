# Módulo Terraform AWS RDS

## Descrição

Este módulo Terraform provisiona uma instância de banco de dados Amazon RDS básica na AWS. Ele permite configurar diversos aspectos da instância, como motor, classe, armazenamento e credenciais.

**Atenção:** A configuração padrão deste módulo (`skip_final_snapshot = true` e `publicly_accessible = true`) é destinada a ambientes de desenvolvimento/teste e **não é recomendada para produção**. Para produção, ajuste essas configurações conforme necessário (ex: `skip_final_snapshot = false`, `final_snapshot_identifier = "meu-db-snapshot-final"`, `publicly_accessible = false` e configure o acesso via VPC e grupos de segurança).

## Variáveis de Entrada (Inputs)

| Nome                | Descrição                                                                 | Tipo   | Padrão        | Obrigatório |
|---------------------|---------------------------------------------------------------------------|--------|---------------|-------------|
| `allocated_storage` | A quantidade de armazenamento alocado para a instância de banco de dados (em GB). | `number` | `20`          | não         |
| `engine`            | O motor do banco de dados a ser usado (ex: mysql, postgres).                | `string` | `"mysql"`     | não         |
| `engine_version`    | A versão do motor do banco de dados.                                       | `string` | `"8.0"`       | não         |
| `instance_class`    | A classe da instância de banco de dados (ex: db.t2.micro, db.m5.large).      | `string` | `"db.t2.micro"` | não         |
| `db_name`           | O nome do banco de dados a ser criado na instância.                         | `string` | N/A           | sim         |
| `username`          | O nome de usuário para a conta mestre do banco de dados.                    | `string` | N/A           | sim         |
| `password`          | A senha para a conta mestre do banco de dados. **Tratada como sensível.**     | `string` | N/A           | sim         |
| `publicly_accessible`| Define se a instância de DB deve ser acessível publicamente.               | `bool`   | `true`        | não         |
| `skip_final_snapshot`| Define se um snapshot final deve ser ignorado ao deletar a instância.    | `bool`   | `true`        | não         |
| `tags`              | Um mapa de tags a serem aplicadas à instância RDS.                           | `map(string)` | `{ Name = "${var.db_name}-instance" }` | não         |

*Nota: A tag `Name` é definida por padrão com base no `var.db_name` dentro do `main.tf` do módulo, mas pode ser sobrescrita ou complementada pela variável `tags`.*

## Saídas (Outputs)

| Nome                  | Descrição                                           |
|-----------------------|-----------------------------------------------------|
| `db_instance_address` | O endpoint (endereço) da instância de banco de dados RDS. |
| `db_instance_port`    | A porta da instância de banco de dados RDS.         |

## Exemplo de Uso

O exemplo abaixo demonstra como usar este módulo para criar uma instância RDS MySQL. O código completo do exemplo pode ser encontrado em `examples/rds_basic/main.tf`.

```terraform
provider "aws" {
  region = "us-east-1" # Ou sua região de preferência
}

module "rds_instance" {
  source = "../../" # Ou o caminho para este módulo

  # Variáveis obrigatórias
  db_name  = "minhaaplicacaodb"
  username = "adminuser"
  password = "UmaSenhaMuitoForte!" # Use um gerenciador de senhas ou segredos em produção

  # Variáveis opcionais (usarão os padrões do módulo se não especificadas)
  # allocated_storage = 30
  # engine            = "postgres"
  # engine_version    = "13.4"
  # instance_class    = "db.t3.small"
  # publicly_accessible = false # Recomendado para produção

  tags = {
    Environment = "Development"
    Application = "MyApp"
  }
}

output "rds_instance_address" {
  description = "Endpoint da instância RDS criada."
  value       = module.rds_instance.db_instance_address
}

output "rds_instance_port" {
  description = "Porta da instância RDS criada."
  value       = module.rds_instance.db_instance_port
}
```

Lembre-se de executar `terraform init` para baixar o módulo e `terraform apply` para provisionar os recursos.
**Importante:** Gerencie senhas de forma segura, utilizando variáveis de ambiente, arquivos de variáveis não versionados ou serviços de gerenciamento de segredos como AWS Secrets Manager em ambientes de produção.
