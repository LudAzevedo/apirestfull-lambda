# ------------------------------------------------------------------------------
# Variáveis Gerais do Cluster EKS
# ------------------------------------------------------------------------------

# Variável para o nome do cluster EKS.
# Este nome deve ser único dentro da sua conta AWS na região especificada.
# Exemplo: "meu-aplicativo-eks-producao"
variable "cluster_name" {
  description = "O nome único para o seu cluster EKS. Ex: 'meu-app-producao'."
  type        = string
  # Sem valor padrão, tornando esta variável obrigatória.
}

# Variável para a versão do Kubernetes para o cluster EKS.
# Consulte a documentação da AWS para as versões suportadas mais recentes.
# Exemplo: "1.29"
variable "cluster_version" {
  description = "A versão desejada do Kubernetes para o cluster EKS. Ex: '1.29'."
  type        = string
  default     = "1.29"
}

# ------------------------------------------------------------------------------
# Variáveis de Rede e Load Balancing
# ------------------------------------------------------------------------------

# Variável para o ID da VPC onde o cluster EKS e seus nós de trabalho serão implantados.
# O cluster e os nós residirão dentro desta VPC.
variable "vpc_id" {
  description = "O ID da VPC (Virtual Private Cloud) onde o cluster EKS e seus nós serão provisionados."
  type        = string
  # Sem valor padrão, tornando esta variável obrigatória.
}

# Variável para a lista de IDs de sub-redes para o control plane do EKS.
# Estas sub-redes devem estar na VPC especificada em var.vpc_id.
# Recomenda-se usar sub-redes privadas em pelo menos duas Zonas de Disponibilidade diferentes para alta disponibilidade do control plane.
variable "subnet_ids" {
  description = "Uma lista de IDs de sub-redes (geralmente privadas e em diferentes AZs) para implantar o control plane do EKS. Mínimo de 2 sub-redes para HA."
  type        = list(string)
  # Sem valor padrão, tornando esta variável obrigatória.
}

# Variável para habilitar o acesso privado ao endpoint do API server do Kubernetes.
# Se verdadeiro, o endpoint do API server só é acessível de dentro da VPC do cluster.
variable "endpoint_private_access" {
  description = "Se verdadeiro, habilita o acesso privado ao endpoint do API server do Kubernetes de dentro da sua VPC. Recomendado para maior segurança."
  type        = bool
  default     = false
}

# Variável para habilitar o acesso público ao endpoint do API server do Kubernetes.
# Se verdadeiro, o endpoint do API server é acessível da internet (controlado por public_access_cidrs).
variable "endpoint_public_access" {
  description = "Se verdadeiro, habilita o acesso público (internet) ao endpoint do API server do Kubernetes. O acesso é filtrado por 'public_access_cidrs'."
  type        = bool
  default     = true
}

# Variável para os blocos CIDR que podem acessar o endpoint público do API server.
# Relevante apenas se endpoint_public_access for verdadeiro. "0.0.0.0/0" permite acesso de qualquer IP.
variable "public_access_cidrs" {
  description = "Lista de blocos CIDR que têm permissão para acessar o endpoint público do API server do EKS. Padrão é '0.0.0.0/0' (acesso global)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# Variáveis de Logging do Control Plane EKS
# ------------------------------------------------------------------------------

# Variável para os tipos de log do control plane do EKS a serem enviados para o Amazon CloudWatch Logs.
# Logs possíveis: "api", "audit", "authenticator", "controllerManager", "scheduler".
variable "enabled_cluster_log_types" {
  description = "Uma lista dos tipos de logs do control plane do EKS a serem habilitados e enviados para o CloudWatch Logs. Logs válidos: 'api', 'audit', 'authenticator', 'controllerManager', 'scheduler'."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# ------------------------------------------------------------------------------
# Variáveis de Tags AWS
# ------------------------------------------------------------------------------

# Variável para tags personalizadas a serem aplicadas ao cluster EKS e outros recursos AWS criados pelo módulo.
# As tags são úteis para organização, faturamento e controle de acesso.
variable "tags" {
  description = "Um mapa de tags (chave-valor) para aplicar aos recursos AWS criados pelo módulo (cluster EKS, roles IAM, etc.). As tags padrão do módulo podem ser complementadas ou sobrescritas."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Variáveis de Configuração dos Grupos de Nós Gerenciados (Managed Node Groups)
# ------------------------------------------------------------------------------

# Variável para definir um ou mais grupos de nós gerenciados para o cluster EKS.
# Cada chave do mapa representa um nome lógico para o node group (ex: "trabalhadores_gerais", "aplicacoes_gpu").
# O valor é um objeto contendo a configuração específica para aquele node group.
variable "node_groups" {
  description = <<-EOT
  Um mapa de objetos para configurar os grupos de nós gerenciados (Managed Node Groups) do EKS.
  A chave do mapa é um nome lógico para o grupo de nós (ex: "default_workers", "gpu_intensive_apps").
  Cada objeto pode ter os seguintes atributos para personalizar o grupo de nós:
    - name: (string, obrigatório) O nome único para o grupo de nós EKS. Este nome será usado na AWS.
    - instance_types: (list(string), padrão ["t3.medium"]) Lista de tipos de instância EC2 para os nós. Ex: ["m5.large", "m5a.large"].
    - desired_size: (number, padrão 2) Número desejado de nós no grupo.
    - min_size: (number, padrão 1) Número mínimo de nós para o auto-scaling do grupo.
    - max_size: (number, padrão 3) Número máximo de nós para o auto-scaling do grupo.
    - disk_size: (number, padrão 20) Tamanho do disco EBS (em GB) para cada nó no grupo.
    - subnet_ids: (list(string), opcional) Lista de IDs de sub-redes específicas para este grupo de nós. Se omitido, usará as sub-redes definidas em 'var.subnet_ids' do cluster. Geralmente são sub-redes privadas.
    - ami_type: (string, padrão "AL2_x86_64") Tipo de AMI para os nós (ex: "AL2_x86_64", "AL2_x86_64_GPU", "AL2_ARM_64", "BOTTLEROCKET_ARM_64", "BOTTLEROCKET_x86_64", "WINDOWS_CORE_2019_x86_64").
    - labels: (map(string), opcional) Labels do Kubernetes a serem aplicados aos nós no grupo. Ex: { "workload-type" = "application" }.
    - taints: (list(object), opcional) Lista de taints do Kubernetes a serem aplicados aos nós. Cada objeto taint deve ter 'key' (string), 'value' (string), e 'effect' (string, ex: "NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE").
    - tags: (map(string), opcional) Tags AWS a serem aplicadas aos recursos do grupo de nós (ex: Auto Scaling Group).
    - capacity_type: (string, padrão "ON_DEMAND") Tipo de capacidade para os nós ("ON_DEMAND" ou "SPOT").
  EOT
  type = map(object({
    name            = string
    instance_types  = optional(list(string), ["t3.medium"])
    desired_size    = optional(number, 2)
    min_size        = optional(number, 1)
    max_size        = optional(number, 3)
    disk_size       = optional(number, 20)
    subnet_ids      = optional(list(string), null) # Se null, usará var.subnet_ids do cluster
    ami_type        = optional(string, "AL2_x86_64")
    labels          = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    tags            = optional(map(string), {})
    capacity_type   = optional(string, "ON_DEMAND")
  }))
  default     = {} # Por padrão, nenhum grupo de nós é criado.
}

# ------------------------------------------------------------------------------
# Variáveis de Configuração do AWS Load Balancer Controller (LBC)
# ------------------------------------------------------------------------------

# Variável para controlar a instalação do AWS Load Balancer Controller via Helm.
# O LBC gerencia ALBs e NLBs para Ingresses e Services do Kubernetes.
variable "enable_aws_load_balancer_controller" {
  description = "Se verdadeiro, instala o AWS Load Balancer Controller usando Helm. Isso permite o provisionamento dinâmico de ALBs/NLBs através de recursos Ingress ou Service no Kubernetes."
  type        = bool
  default     = true
}

# Variável para a versão do Helm chart do AWS Load Balancer Controller.
# É importante verificar a versão mais recente e compatível na documentação oficial da AWS ou no repositório do chart.
variable "aws_load_balancer_controller_helm_chart_version" {
  description = "A versão do Helm chart para o AWS Load Balancer Controller a ser instalada. Verifique a versão mais recente e estável recomendada pela AWS."
  type        = string
  default     = "1.7.1" # Exemplo, pode ser necessário atualizar para versões mais recentes como "1.8.x".
}

# ------------------------------------------------------------------------------
# Variáveis de Configuração do Nginx Ingress Controller
# ------------------------------------------------------------------------------

# Variável para controlar a instalação do Nginx Ingress Controller via Helm.
# Este controlador de Ingress é uma alternativa ou complemento ao AWS LBC para gerenciamento de tráfego de entrada.
variable "enable_nginx_ingress_controller" {
  description = "Se verdadeiro, instala o Nginx Ingress Controller usando Helm. Este controlador trabalha em conjunto com o AWS Load Balancer Controller (se habilitado e configurado para NLB) ou pode provisionar um Classic Load Balancer."
  type        = bool
  default     = true
}

# Variável para a versão do Helm chart do Nginx Ingress Controller.
# Verifique a versão mais recente e compatível no repositório oficial do chart.
variable "nginx_ingress_helm_chart_version" {
  description = "A versão do Helm chart para o Nginx Ingress Controller a ser instalada."
  type        = string
  default     = "4.10.0" # Exemplo, pode ser necessário atualizar para versões mais recentes como "4.10.x".
}

# Variável para o número de réplicas do Nginx Ingress Controller.
# Um número maior de réplicas aumenta a disponibilidade e a capacidade de lidar com tráfego.
variable "nginx_ingress_replica_count" {
  description = "Número de réplicas para os pods do Nginx Ingress Controller. Recomenda-se pelo menos 2 para alta disponibilidade."
  type        = number
  default     = 2
}

# Variável para o namespace do Kubernetes onde o Nginx Ingress Controller será instalado.
variable "nginx_ingress_namespace" {
  description = "O namespace do Kubernetes onde os recursos do Nginx Ingress Controller (pods, services, etc.) serão instalados."
  type        = string
  default     = "ingress-nginx"
}

# ------------------------------------------------------------------------------
# Variáveis de Configuração do `aws-auth` ConfigMap e RBAC (Role-Based Access Control)
# ------------------------------------------------------------------------------

# Variável para controlar se o Terraform deve gerenciar o ConfigMap `aws-auth`.
# Se `false`, você precisará configurar manualmente o `aws-auth` para permitir que nós e outros usuários/roles acessem o cluster.
# Gerenciar via Terraform garante consistência e versionamento da configuração de acesso.
variable "manage_aws_auth_configmap" {
  description = "Se verdadeiro, o Terraform gerenciará o ConfigMap 'aws-auth' no namespace 'kube-system'. Isso permite mapear programaticamente roles e usuários IAM para o RBAC do Kubernetes."
  type        = bool
  default     = false # Por padrão, não gerencia para evitar conflitos com configurações manuais existentes ou políticas de segurança que restrinjam a modificação.
}

# Variável para mapear roles IAM adicionais para grupos RBAC no ConfigMap `aws-auth`.
# Permite conceder permissões no cluster Kubernetes a roles IAM existentes.
variable "map_additional_iam_roles_to_rbac" {
  description = <<-EOT
  Uma lista de objetos para mapear roles IAM adicionais para o RBAC (Role-Based Access Control) do Kubernetes através do ConfigMap 'aws-auth'.
  Cada objeto na lista deve ter os seguintes atributos:
    - rolearn: (string, obrigatório) O ARN completo da role IAM a ser mapeada. Ex: "arn:aws:iam::123456789012:role/MinhaRoleDeAdminEKS".
    - username: (string, obrigatório) O nome de usuário que esta role representará dentro do Kubernetes. Ex: "admin-iam-role". Pode usar templates como "{{SessionName}}".
    - groups: (list(string), obrigatório) Uma lista de grupos RBAC do Kubernetes aos quais este usuário será associado. Ex: ["system:masters"] para acesso de administrador.
  EOT
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

# Variável para mapear usuários IAM adicionais para grupos RBAC no ConfigMap `aws-auth`.
# Permite conceder permissões no cluster Kubernetes a usuários IAM existentes.
variable "map_additional_iam_users_to_rbac" {
  description = <<-EOT
  Uma lista de objetos para mapear usuários IAM adicionais para o RBAC do Kubernetes através do ConfigMap 'aws-auth'.
  Cada objeto na lista deve ter os seguintes atributos:
    - userarn: (string, obrigatório) O ARN completo do usuário IAM a ser mapeado. Ex: "arn:aws:iam::123456789012:user/MeuUsuarioDev".
    - username: (string, obrigatório) O nome de usuário que este usuário IAM representará dentro do Kubernetes. Ex: "desenvolvedor-iam-user".
    - groups: (list(string), obrigatório) Uma lista de grupos RBAC do Kubernetes aos quais este usuário será associado. Ex: ["desenvolvedores", "visualizadores-debug"].
  EOT
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

# ------------------------------------------------------------------------------
# Variáveis de Configuração do Fluent Bit para Logs de Container no CloudWatch
# ------------------------------------------------------------------------------

# Variável para controlar a implantação do Fluent Bit para encaminhar logs de container para o CloudWatch.
# O Fluent Bit é um processador e encaminhador de logs leve.
variable "enable_container_logs_to_cloudwatch" {
  description = "Se verdadeiro, implanta o Fluent Bit como um DaemonSet no cluster para coletar logs de todos os containers e enviá-los para o Amazon CloudWatch Logs."
  type        = bool
  default     = true
}

# Variável para o nome do grupo de logs do CloudWatch para os logs de container.
# Se não especificado, um nome padrão será usado, incorporando o nome do cluster.
variable "fluent_bit_cloudwatch_log_group_name" {
  description = "O nome do grupo de logs no Amazon CloudWatch para onde os logs de container serão enviados pelo Fluent Bit. Se nulo ou vazio, um nome padrão será gerado: '/aws/eks/${var.cluster_name}/containers'."
  type        = string
  default     = null
}

# Variável para o namespace do Kubernetes onde os recursos do Fluent Bit (ServiceAccount, ConfigMap, DaemonSet) serão criados.
# "amazon-cloudwatch" é um namespace comum para add-ons da AWS.
variable "fluent_bit_namespace" {
  description = "O namespace do Kubernetes para implantar os recursos do Fluent Bit (ServiceAccount, ConfigMap, DaemonSet, etc.)."
  type        = string
  default     = "amazon-cloudwatch"
}
