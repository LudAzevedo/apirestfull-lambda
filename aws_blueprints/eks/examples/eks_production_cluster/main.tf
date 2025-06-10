# Arquivo main.tf para o exemplo de cluster EKS de produção.
# Este exemplo demonstra como usar os módulos vpc e eks para criar um cluster EKS completo.

# ------------------------------------------------------------------------------
# Configuração do Provedor AWS
# ------------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
}

# Obtém a conta AWS atual para construir ARNs dinamicamente.
data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# Módulo VPC: Criação da Rede para o Cluster EKS
# ------------------------------------------------------------------------------
module "vpc_eks" {
  source = "../../../vpc" # Caminho relativo para o módulo VPC

  vpc_cidr_block            = "10.0.0.0/16"
  public_subnet_cidr_block  = "10.0.1.0/24"  # Sub-rede pública para NAT Gateways, Bastion Hosts, etc.
  private_subnet_cidr_block = "10.0.2.0/24" # Sub-rede privada para os nós do EKS e control plane.
  availability_zone         = "${var.aws_region}a" # Exemplo, para produção real, use múltiplas AZs.

  # Habilita as tags necessárias nas sub-redes para o EKS e o AWS Load Balancer Controller.
  enable_eks_support = true
  cluster_name       = var.cluster_name_prefix # Nome do cluster que será usado nas tags das sub-redes.

  tags = {
    TerraformExample = "eks_production_cluster"
    VPCOwner         = "EquipeEKS"
  }
}

# ------------------------------------------------------------------------------
# Módulo EKS: Criação do Cluster Kubernetes
# ------------------------------------------------------------------------------
module "eks_cluster_prod" {
  source = "../../" # Caminho relativo para o módulo EKS raiz (aws_blueprints/eks)

  # --- Configurações Gerais do Cluster ---
  cluster_name    = var.cluster_name_prefix
  cluster_version = "1.29" # Verifique a versão mais recente suportada e recomendada.

  # --- Rede e Load Balancing ---
  vpc_id     = module.vpc_eks.vpc_id
  # Para produção, é recomendado usar sub-redes privadas para o control plane e nós.
  # O módulo VPC já cria sub-redes privadas e públicas. Aqui usamos as privadas.
  # Se o módulo VPC for configurado para múltiplas AZs, certifique-se de passar todas as subnet_ids relevantes.
  subnet_ids = [module.vpc_eks.private_subnet_id] # Idealmente, seriam múltiplas sub-redes privadas em diferentes AZs.
                                                 # Ex: [module.vpc_eks.private_subnet_az1_id, module.vpc_eks.private_subnet_az2_id]

  endpoint_private_access = true  # Recomendado para produção.
  endpoint_public_access  = false # Desabilitar acesso público se não for estritamente necessário.

  # --- Grupos de Nós Gerenciados ---
  node_groups = {
    geral_apps = {
      name           = "geral-apps-pool"
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      disk_size      = 30
      labels = {
        "workload" = "general-purpose"
        "env"      = "production"
      }
    },
    worker_intensivo = {
      name           = "worker-intensivo-pool"
      instance_types = ["m5.large"]
      desired_size   = 1
      min_size       = 1
      max_size       = 5 # Permite escalar até 5 nós.
      disk_size      = 50
      labels = {
        "workload" = "compute-intensive"
        "env"      = "production"
      }
      taints = [
        { key = "workload", value = "intensive", effect = "NO_SCHEDULE" }
      ]
    }
  }

  # --- AWS Load Balancer Controller ---
  enable_aws_load_balancer_controller = true
  # aws_load_balancer_controller_helm_chart_version = "1.8.0" # Verifique e use a versão estável mais recente.

  # --- Nginx Ingress Controller ---
  enable_nginx_ingress_controller = true
  nginx_ingress_replica_count   = 2 # Mínimo de 2 para HA.
  # nginx_ingress_helm_chart_version = "4.10.1" # Verifique e use a versão estável mais recente.

  # --- Fluent Bit (Logging de Containers) ---
  enable_container_logs_to_cloudwatch = true
  # fluent_bit_cloudwatch_log_group_name = "/aws/eks/meu-eks-prod/containers" # Opcional, o módulo gera um padrão.
  fluent_bit_namespace = "amazon-cloudwatch" # Namespace padrão para Fluent Bit.

  # --- Segurança e Acesso (aws-auth) ---
  manage_aws_auth_configmap = true # Permite que o Terraform gerencie o aws-auth ConfigMap.

  # Mapeia uma role IAM administrativa para o grupo system:masters no Kubernetes.
  # IMPORTANTE: Substitua 'var.eks_admin_role_arn' pelo ARN real da sua role IAM administrativa.
  # Se var.eks_admin_role_arn for uma string vazia, este mapeamento será ignorado.
  map_additional_iam_roles_to_rbac = compact([
    var.eks_admin_role_arn != "" ? {
      rolearn  = var.eks_admin_role_arn
      username = "iam-admin-${replace(var.eks_admin_role_arn, "/^.*:role\\/(.*)$/", "$1")}" # Gera um username a partir do nome da role
      groups   = ["system:masters"]
    } : null
  ])
  # Exemplo de como adicionar um usuário IAM (descomente e ajuste se necessário):
  # map_additional_iam_users_to_rbac = [
  #   {
  #     userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/MeuUsuarioEKS"
  #     username = "meu-usuario-eks"
  #     groups   = ["system:viewers"] # Conceder permissões de visualização, por exemplo.
  #   }
  # ]

  tags = {
    TerraformExample = "eks_production_cluster"
    ClusterOwner     = "EquipeSRE"
  }

  # Depende da criação completa da VPC, incluindo gateways e tabelas de rota.
  depends_on = [module.vpc_eks]
}

# ------------------------------------------------------------------------------
# Saídas (Outputs) do Exemplo
# Informações úteis após a criação dos recursos.
# ------------------------------------------------------------------------------

output "eks_cluster_endpoint" {
  description = "Endpoint do servidor da API do cluster EKS. Use para configurar o kubectl."
  value       = module.eks_cluster_prod.cluster_endpoint
}

output "eks_cluster_name_output" {
  description = "Nome do cluster EKS criado."
  value       = module.eks_cluster_prod.cluster_id
}

output "configure_kubectl_command" {
  description = "Comando para configurar o kubectl para acessar o cluster EKS criado."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster_prod.cluster_id}"
}

output "nginx_ingress_load_balancer_hostname" {
  description = "Hostname do Network Load Balancer (NLB) para o Nginx Ingress Controller. Pode levar alguns minutos para estar disponível."
  value       = module.eks_cluster_prod.nginx_ingress_controller_load_balancer_hostname
}

output "cloudwatch_log_group_for_container_logs" {
  description = "Nome do grupo de logs no CloudWatch para onde os logs dos contêineres são enviados pelo Fluent Bit."
  value       = module.eks_cluster_prod.fluent_bit_cloudwatch_log_group
}

output "eks_admin_role_mapped" {
  description = "ARN da role IAM administrativa que foi mapeada no aws-auth (se fornecida)."
  value       = var.eks_admin_role_arn != "" ? var.eks_admin_role_arn : "Nenhuma role administrativa adicional foi mapeada via variável."
}

output "vpc_id_created" {
  description = "ID da VPC criada para o cluster EKS."
  value       = module.vpc_eks.vpc_id
}

output "vpc_public_subnet_id_created" {
  description = "ID da sub-rede pública criada na VPC."
  value       = module.vpc_eks.public_subnet_id # Assumindo que o módulo VPC retorna IDs de sub-redes individuais
}

output "vpc_private_subnet_id_created" {
  description = "ID da sub-rede privada criada na VPC."
  value       = module.vpc_eks.private_subnet_id
}
