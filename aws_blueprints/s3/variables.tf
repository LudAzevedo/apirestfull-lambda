# Variável para o nome do bucket S3
variable "bucket_name" {
  description = "O nome do bucket S3. Deve ser globalmente único."
  type        = string
  # Sem valor padrão, tornando esta variável obrigatória.
}

# Variável para habilitar ou desabilitar o versionamento do bucket
variable "enable_versioning" {
  description = "Define se o versionamento deve ser habilitado para o bucket S3."
  type        = bool
  default     = false
}
