# ------------------------------------------------------------------------------
# IAM Role para o Control Plane do EKS (Plano de Controle)
# Esta role é assumida pelo serviço EKS para gerenciar recursos AWS em nome do seu cluster.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "eks_cluster_role" {
  # Nome da role IAM. Inclui o nome do cluster para garantir unicidade.
  name = "${var.cluster_name}-EKSClusterRole"

  # Política de confiança (Assume Role Policy).
  # Permite que o serviço EKS (eks.amazonaws.com) assuma esta role.
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "eks.amazonaws.com" # Principal de serviço para EKS.
        },
        Action    = "sts:AssumeRole" # Ação para assumir a role.
      }
    ]
  })

  # Tags aplicadas à role IAM.
  tags = merge(
    var.tags, # Mescla com tags globais definidas pelo usuário.
    {
      Name = "${var.cluster_name}-EKSClusterRole" # Tag 'Name' específica para esta role.
    }
  )
}

# Anexa a política gerenciada pela AWS 'AmazonEKSClusterPolicy' à role do cluster.
# Esta política concede as permissões básicas necessárias para o EKS operar o cluster.
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" # ARN da política gerenciada.
  role       = aws_iam_role.eks_cluster_role.name               # Nome da role à qual anexar.
}

# Opcional: Anexa a política gerenciada pela AWS 'AmazonEKSServicePolicy'.
# Esta política concede permissões adicionais, geralmente necessárias se você gerencia
# o cluster através do console da AWS ou se outros serviços AWS precisam interagir
# com o EKS de forma mais ampla. Para a criação e operação básica do cluster via Terraform,
# a 'AmazonEKSClusterPolicy' é a principal. Descomente se necessário.
/*
resource "aws_iam_role_policy_attachment" "eks_service_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
*/

# ------------------------------------------------------------------------------
# Considerações Adicionais de IAM (a serem tratadas separadamente, se necessário):
# - IAM Roles para Service Accounts (IRSA): Para permitir que pods assumam roles IAM específicas.
#   Exemplos disso são as roles para o AWS LBC e Fluent Bit neste módulo.
# - Políticas para Fargate Profiles: Se estiver usando EKS com AWS Fargate, perfis Fargate
#   precisarão de suas próprias IAM roles com permissões específicas.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# IAM Role para os Node Groups do EKS (Nós de Trabalho / Data Plane)
# Esta role é assumida pelas instâncias EC2 que compõem os nós de trabalho do cluster.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "eks_node_group_role" {
  # Nome da role IAM para os nós. Inclui o nome do cluster para unicidade.
  name = "${var.cluster_name}-EKSNodeGroupRole"

  # Política de confiança.
  # Permite que instâncias EC2 (ec2.amazonaws.com) assumam esta role.
  # Necessário para que as instâncias dos nós possam se registrar no cluster EKS.
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com" # Principal de serviço para EC2.
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  # Tags aplicadas à role IAM dos nós.
  tags = merge(
    var.tags, # Mescla com tags globais.
    {
      Name = "${var.cluster_name}-EKSNodeGroupRole" # Tag 'Name' específica.
    }
  )
}

# Anexa a política gerenciada pela AWS 'AmazonEKSWorkerNodePolicy'.
# Concede as permissões mínimas necessárias para que um nó EC2 se junte e opere em um cluster EKS.
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

# Anexa a política gerenciada pela AWS 'AmazonEC2ContainerRegistryReadOnly'.
# Concede permissões para que os nós possam puxar (download) imagens de contêineres do Amazon ECR (Elastic Container Registry).
resource "aws_iam_role_policy_attachment" "eks_ecr_read_only_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# Anexa a política gerenciada pela AWS 'AmazonEKS_CNI_Policy'.
# Concede as permissões necessárias para o plugin CNI (Container Network Interface) da AWS,
# que é responsável pela configuração de rede dos pods no cluster.
resource "aws_iam_role_policy_attachment" "eks_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

# ------------------------------------------------------------------------------
# IAM para o AWS Load Balancer Controller (LBC)
# Configura uma IAM Role e Política para a Service Account do LBC, permitindo que ele gerencie ALBs e NLBs.
# Utiliza IRSA (IAM Roles for Service Accounts).
# ------------------------------------------------------------------------------

# Define o documento da política IAM para o AWS Load Balancer Controller.
# Esta política é baseada nas recomendações da AWS e concede as permissões necessárias.
# Link para documentação oficial: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
# É uma boa prática verificar periodicamente o link acima para a versão mais recente da política.
data "aws_iam_policy_document" "aws_lbc_iam_policy_document" {
  # Permissão para criar a Service Linked Role para o Elastic Load Balancing, se ainda não existir.
  statement {
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"] # A criação de SLR é uma ação ampla, mas condicionada.
    effect    = "Allow"
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"] # Condiciona à criação para o serviço ELB.
    }
  }
  # Permissões de leitura para diversos serviços EC2 e ELB.
  statement {
    actions = [
      "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses", "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways", "ec2:DescribeVpcs", "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces", "ec2:DescribeTags", "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools", # Adicionado para cobrir variações de políticas.
      "elasticloadbalancing:DescribeLoadBalancers", "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners", "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies", "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth", "elasticloadbalancing:DescribeTags"
    ]
    resources = ["*"] # Ações de descrição geralmente são seguras com "*".
    effect    = "Allow"
  }
  # Permissões para interagir com outros serviços como ACM, WAF, Shield.
  statement {
    actions = [
      "cognito-idp:DescribeUserPoolClient", "acm:ListCertificates", "acm:DescribeCertificate",
      "iam:ListServerCertificates", "iam:GetServerCertificate",
      "waf-regional:GetWebACLForResource", "waf-regional:GetWebACL", "waf-regional:AssociateWebACL", "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL", "wafv2:GetWebACLForResource", "wafv2:AssociateWebACL", "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState", "shield:DescribeProtection", "shield:CreateProtection", "shield:DeleteProtection",
      "shield:DescribeSubscription", "shield:ListProtections"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
  # Permissões para gerenciar Security Groups.
  statement {
    actions   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:CreateSecurityGroup"]
    resources = ["*"] # Idealmente, poderia ser mais restrito se o SG da VPC fosse conhecido e referenciado.
    effect    = "Allow"
  }
  # Permissão para criar interfaces de rede (ENIs), condicionada por tags.
  statement {
    actions   = ["ec2:CreateNetworkInterface"]
    resources = ["arn:aws:ec2:*:*:network-interface/*"] # Permite em qualquer ENI, mas a criação é condicionada.
    effect    = "Allow"
    condition { # Condiciona a criação de ENI à presença da tag de cluster específica do LBC.
      test     = "StringEquals"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = [var.cluster_name]
    }
    condition { # Garante que a ação é de fato CreateNetworkInterface.
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateNetworkInterface"]
    }
  }
  # Permissão para deletar interfaces de rede, condicionada por tags.
  statement {
    actions   = ["ec2:DeleteNetworkInterface"]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]
    effect    = "Allow"
    condition { # Condiciona a deleção de ENI à presença da tag de cluster do LBC no recurso.
      test     = "StringEquals"
      variable = "ec2:ResourceTag/elbv2.k8s.aws/cluster"
      values   = [var.cluster_name]
    }
  }
  # Permissões para criar e deletar tags em ENIs, condicionadas.
  statement {
    actions   = ["ec2:CreateTags", "ec2:DeleteTags"]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]
    effect    = "Allow"
    condition { # Permite se a tag de cluster já existir no recurso.
      test     = "StringEqualsIfExists"
      variable = "ec2:ResourceTag/elbv2.k8s.aws/cluster"
      values   = [var.cluster_name]
    }
    condition { # Ou se a tag de cluster estiver sendo adicionada/removida na própria requisição.
      test     = "StringEquals"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = [var.cluster_name]
    }
  }
  # Permissão para modificar atributos de ENIs.
  statement {
    actions   = ["ec2:ModifyNetworkInterfaceAttribute"]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]
    effect    = "Allow"
  }
  # Permissões para diversas ações de gerenciamento de Load Balancers (ALB/NLB).
  statement {
    actions = [
      "elasticloadbalancing:SetIpAddressType", "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets", "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener", "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:CreateRule", "elasticloadbalancing:DeleteRule", "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"
    ]
    resources = ["*"] # Ações de ELB são geralmente amplas; algumas podem ser restringidas por tags se suportado.
    effect    = "Allow"
  }
  # Permissão para criar Load Balancers, condicionada pela tag de cluster na requisição.
  statement {
    actions   = ["elasticloadbalancing:CreateLoadBalancer"]
    resources = ["*"]
    effect    = "Allow"
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = [var.cluster_name]
    }
  }
  # Permissão para deletar Load Balancers, condicionada pela tag de cluster no recurso.
  statement {
    actions   = ["elasticloadbalancing:DeleteLoadBalancer"]
    resources = ["*"]
    effect    = "Allow"
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = [var.cluster_name]
    }
  }
}

# Cria a política IAM para o AWS Load Balancer Controller a partir do documento definido acima.
resource "aws_iam_policy" "aws_lbc_iam_policy" {
  name        = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "Política IAM para o AWS Load Balancer Controller do cluster EKS ${var.cluster_name}."
  policy      = data.aws_iam_policy_document.aws_lbc_iam_policy_document.json # Conteúdo da política em formato JSON.

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
    }
  )
}

# Role IAM para a Service Account (SA) do AWS Load Balancer Controller.
# Esta role será assumida pela SA do LBC no Kubernetes, usando o provedor OIDC do cluster EKS.
resource "aws_iam_role" "aws_lbc_sa_role" {
  name = "${var.cluster_name}-AWSLBCServiceAccountRole"

  # Política de confiança para IRSA.
  # Permite que a SA do Kubernetes especificada assuma esta role através do OIDC.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          # ARN do provedor OIDC do cluster EKS.
          Federated = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
        }
        Action = "sts:AssumeRoleWithWebIdentity" # Ação para assumir role com identidade web.
        Condition = {
          StringEquals = {
            # Condiciona a assunção da role à SA específica.
            # O formato é: OIDC_PROVIDER_URL_SEM_HTTPS:sub = system:serviceaccount:NAMESPACE:SERVICE_ACCOUNT_NAME
            "${replace(aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller-sa"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-AWSLBCServiceAccountRole"
    }
  )
}

# Anexa a política IAM do LBC à role da Service Account do LBC.
resource "aws_iam_role_policy_attachment" "aws_lbc_sa_policy_attachment" {
  policy_arn = aws_iam_policy.aws_lbc_iam_policy.arn
  role       = aws_iam_role.aws_lbc_sa_role.name
}

# ------------------------------------------------------------------------------
# IAM para Fluent Bit (Encaminhamento de Logs de Container para CloudWatch)
# Configura uma IAM Role e Política para a Service Account do Fluent Bit.
# Utiliza IRSA.
# ------------------------------------------------------------------------------

# Define o documento da política IAM para o Fluent Bit.
# Concede permissões para criar e escrever em Log Groups e Log Streams no CloudWatch.
data "aws_iam_policy_document" "fluent_bit_iam_policy_document" {
  statement {
    actions = [
      "logs:CreateLogStream",    # Permite criar novos streams de log.
      "logs:CreateLogGroup",     # Permite criar novos grupos de log (se `auto_create_group` for true no Fluent Bit).
      "logs:DescribeLogStreams", # Permite descrever streams de log.
      "logs:PutLogEvents"        # Permite enviar eventos de log para o CloudWatch.
    ]
    # Recurso: ARN do grupo de logs. Permite acesso ao grupo padrão e a um grupo customizado, se definido.
    # A primeira entrada é para o grupo de logs padrão que o Fluent Bit pode tentar criar.
    # A segunda entrada é para o grupo de logs efetivamente usado (padrão ou customizado).
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/eks/${var.cluster_name}/containers:*", # Permissão para o grupo de logs padrão.
      "arn:aws:logs:*:*:log-group:${coalesce(var.fluent_bit_cloudwatch_log_group_name, "/aws/eks/${var.cluster_name}/containers")}:*" # Permissão para o grupo de logs configurado.
    ]
    effect    = "Allow"
  }
}

# Cria a política IAM para o Fluent Bit a partir do documento.
resource "aws_iam_policy" "fluent_bit_iam_policy" {
  name        = "${var.cluster_name}-FluentBitIAMPolicy"
  description = "Política IAM para o Fluent Bit no cluster EKS ${var.cluster_name} para enviar logs de contêineres ao CloudWatch."
  policy      = data.aws_iam_policy_document.fluent_bit_iam_policy_document.json

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-FluentBitIAMPolicy"
    }
  )
}

# Role IAM para a Service Account (SA) do Fluent Bit.
# Assumida pela SA do Fluent Bit no Kubernetes via OIDC.
resource "aws_iam_role" "fluent_bit_sa_role" {
  name = "${var.cluster_name}-FluentBitServiceAccountRole"

  # Política de confiança para IRSA.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # Condiciona à SA específica do Fluent Bit.
            "${replace(aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.fluent_bit_namespace}:fluent-bit-sa"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-FluentBitServiceAccountRole"
    }
  )
}

# Anexa a política IAM do Fluent Bit à role da Service Account do Fluent Bit.
resource "aws_iam_role_policy_attachment" "fluent_bit_sa_policy_attachment" {
  policy_arn = aws_iam_policy.fluent_bit_iam_policy.arn
  role       = aws_iam_role.fluent_bit_sa_role.name
}
