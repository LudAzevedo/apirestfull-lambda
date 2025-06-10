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
| `enable_eks_support`        | Se verdadeiro, adiciona tags às sub-redes necessárias para a integração com o Amazon EKS. | `bool`   | `false`        | não         |
| `cluster_name`              | O nome do cluster EKS. Usado nas tags das sub-redes quando `enable_eks_support` é verdadeiro. Ex: 'meu-cluster-eks'. | `string` | `null`         | não (obrigatório se `enable_eks_support` for `true`) |
| `tags`                      | Um mapa de tags a serem aplicadas aos recursos da VPC (VPC, Subnets, IGW, NAT GW, EIP, Route Tables). | `map(string)` | `{ Name = "MainVPC", ... }` | não         |

*Nota: Tags como `Name` são definidas por padrão para os principais recursos dentro do `main.tf`. A variável `tags` pode ser usada para adicionar ou sobrescrever tags. Se `enable_eks_support` for `true`, tags específicas do EKS serão mescladas com as tags existentes nas sub-redes.*

### Suporte a EKS

Quando a variável `enable_eks_support` é definida como `true`, as seguintes tags são adicionadas às sub-redes para permitir que o Amazon EKS as utilize para provisionar recursos de balanceamento de carga (Load Balancers):

-   **Sub-rede Pública:**
    -   `kubernetes.io/role/elb = "1"`: Indica que a sub-rede pode ser usada por Load Balancers externos do Kubernetes.
    -   `kubernetes.io/cluster/${var.cluster_name} = "shared"`: Associa a sub-rede a um cluster EKS específico, permitindo que múltiplos clusters compartilhem a mesma VPC e sub-redes (se configurado corretamente). O `var.cluster_name` deve ser fornecido.

-   **Sub-rede Privada:**
    -   `kubernetes.io/role/internal-elb = "1"`: Indica que a sub-rede pode ser usada por Load Balancers internos do Kubernetes.
    -   `kubernetes.io/cluster/${var.cluster_name} = "shared"`: Similar à sub-rede pública, associa a sub-rede privada ao cluster EKS especificado.

É crucial fornecer um valor para `var.cluster_name` quando `enable_eks_support` é `true` para que as tags de cluster sejam corretamente aplicadas.

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
  # private_subnet_cidr_block = "10.10.2.0/24"
  # availability_zone         = "us-west-2a" # Verifique as AZs disponíveis na sua região

  # Exemplo para habilitar suporte a EKS (requer que cluster_name seja definido)
  # enable_eks_support = true
  # cluster_name       = "meu-cluster-demo"

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
