# Variável para o armazenamento alocado em GB
variable "allocated_storage" {
  description = "A quantidade de armazenamento alocado para a instância de banco de dados (em GB)."
  type        = number
  default     = 20
}

# Variável para o motor do banco de dados
variable "engine" {
  description = "O motor do banco de dados a ser usado (ex: mysql, postgres, oracle-ee)."
  type        = string
  default     = "mysql"
}

# Variável para a versão do motor do banco de dados
variable "engine_version" {
  description = "A versão do motor do banco de dados."
  type        = string
  default     = "8.0" # Padrão para MySQL 8.0. Ajuste se 'engine' for diferente.
}

# Variável para a classe da instância de banco de dados
variable "instance_class" {
  description = "A classe da instância de banco de dados (ex: db.t2.micro, db.m5.large)."
  type        = string
  default     = "db.t2.micro"
}

# Variável para o nome do banco de dados inicial
variable "db_name" {
  description = "O nome do banco de dados a ser criado na instância. Deve ser especificado pelo usuário."
  type        = string
  # Sem valor padrão, tornando esta variável obrigatória.
}

# Variável para o nome de usuário mestre
variable "username" {
  description = "O nome de usuário para a conta mestre do banco de dados. Deve ser especificado pelo usuário."
  type        = string
  # Sem valor padrão, tornando esta variável obrigatória.
}

# Variável para a senha mestre
variable "password" {
  description = "A senha para a conta mestre do banco de dados. Deve ser especificado pelo usuário."
  type        = string
  sensitive   = true # Marca a variável como sensível para evitar exibição em logs.
  # Sem valor padrão, tornando esta variável obrigatória.
}
