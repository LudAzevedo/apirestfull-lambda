# Arquivo versions.tf para o exemplo do cluster EKS de produção.
# Define os provedores Terraform necessários e suas versões.

terraform {
  required_version = ">= 1.0" # Especifica a versão mínima do Terraform

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Recomenda-se usar a versão mais recente estável do provedor AWS.
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10" # Recomenda-se usar uma versão recente do provedor Helm.
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20" # Recomenda-se usar uma versão recente do provedor Kubernetes.
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14" # Versão mínima para o provedor kubectl.
    }
    template = {
      source = "hashicorp/template"
      # Nenhuma restrição de versão específica aqui, mas pode ser adicionada.
    }
  }
}
