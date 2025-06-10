# Blueprints AWS em Terraform

## Descrição

Esta é uma coleção de blueprints Terraform projetados para provisionar recursos na AWS de forma modular e reutilizável. Cada blueprint foca em um serviço específico da AWS, permitindo que você componha sua infraestrutura de maneira eficiente.

## Estrutura do Projeto

O repositório está organizado da seguinte forma:

```
aws_blueprints/
├── ec2/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── examples/
│       └── ec2_basic/
│           └── main.tf
├── rds/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── examples/
│       └── rds_basic/
│           └── main.tf
├── s3/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── examples/
│       └── s3_basic/
│           └── main.tf
├── vpc/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── examples/
│       └── vpc_basic/
│           └── main.tf
└── README.md
```

- Cada subpasta dentro de `aws_blueprints` (ex: `ec2`, `s3`) representa um módulo Terraform para um serviço específico da AWS.
- Cada módulo contém:
    - `main.tf`: A lógica principal para provisionar os recursos.
    - `variables.tf`: As variáveis de entrada do módulo.
    - `outputs.tf`: Os valores de saída do módulo.
    - `examples/`: Uma ou mais pastas com exemplos de como utilizar o módulo.

## Como Usar

Para utilizar qualquer um dos módulos em seu próprio projeto Terraform:

1.  **Referencie o Módulo**: No seu arquivo `.tf`, adicione um bloco `module` referenciando o caminho para o módulo desejado. Por exemplo, para usar o módulo VPC:

    ```terraform
    provider "aws" {
      region = "us-east-1" # Ou sua região de preferência
    }

    module "my_vpc" {
      source = "./aws_blueprints/vpc" # Ajuste o caminho conforme necessário

      # Forneça as variáveis necessárias para o módulo
      vpc_cidr_block = "10.0.0.0/16"
      # ... outras variáveis
    }
    ```

    Consulte a pasta `examples/` dentro de cada módulo para ver configurações mais detalhadas.

2.  **Inicialize o Terraform**: Navegue até o diretório do seu projeto (onde você referenciou o módulo) e execute:
    ```bash
    terraform init
    ```
    Isso fará o download do módulo e de quaisquer provedores necessários.

3.  **Planeje e Aplique**:
    ```bash
    terraform plan  # Para visualizar as alterações que serão feitas
    terraform apply # Para provisionar os recursos
    ```

## Módulos Disponíveis

Atualmente, os seguintes módulos estão disponíveis:

-   **EC2**: Provisiona instâncias Amazon EC2 básicas.
    -   Permite configurar tipo de instância e AMI.
    -   Outputs: IP público e ID da instância.
-   **S3**: Cria buckets Amazon S3.
    -   Permite configurar o nome do bucket e habilitar/desabilitar versionamento.
    -   Outputs: ID (nome) do bucket e ARN do bucket.
-   **RDS**: Provisiona instâncias de banco de dados Amazon RDS.
    -   Permite configurar armazenamento, tipo de motor, versão, classe da instância, nome do DB, usuário e senha.
    -   Outputs: Endpoint (endereço) e porta da instância.
-   **VPC**: Configura uma Virtual Private Cloud (VPC) com sub-redes públicas e privadas.
    -   Inclui Internet Gateway para a sub-rede pública e NAT Gateway para a sub-rede privada.
    -   Permite configurar blocos CIDR para VPC e sub-redes, e zona de disponibilidade.
    -   Outputs: IDs da VPC, sub-rede pública e sub-rede privada.

## Contribuições

Contribuições são bem-vindas! Se você tiver melhorias, novos módulos ou correções de bugs:

1.  Faça um fork deste repositório.
2.  Crie uma nova branch para sua feature ou correção (`git checkout -b minha-feature`).
3.  Faça commit de suas alterações (`git commit -am 'Adiciona nova feature'`).
4.  Envie para a branch (`git push origin minha-feature`).
5.  Abra um Pull Request.

Por favor, tente manter o estilo e a estrutura existentes ao adicionar novos módulos. Adicionar um exemplo de uso para cada novo módulo também é altamente recomendado.
