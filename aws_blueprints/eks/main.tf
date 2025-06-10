# Define o provedor AWS (se não estiver definido em um nível superior ou em um arquivo provider.tf)
# provider "aws" {
#   region = var.aws_region # Idealmente, defina a região através de uma variável ou configuração do provedor
# }

# Obtém a região AWS atual onde os recursos do Terraform estão sendo provisionados.
# Utilizado para configurar componentes como o AWS LBC e Fluent Bit com a região correta.
data "aws_region" "current" {}

# Obtém a identidade do chamador AWS (conta, usuário, role ARN).
# Pode ser útil para construir ARNs dinamicamente ou para verificações de identidade.
data "aws_caller_identity" "current" {}

# Bloco de configuração do Terraform para definir provedores necessários e suas versões.
# Isso garante que o Terraform use as versões corretas dos provedores para este módulo.
terraform {
  required_providers {
    # Provedor AWS para interagir com serviços da Amazon Web Services.
    aws = {
      source  = "hashicorp/aws"
      # version = "~> 5.0" # Exemplo: Descomente e ajuste para fixar uma versão específica do provedor AWS.
    }
    # Provedor Helm para gerenciar charts Helm no Kubernetes.
    helm = {
      source  = "hashicorp/helm"
      # version = "~> 2.0" # Exemplo: Descomente e ajuste para fixar uma versão específica do provedor Helm.
    }
    # Provedor Kubernetes para interagir com a API do Kubernetes.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      # version = "~> 2.0" # Exemplo: Descomente e ajuste para fixar uma versão específica do provedor Kubernetes.
    }
    # Provedor kubectl para aplicar manifestos YAML diretamente, usado para o Fluent Bit.
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14" # Requer versão 1.14 ou superior.
    }
  }
}

# ------------------------------------------------------------------------------
# Configuração dos Provedores Kubernetes e Helm
# Estes provedores são configurados para interagir com o cluster EKS recém-criado.
# ------------------------------------------------------------------------------

# Configura o provedor Kubernetes para interagir com o cluster EKS.
# Utiliza o endpoint do cluster, o certificado da autoridade de certificação (CA)
# e um token de autenticação obtido via AWS CLI.
provider "kubernetes" {
  host                   = aws_eks_cluster.main_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main_cluster.certificate_authority[0].data)

  # Bloco 'exec' para obter dinamicamente o token de autenticação do EKS.
  # O Terraform chamará o comando 'aws eks get-token' para se autenticar na API do Kubernetes.
  exec {
    api_version = "client.authentication.k8s.io/v1beta1" # Versão da API de autenticação do cliente Kubernetes.
    command     = "aws"                                  # Comando a ser executado.
    # Argumentos para o comando 'aws'.
    # Opcional: Adicione ["--profile", "seu-perfil-aws"] se usar um perfil AWS nomeado.
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main_cluster.name]
  }
}

# Configura o provedor Helm para gerenciar charts Helm no cluster Kubernetes.
# Similar ao provedor Kubernetes, usa o endpoint, CA e token do cluster EKS.
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main_cluster.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main_cluster.name]
    }
  }
}

# ------------------------------------------------------------------------------
# Recurso Principal: Cluster Amazon EKS (Control Plane)
# Define e configura o control plane do EKS.
# ------------------------------------------------------------------------------
resource "aws_eks_cluster" "main_cluster" {
  name     = var.cluster_name                     # Nome do cluster EKS, vindo da variável.
  version  = var.cluster_version                  # Versão do Kubernetes para o cluster, vindo da variável.
  role_arn = aws_iam_role.eks_cluster_role.arn # ARN da IAM Role criada em `iam.tf` para o control plane.

  # Configurações de rede para o cluster EKS.
  # Define em quais sub-redes o control plane será implantado e como ele será acessado.
  vpc_config {
    subnet_ids              = var.subnet_ids              # Lista de IDs de sub-redes para o control plane.
    endpoint_private_access = var.endpoint_private_access # Habilita/desabilita acesso privado ao endpoint da API.
    endpoint_public_access  = var.endpoint_public_access  # Habilita/desabilita acesso público ao endpoint da API.
    public_access_cidrs     = var.public_access_cidrs     # CIDRs permitidos para acesso público.
    # security_group_ids = [aws_security_group.eks_cluster_sg.id] # Exemplo: Se um Security Group customizado fosse gerenciado.
  }

  # Configuração de logging do control plane.
  # Define quais tipos de logs do control plane são enviados para o Amazon CloudWatch Logs.
  enabled_cluster_log_types = var.enabled_cluster_log_types

  # Tags AWS aplicadas ao cluster EKS.
  tags = merge(
    var.tags, # Mescla com tags globais definidas pelo usuário.
    {
      Name = var.cluster_name # Tag 'Name' padrão com o nome do cluster.
      # Tag para identificar que este cluster é gerenciado pelo Terraform.
      "TerraformManaged" = "true"
    }
  )

  # Garante que a IAM role do cluster e seus anexos de política estejam completamente
  # configurados antes de tentar criar o cluster EKS.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment,
    # aws_iam_role_policy_attachment.eks_service_policy_attachment, # Descomente se a política de serviço opcional estiver em uso.
  ]
}

# ------------------------------------------------------------------------------
# Recursos dos Grupos de Nós Gerenciados (Managed Node Groups) do EKS
# Cria e configura os grupos de instâncias EC2 que servirão como nós de trabalho para o cluster.
# ------------------------------------------------------------------------------

# Cria um ou mais grupos de nós gerenciados para o cluster EKS.
# O loop `for_each` itera sobre o mapa `var.node_groups`, permitindo definir múltiplas configurações de node groups.
resource "aws_eks_node_group" "managed_nodes" {
  for_each = var.node_groups # Itera sobre cada entrada no mapa var.node_groups.

  cluster_name    = aws_eks_cluster.main_cluster.name      # Associa ao cluster EKS principal.
  node_group_name = each.value.name                        # Nome do node group, ex: "default-worker-nodes".
  node_role_arn   = aws_iam_role.eks_node_group_role.arn # ARN da IAM Role para os nós, definida em `iam.tf`.

  # Sub-redes para os nós de trabalho.
  # Usa as sub-redes específicas do node group se fornecidas (`each.value.subnet_ids`),
  # caso contrário, usa as sub-redes do control plane do cluster (`var.subnet_ids`).
  subnet_ids      = coalesce(each.value.subnet_ids, var.subnet_ids)

  # Configuração de escalonamento para o grupo de nós.
  scaling_config {
    desired_size = each.value.desired_size # Número desejado de nós.
    min_size     = each.value.min_size     # Número mínimo de nós.
    max_size     = each.value.max_size     # Número máximo de nós.
  }

  instance_types = each.value.instance_types # Tipos de instância EC2 para os nós.
  disk_size      = each.value.disk_size      # Tamanho do disco EBS (em GB) para cada nó.
  ami_type       = each.value.ami_type       # Tipo de AMI para os nós (ex: AL2_x86_64, BOTTLEROCKET).
  capacity_type  = each.value.capacity_type  # Tipo de capacidade (ON_DEMAND ou SPOT).

  # Labels do Kubernetes a serem aplicados aos nós deste grupo.
  labels = merge(
    {
      # Label padrão para identificar o nome do node group.
      "eks.amazonaws.com/nodegroup" = each.value.name
    },
    each.value.labels # Mescla com labels customizadas fornecidas pelo usuário.
  )

  # Taints do Kubernetes a serem aplicados aos nós deste grupo.
  # Bloco dinâmico para criar múltiplos taints se definidos na variável.
  dynamic "taint" {
    for_each = each.value.taints # Itera sobre a lista de taints do node group.
    content {
      key    = taint.value.key    # Chave do taint.
      value  = taint.value.value  # Valor do taint.
      effect = taint.value.effect # Efeito do taint (ex: NO_SCHEDULE).
    }
  }

  # Tags AWS aplicadas ao Auto Scaling Group do node group.
  tags = merge(
    var.tags, # Mescla com tags globais.
    {
      Name                                  = "${var.cluster_name}-${each.value.name}-NodeGroup" # Tag 'Name' específica para o ASG.
      "eks.amazonaws.com/cluster-name"      = var.cluster_name                               # Tag para identificar o cluster associado.
      "eks.amazonaws.com/nodegroup-name"    = each.value.name                                # Tag para identificar o nome do node group.
    },
    each.value.tags # Mescla com tags específicas do node group fornecidas pelo usuário.
  )

  # Garante que o control plane do EKS e a IAM role dos nós (com suas políticas)
  # estejam completamente configurados antes de tentar criar os node groups.
  depends_on = [
    aws_eks_cluster.main_cluster,
    aws_iam_role_policy_attachment.eks_worker_node_policy_attachment,
    aws_iam_role_policy_attachment.eks_ecr_read_only_policy_attachment,
    aws_iam_role_policy_attachment.eks_cni_policy_attachment,
  ]
}

# ------------------------------------------------------------------------------
# AWS Load Balancer Controller (LBC) - Instalação via Helm
# O LBC gerencia Elastic Load Balancers (ALB/NLB) para Ingresses e Services do Kubernetes.
# ------------------------------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  # Instala apenas se var.enable_aws_load_balancer_controller for true.
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"       # Nome da release Helm.
  repository = "https://aws.github.io/eks-charts"   # Repositório do chart Helm da AWS.
  chart      = "aws-load-balancer-controller"       # Nome do chart.
  namespace  = "kube-system"                        # Namespace padrão para o LBC.
  version    = var.aws_load_balancer_controller_helm_chart_version # Versão do chart.

  # Valores de configuração passados para o chart Helm.
  # Consulte a documentação do chart para todas as opções:
  # https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller
  set {
    name  = "clusterName"
    value = var.cluster_name # Nome do cluster EKS, usado pelo LBC para identificar o cluster correto.
  }
  set {
    name  = "serviceAccount.create"
    value = "true" # Permite que o chart crie a ServiceAccount para o LBC.
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller-sa" # Nome da ServiceAccount.
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" # Anotação para IRSA. O '.' precisa ser escapado.
    value = aws_iam_role.aws_lbc_sa_role.arn                             # ARN da IAM role criada para a SA do LBC.
  }
  set {
    name  = "region"
    value = data.aws_region.current.name # Região AWS atual.
  }
  set {
    name  = "vpcId"
    value = var.vpc_id # ID da VPC onde o cluster está.
  }
  # Adicione outros valores ('set' blocks) conforme necessário para customizações avançadas.

  # Garante que o cluster EKS, a IAM role da SA do LBC, e os node groups (se houver)
  # estejam prontos antes de tentar instalar o chart Helm.
  depends_on = [
    aws_eks_cluster.main_cluster,
    aws_iam_role.aws_lbc_sa_role,
    aws_eks_node_group.managed_nodes # Garante que os nós estejam disponíveis para agendar os pods do LBC.
  ]
}

# ------------------------------------------------------------------------------
# Namespace para o Nginx Ingress Controller
# Cria um namespace dedicado se o Nginx Ingress Controller estiver habilitado.
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "nginx_ingress_ns" {
  # Cria o namespace apenas se var.enable_nginx_ingress_controller for true.
  count = var.enable_nginx_ingress_controller ? 1 : 0

  metadata {
    name = var.nginx_ingress_namespace # Nome do namespace, vindo da variável.
    labels = {
      name = var.nginx_ingress_namespace # Label para identificar o namespace.
      # Adicionar outras labels se necessário, como para políticas de segurança de Pods.
      # "pod-security.kubernetes.io/enforce" = "privileged" # Exemplo, ajuste conforme suas políticas.
    }
  }

  # Garante que o cluster EKS esteja pronto e os provedores Kubernetes/Helm configurados
  # antes de tentar criar o namespace.
  depends_on = [
    aws_eks_cluster.main_cluster
  ]
}

# ------------------------------------------------------------------------------
# Nginx Ingress Controller - Instalação via Helm
# Um controlador de Ingress popular que usa Nginx como proxy reverso.
# ------------------------------------------------------------------------------
resource "helm_release" "nginx_ingress_controller" {
  # Instala apenas se var.enable_nginx_ingress_controller for true.
  count = var.enable_nginx_ingress_controller ? 1 : 0

  name       = "nginx-ingress"                             # Nome da release Helm.
  repository = "https://kubernetes.github.io/ingress-nginx" # Repositório do chart oficial.
  chart      = "ingress-nginx"                             # Nome do chart.
  # Usa o namespace criado dinamicamente (acessando o primeiro elemento da lista, pois count=1).
  namespace  = kubernetes_namespace.nginx_ingress_ns[0].metadata[0].name
  version    = var.nginx_ingress_helm_chart_version        # Versão do chart.

  # Valores de configuração passados para o chart Helm, usando yamlencode para estruturação.
  # Consulte a documentação do chart para todas as opções:
  # https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx
  values = [
    yamlencode({
      controller = {
        replicaCount = var.nginx_ingress_replica_count # Número de réplicas do controller.
        service = {
          type = "LoadBalancer" # Expõe o Nginx Ingress via um LoadBalancer.
          annotations = {
            # Annotations para usar NLB (Network Load Balancer) via AWS Load Balancer Controller.
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            # Outras annotations comuns para NLB (descomente e ajuste se necessário):
            # "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance" # ou "ip" se usando VPC CNI com custom networking.
            # "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing" # ou "internal".
            # "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          }
          # Preserva o IP de origem do cliente. Requer que os nós tenham conectividade direta com o NLB.
          externalTrafficPolicy = "Local"
        }
        # Node selectors para garantir que os pods do controller e webhooks de admissão rodem em nós Linux.
        nodeSelector = {
          "kubernetes.io/os" = "linux"
        }
        admissionWebhooks = {
          patch = {
            nodeSelector = {
              "kubernetes.io/os" = "linux"
            }
          }
        }
      }
      # Node selector para o backend padrão (usado quando nenhuma regra de Ingress corresponde).
      defaultBackend = {
        nodeSelector = {
          "kubernetes.io/os" = "linux"
        }
        # enabled = false # Descomente para desabilitar o backend padrão se não for necessário.
      }
      # Exemplo de como habilitar métricas para Prometheus (descomente e ajuste se usar Prometheus Operator):
      # controller = {
      #   metrics = {
      #     enabled = true
      #     serviceMonitor = {
      #       enabled = true
      #       namespace = "monitoring" # Namespace do Prometheus Operator.
      #     }
      #   }
      # }
    })
  ]

  # Garante que os node groups, o namespace do Nginx e, opcionalmente, o AWS LBC
  # estejam prontos antes de instalar o Nginx Ingress.
  depends_on = [
    aws_eks_node_group.managed_nodes,
    kubernetes_namespace.nginx_ingress_ns,
    # Se o AWS LBC estiver habilitado, é uma boa prática depender explicitamente dele,
    # pois o serviço do Nginx (NLB) será provisionado através do LBC.
    helm_release.aws_load_balancer_controller,
  ]
}

# ------------------------------------------------------------------------------
# Considerações de Segurança Adicionais:
# - Security Groups: O EKS cria e gerencia SGs para o control plane e node groups.
#   O AWS LBC também gerencia SGs para os Load Balancers que ele provisiona.
#   Para um controle mais granular, podem ser usados recursos como `aws_security_group_rule`
#   ou `kubernetes_network_policy`.
# - Criptografia de Segredos no etcd: Para maior segurança, considere habilitar a
#   criptografia de segredos no etcd usando uma chave KMS gerenciada pelo cliente (CMK).
#   Isso é feito através do argumento `encryption_config` no recurso `aws_eks_cluster`.
#
# Exemplo de configuração de criptografia de segredos (requer um recurso `aws_kms_key` definido):
#   encryption_config {
#     resources = ["secrets"] # Especifica que os segredos do Kubernetes devem ser criptografados.
#     provider {
#       key_arn = aws_kms_key.eks_secrets_encryption_key.arn # ARN da sua chave KMS.
#     }
#   }
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Fluent Bit para Encaminhamento de Logs de Container para CloudWatch
# Coleta logs de containers e os envia para o Amazon CloudWatch Logs.
# ------------------------------------------------------------------------------

# Renderiza o manifesto YAML do Fluent Bit com os valores das variáveis Terraform.
# O arquivo de template `fluent-bit-daemonset.yaml` contém placeholders.
data "template_file" "fluent_bit_daemonset" {
  # Cria este data source apenas se var.enable_container_logs_to_cloudwatch for true.
  count    = var.enable_container_logs_to_cloudwatch ? 1 : 0
  template = file("${path.module}/fluent-bit-daemonset.yaml") # Caminho para o arquivo de template.

  # Variáveis passadas para o template.
  vars = {
    FLUENT_BIT_SA_ROLE_ARN    = aws_iam_role.fluent_bit_sa_role.arn # ARN da IAM role para a SA do Fluent Bit.
    AWS_REGION                = data.aws_region.current.name        # Região AWS atual.
    # Nome do grupo de logs no CloudWatch. Usa o valor da variável se fornecido, senão um padrão.
    CLOUDWATCH_LOG_GROUP_NAME = coalesce(var.fluent_bit_cloudwatch_log_group_name, "/aws/eks/${var.cluster_name}/containers")
    FLUENT_BIT_NAMESPACE      = var.fluent_bit_namespace            # Namespace para os recursos do Fluent Bit.
  }
}

# Aplica o manifesto do Fluent Bit renderizado (contendo Namespace, ServiceAccount,
# ClusterRole, ClusterRoleBinding, ConfigMap, DaemonSet) usando o provedor `kubectl`.
resource "kubectl_manifest" "fluent_bit" {
  # Cria este recurso apenas se var.enable_container_logs_to_cloudwatch for true.
  count     = var.enable_container_logs_to_cloudwatch ? 1 : 0
  # Conteúdo YAML do manifesto a ser aplicado. Acessa o `rendered` do primeiro (e único) elemento.
  yaml_body = data.template_file.fluent_bit_daemonset[0].rendered

  # Dependências para garantir a ordem correta de criação dos recursos.
  depends_on = [
    aws_eks_cluster.main_cluster,          # O cluster EKS deve existir.
    aws_iam_role.fluent_bit_sa_role,       # A IAM role para a SA do Fluent Bit deve existir.
    aws_eks_node_group.managed_nodes,      # Os node groups devem estar prontos para agendar o DaemonSet.
    # Embora o namespace do Fluent Bit seja criado no manifesto, pode ser bom ter dependências explícitas
    # se outros recursos dependerem dele ou se for criado separadamente.
    # kubernetes_namespace.fluent_bit_ns, # Exemplo se o namespace fosse criado como um recurso Terraform separado.
    helm_release.aws_load_balancer_controller, # Dependência geral para garantir que o cluster está "pronto" para addons.
    helm_release.nginx_ingress_controller
  ]
}

# ------------------------------------------------------------------------------
# Gerenciamento do ConfigMap `aws-auth`
# Este ConfigMap é usado para mapear roles e usuários IAM para o RBAC do Kubernetes.
# ------------------------------------------------------------------------------
resource "kubernetes_config_map_v1_data" "aws_auth" {
  # Cria este recurso apenas se var.manage_aws_auth_configmap for true.
  count = var.manage_aws_auth_configmap ? 1 : 0

  metadata {
    name      = "aws-auth"      # Nome padrão do ConfigMap.
    namespace = "kube-system"   # Namespace onde o ConfigMap reside.
  }

  # Constrói dinamicamente o conteúdo YAML para as seções `mapRoles` e `mapUsers` do ConfigMap.
  data = {
    # Mapeia as roles IAM.
    # Inclui sempre a role dos node groups (se houver node groups definidos) para que os nós possam se juntar ao cluster.
    mapRoles = yamlencode(distinct(concat( # `distinct` remove duplicatas se a role do nó for adicionada manualmente também.
      # Mapeamento automático da role dos Node Groups.
      [for ng_key, ng_val in var.node_groups : {
        rolearn  = aws_iam_role.eks_node_group_role.arn # ARN da role compartilhada pelos node groups.
        username = "system:node:{{EC2PrivateDNSName}}" # Template padrão para permitir que os nós se juntem.
        groups   = ["system:bootstrappers", "system:nodes"] # Grupos padrão para nós.
      } if length(var.node_groups) > 0], # Adiciona este bloco apenas se houver node groups definidos.

      # Mapeamentos de roles IAM adicionais fornecidos pelo usuário através de `var.map_additional_iam_roles_to_rbac`.
      [for r in var.map_additional_iam_roles_to_rbac : {
        rolearn  = r.rolearn
        username = r.username
        groups   = r.groups
      }]
    )))

    # Mapeia os usuários IAM, conforme definido em `var.map_additional_iam_users_to_rbac`.
    mapUsers = yamlencode(
      [for u in var.map_additional_iam_users_to_rbac : {
        userarn  = u.userarn
        username = u.username
        groups   = u.groups
      }]
    )
    # Outras entradas possíveis no `aws-auth` (como `mapAccounts`) podem ser adicionadas aqui se necessário.
  }

  # `force = true` permite que o Terraform sobrescreva quaisquer alterações manuais feitas no ConfigMap.
  # Use com cautela se houver processos externos modificando o `aws-auth`.
  force = true

  # Dependências para garantir a ordem correta de criação.
  depends_on = [
    aws_eks_cluster.main_cluster,          # O cluster EKS deve existir.
    aws_iam_role.eks_node_group_role,      # O ARN da role do node group deve estar disponível.
    # Garante que os provedores Kubernetes/Helm estejam prontos, pois este é um recurso Kubernetes.
  ]
}
