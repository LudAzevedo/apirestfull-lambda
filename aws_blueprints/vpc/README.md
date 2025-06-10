# Módulo Terraform AWS VPC

## Descrição

Este módulo Terraform provisiona uma Virtual Private Cloud (VPC) na AWS. Ele cria uma VPC com uma sub-rede pública e uma sub-rede privada. A sub-rede pública é configurada com um Internet Gateway para acesso direto à internet, enquanto a sub-rede privada utiliza um NAT Gateway (com um Elastic IP associado) para acesso de saída à internet, mantendo as instâncias privadas não diretamente acessíveis de fora.

Este módulo configura:
- Uma VPC (`aws_vpc`).
- Uma sub-rede pública (`aws_subnet`) com `map_public_ip_on_launch = true`.
- Uma sub-rede privada (`aws_subnet`) com `map_public_ip_on_launch = false`.
- Um Internet Gateway (`aws_internet_gateway`) anexado à VPC.
- Uma Tabela de Rotas para a sub-rede pública, direcionando o tráfego `0.0.0.0/0` para o Internet Gateway.
- Um Elastic IP (`aws_eip`) para o NAT Gateway.
- Um NAT Gateway (`aws_nat_gateway`) localizado na sub-rede pública.
- Uma Tabela de Rotas para a sub-rede privada, direcionando o tráfego `0.0.0.0/0` para o NAT Gateway.

## Variáveis de Entrada (Inputs)

| Nome                        | Descrição                                                                 | Tipo   | Padrão         | Obrigatório |
|-----------------------------|---------------------------------------------------------------------------|--------|----------------|-------------|
| `vpc_cidr_block`            | O bloco CIDR para a VPC.                                                  | `string` | `"10.0.0.0/16"`  | não         |
| `public_subnet_cidr_block`  | O bloco CIDR para a sub-rede pública.                                     | `string` | `"10.0.1.0/24"`  | não         |
| `private_subnet_cidr_block` | O bloco CIDR para a sub-rede privada.                                     | `string` | `"10.0.2.0/24"`  | não         |
| `availability_zone`         | A zona de disponibilidade para as sub-redes (ex: us-east-1a, us-west-2b). | `string` | `"us-east-1a"` | não         |
| `tags`                      | Um mapa de tags a serem aplicadas aos recursos da VPC (VPC, Subnets, IGW, NAT GW, EIP, Route Tables). | `map(string)` | `{ Name = "MainVPC", ... }` | não         |

*Nota: Tags como `Name` são definidas por padrão para os principais recursos dentro do `main.tf`. A variável `tags` pode ser usada para adicionar ou sobrescrever tags globalmente nos recursos que a suportam dentro deste módulo, embora o comportamento específico possa variar por recurso.*

## Saídas (Outputs)

| Nome                    | Descrição                                               |
|-------------------------|---------------------------------------------------------|
| `vpc_id`                | O ID da VPC criada.                                     |
| `public_subnet_id`      | O ID da sub-rede pública criada.                        |
| `private_subnet_id`     | O ID da sub-rede privada criada.                       |
| `nat_gateway_id`        | O ID do NAT Gateway criado.                             |
| `nat_gateway_public_ip` | O endereço IP público (EIP) associado ao NAT Gateway. |

## Exemplo de Uso

O exemplo abaixo demonstra como usar este módulo para criar uma VPC com sub-redes pública e privada. O código completo do exemplo pode ser encontrado em `examples/vpc_basic/main.tf`.

```terraform
provider "aws" {
  region = "us-east-1" # Ou sua região de preferência
}

module "vpc_environment" {
  source = "../../" # Ou o caminho para este módulo

  # Opcional: Personalize os blocos CIDR e a zona de disponibilidade
  # vpc_cidr_block            = "192.168.0.0/16"
  # public_subnet_cidr_block  = "192.168.1.0/24"
  # private_subnet_cidr_block = "192.168.2.0/24"
  # availability_zone         = "us-west-2a" # Verifique as AZs disponíveis na sua região

  tags = {
    Environment = "Production"
    Project     = "CoreNetworking"
  }
}

output "created_vpc_id" {
  description = "ID da VPC criada."
  value       = module.vpc_environment.vpc_id
}

output "created_public_subnet_id" {
  description = "ID da sub-rede pública."
  value       = module.vpc_environment.public_subnet_id
}

output "created_private_subnet_id" {
  description = "ID da sub-rede privada."
  value       = module.vpc_environment.private_subnet_id
}

output "nat_gw_public_ip" {
  description = "IP público do NAT Gateway."
  value       = module.vpc_environment.nat_gateway_public_ip
}
```

Lembre-se de executar `terraform init` para baixar o módulo e `terraform apply` para provisionar os recursos.
Este módulo cria recursos que podem incorrer em custos na AWS (ex: NAT Gateway, EIP).
Considere as implicações de `availability_zone` para resiliência e custos. Para alta disponibilidade, você pode precisar instanciar este módulo ou partes dele em múltiplas AZs.
