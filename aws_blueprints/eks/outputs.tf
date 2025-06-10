# ------------------------------------------------------------------------------
# Saídas do Módulo EKS Control Plane
# Estas saídas fornecem informações essenciais sobre o cluster EKS criado.
# ------------------------------------------------------------------------------

# O endpoint do servidor da API do Kubernetes para o cluster EKS.
# Usado para configurar o `kubectl` e outros clientes para interagir com o cluster.
output "cluster_endpoint" {
  description = "O endpoint (URL) do servidor da API do Kubernetes para o cluster EKS. Usado para configurar o kubectl."
  value       = aws_eks_cluster.main_cluster.endpoint
}

# O Amazon Resource Name (ARN) completo do cluster EKS.
# Identificador único do cluster na AWS.
output "cluster_arn" {
  description = "O ARN (Amazon Resource Name) completo do cluster EKS."
  value       = aws_eks_cluster.main_cluster.arn
}

# O ID do cluster EKS (geralmente o mesmo que o nome do cluster).
output "cluster_id" {
  description = "O ID do cluster EKS (normalmente corresponde ao nome do cluster fornecido)."
  value       = aws_eks_cluster.main_cluster.id
}

# A URL do provedor OpenID Connect (OIDC) do cluster EKS.
# Essencial para configurar o IAM Roles for Service Accounts (IRSA), permitindo que pods assumam roles IAM.
output "cluster_oidc_issuer_url" {
  description = "A URL do provedor OIDC (OpenID Connect) do cluster EKS. Necessária para configurar IAM Roles for Service Accounts (IRSA)."
  value       = aws_eks_cluster.main_cluster.identity[0].oidc[0].issuer
}

# O nome da IAM Role criada para o control plane do EKS.
output "cluster_iam_role_name" {
  description = "O nome da IAM role associada ao control plane do cluster EKS."
  value       = aws_iam_role.eks_cluster_role.name
}

# O ARN da IAM Role criada para o control plane do EKS.
output "cluster_iam_role_arn" {
  description = "O ARN (Amazon Resource Name) da IAM role associada ao control plane do cluster EKS."
  value       = aws_iam_role.eks_cluster_role.arn
}

# O ID do Security Group principal criado e associado ao cluster EKS.
# Este security group controla o tráfego de e para o control plane do EKS.
output "cluster_security_group_id" {
  description = "O ID do security group principal associado ao control plane do cluster EKS. Controla o tráfego de e para o control plane."
  value       = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
}

# A versão do Kubernetes do cluster EKS.
output "cluster_version" {
  description = "A versão do Kubernetes configurada e em execução no cluster EKS."
  value       = aws_eks_cluster.main_cluster.version
}

# ------------------------------------------------------------------------------
# Saídas dos Grupos de Nós Gerenciados (Managed Node Groups) do EKS
# Estas saídas fornecem informações sobre os node groups criados.
# ------------------------------------------------------------------------------

# Um mapa dos ARNs dos Node Groups criados.
# A chave do mapa é a mesma chave usada em `var.node_groups` (o nome lógico do node group).
output "node_group_arns" {
  description = "Mapa dos ARNs (Amazon Resource Names) dos grupos de nós EKS criados, indexados pelo nome lógico do grupo (chave do mapa 'var.node_groups')."
  value       = { for k, ng in aws_eks_node_group.managed_nodes : k => ng.arn }
}

# Um mapa dos nomes dos Node Groups criados na AWS.
# A chave do mapa é o nome lógico do node group.
output "node_group_names" {
  description = "Mapa dos nomes reais dos grupos de nós EKS criados na AWS, indexados pelo nome lógico do grupo."
  value       = { for k, ng in aws_eks_node_group.managed_nodes : k => ng.node_group_name }
}

# Um mapa dos ARNs das IAM Roles associadas a cada Node Group.
# Neste módulo, todos os node groups gerenciados compartilham a mesma role IAM.
output "node_group_iam_role_arns" {
  description = "Mapa dos ARNs das IAM roles dos grupos de nós EKS, indexados pelo nome lógico do grupo. Todos os grupos de nós gerenciados por este módulo compartilham a mesma role."
  value       = { for k, ng in aws_eks_node_group.managed_nodes : k => aws_iam_role.eks_node_group_role.arn }
}

# O nome da IAM Role compartilhada pelos Node Groups.
output "node_group_shared_iam_role_name" {
  description = "O nome da IAM role compartilhada por todos os grupos de nós gerenciados criados por este módulo."
  value       = aws_iam_role.eks_node_group_role.name
}

# ------------------------------------------------------------------------------
# Saídas do AWS Load Balancer Controller (LBC)
# Estas saídas são relevantes se o LBC estiver habilitado.
# ------------------------------------------------------------------------------

# O ARN da IAM Role criada para a Service Account do AWS Load Balancer Controller.
# Retorna `null` se o LBC não estiver habilitado (`var.enable_aws_load_balancer_controller` é `false`).
output "aws_load_balancer_controller_sa_role_arn" {
  description = "O ARN da IAM Role para a Service Account do AWS Load Balancer Controller. Retorna 'null' se o LBC não estiver habilitado."
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_lbc_sa_role.arn : null
}

# O nome da Service Account Kubernetes usada pelo AWS Load Balancer Controller.
# Retorna `null` se o LBC não estiver habilitado.
output "aws_load_balancer_controller_sa_name" {
  description = "O nome da Service Account Kubernetes configurada para o AWS Load Balancer Controller. Retorna 'null' se o LBC não estiver habilitado."
  value       = var.enable_aws_load_balancer_controller ? "aws-load-balancer-controller-sa" : null # Conforme definido no Helm chart e na política de confiança IAM.
}

# ------------------------------------------------------------------------------
# Saídas do Fluent Bit (Logs de Container para CloudWatch)
# Estas saídas são relevantes se o encaminhamento de logs de container estiver habilitado.
# ------------------------------------------------------------------------------

# O nome do grupo de logs do CloudWatch para onde os logs de container são enviados pelo Fluent Bit.
# Retorna `null` se o encaminhamento de logs de container não estiver habilitado.
output "fluent_bit_cloudwatch_log_group" {
  description = "O nome do grupo de logs do CloudWatch usado pelo Fluent Bit para os logs de container. Retorna 'null' se o encaminhamento de logs estiver desabilitado."
  value       = var.enable_container_logs_to_cloudwatch ? coalesce(var.fluent_bit_cloudwatch_log_group_name, "/aws/eks/${var.cluster_name}/containers") : null
}

# O ARN da IAM Role criada para a Service Account do Fluent Bit.
# Retorna `null` se o encaminhamento de logs de container não estiver habilitado.
output "fluent_bit_sa_role_arn" {
  description = "O ARN da IAM Role para a Service Account do Fluent Bit. Retorna 'null' se o encaminhamento de logs estiver desabilitado."
  value       = var.enable_container_logs_to_cloudwatch ? aws_iam_role.fluent_bit_sa_role.arn : null
}

# O nome do namespace onde os recursos do Fluent Bit estão implantados.
# Retorna `null` se o encaminhamento de logs de container não estiver habilitado.
output "fluent_bit_namespace_name" {
  description = "O namespace Kubernetes onde os recursos do Fluent Bit (DaemonSet, ConfigMap, etc.) estão implantados. Retorna 'null' se o encaminhamento de logs estiver desabilitado."
  value       = var.enable_container_logs_to_cloudwatch ? var.fluent_bit_namespace : null
}

# ------------------------------------------------------------------------------
# Saídas do Nginx Ingress Controller
# Estas saídas são relevantes se o Nginx Ingress Controller estiver habilitado.
# ------------------------------------------------------------------------------

# O hostname do Network Load Balancer (NLB) criado para o Nginx Ingress Controller.
# Este é o ponto de entrada para o tráfego do Ingress.
# Retorna `null` se o Nginx Ingress Controller não estiver habilitado ou se o serviço ainda não foi provisionado.
output "nginx_ingress_controller_load_balancer_hostname" {
  description = "O hostname do Load Balancer (NLB) para o Nginx Ingress Controller. Pode levar alguns minutos para ser populado após a criação. Retorna 'null' se o Nginx Ingress não estiver habilitado."
  # Acessa o status do serviço LoadBalancer criado pelo Helm chart.
  # O 'try' é usado para evitar erros se o recurso ou seus atributos não existirem (ex: se desabilitado ou ainda não provisionado).
  value       = try(data.kubernetes_service_v1.nginx_ingress_controller_service[0].status[0].load_balancer[0].ingress[0].hostname, null)
}

# Data source para obter informações sobre o serviço Kubernetes do Nginx Ingress Controller.
# Usado para extrair o hostname do LoadBalancer para a saída `nginx_ingress_controller_load_balancer_hostname`.
data "kubernetes_service_v1" "nginx_ingress_controller_service" {
  # Cria este data source apenas se var.enable_nginx_ingress_controller for true.
  count = var.enable_nginx_ingress_controller ? 1 : 0

  metadata {
    # Nome padrão do serviço criado pelo chart Helm `ingress-nginx`. Ajuste se o nome for diferente.
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = var.nginx_ingress_namespace
  }

  # Garante que o Helm chart do Nginx Ingress tenha sido aplicado antes de tentar ler o serviço.
  depends_on = [helm_release.nginx_ingress_controller]
}
