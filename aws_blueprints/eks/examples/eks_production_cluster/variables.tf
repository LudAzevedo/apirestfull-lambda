# Arquivo variables.tf para o exemplo do cluster EKS de produção.

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados."
  type        = string
  default     = "us-east-1"
}

variable "eks_admin_role_arn" {
  description = "O ARN da role IAM que será mapeada para 'system:masters' no cluster EKS. Substitua pelo ARN da sua role de administrador."
  type        = string
  # Exemplo: "arn:aws:iam::123456789012:role/MinhaRoleAdminEKS"
  # É importante que esta role exista na sua conta AWS.
  # Deixe em branco ou comente se não quiser mapear uma role admin adicional inicialmente via esta variável.
  # Se manage_aws_auth_configmap = true no módulo EKS, você ainda precisará de uma forma de acessar o cluster.
  # O criador do cluster (a identidade IAM que executa o Terraform) já tem acesso system:masters.
  default = "" # Deixe como string vazia para forçar o usuário a fornecer ou para não usar.
}

variable "cluster_name_prefix" {
  description = "Prefixo para o nome do cluster EKS e outros recursos relacionados (como a VPC)."
  type        = string
  default     = "meu-eks-prod"
}
