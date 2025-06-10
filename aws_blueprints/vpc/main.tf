# Define o provedor AWS
provider "aws" {
  region = "us-east-1" # Exemplo de região, pode ser alterado conforme necessário
}

# ------------------------------------------------------------------------------
# VPC (Virtual Private Cloud)
# ------------------------------------------------------------------------------
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MainVPC"
  }
}

# ------------------------------------------------------------------------------
# Sub-rede Pública
# ------------------------------------------------------------------------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_cidr_block
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true # Instâncias nesta sub-rede receberão IP público

  tags = merge(
    {
      Name = "PublicSubnet"
    },
    # Tags condicionais para suporte EKS
    # Estas tags permitem que o Kubernetes descubra automaticamente estas sub-redes para LoadBalancers (ELB/NLB).
    var.enable_eks_support ? {
      "kubernetes.io/role/elb" = "1" # Usado por LoadBalancers externos
      "kubernetes.io/cluster/${var.cluster_name}" = "shared" # Associa a sub-rede a um cluster específico
    } : {}
  )
}

# ------------------------------------------------------------------------------
# Sub-rede Privada
# ------------------------------------------------------------------------------
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.private_subnet_cidr_block
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false # Instâncias nesta sub-rede NÃO receberão IP público

  tags = merge(
    {
      Name = "PrivateSubnet"
    },
    # Tags condicionais para suporte EKS
    # Estas tags permitem que o Kubernetes descubra automaticamente estas sub-redes para LoadBalancers internos.
    var.enable_eks_support ? {
      "kubernetes.io/role/internal-elb" = "1" # Usado por LoadBalancers internos
      "kubernetes.io/cluster/${var.cluster_name}" = "shared" # Associa a sub-rede a um cluster específico
    } : {}
  )
}

# ------------------------------------------------------------------------------
# Internet Gateway (para a sub-rede pública)
# ------------------------------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "MainIGW"
  }
}

# ------------------------------------------------------------------------------
# Tabela de Rotas para a Sub-rede Pública
# ------------------------------------------------------------------------------
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Rota para todo tráfego de saída
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associação da Tabela de Rotas com a Sub-rede Pública
resource "aws_route_table_association" "public_subnet_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# ------------------------------------------------------------------------------
# Elastic IP (EIP) para o NAT Gateway
# ------------------------------------------------------------------------------
resource "aws_eip" "nat_eip" {
  vpc = true # Especifica que o EIP é para uso na VPC (dependência implícita)
  # Opcional: use depends_on para garantir que o IGW seja criado antes do EIP,
  # embora o Terraform geralmente lide bem com isso.
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "NatEIP"
  }
}

# ------------------------------------------------------------------------------
# NAT Gateway (para a sub-rede privada)
# ------------------------------------------------------------------------------
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id # NAT Gateway reside na sub-rede pública

  tags = {
    Name = "MainNATGateway"
  }

  # Garante que o Internet Gateway esteja disponível antes de criar o NAT Gateway
  depends_on = [aws_internet_gateway.igw]
}

# ------------------------------------------------------------------------------
# Tabela de Rotas para a Sub-rede Privada (usando o NAT Gateway)
# ------------------------------------------------------------------------------
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0" # Rota para todo tráfego de saída
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "PrivateRouteTable"
  }
}

# Associação da Tabela de Rotas com a Sub-rede Privada
resource "aws_route_table_association" "private_subnet_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}
