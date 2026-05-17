variable "aws_region" {
  description = "Região da AWS onde os recursos serão criados."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado para nomear os recursos."
  type        = string
  default     = "k3s-lab"
}

variable "environment" {
  description = "Nome do ambiente."
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "Tipo das instâncias EC2. Para laboratório, t3.micro pode funcionar, mas t3.small é mais confortável para K3s."
  type        = string
  default     = "t3.small"
}

variable "worker_count" {
  description = "Quantidade de workers do cluster K3s."
  type        = number
  default     = 2
}

variable "key_name" {
  description = "Nome da key pair que será criada/importada na AWS."
  type        = string
}

variable "public_key_path" {
  description = "Caminho local da chave pública SSH. Exemplo: ~/.ssh/k3s-lab.pub"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorizado a acessar as instâncias via SSH. Exemplo: 189.10.20.30/32"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas. Usadas pelas EC2 e pelo Application Load Balancer."
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas. Usadas pelo RDS."
  type        = list(string)
  default     = ["10.10.11.0/24", "10.10.12.0/24"]
}

variable "db_name" {
  description = "Nome do banco de dados PostgreSQL criado no RDS."
  type        = string
  default     = "task_cloud"
}

variable "db_username" {
  description = "Usuário administrador do banco RDS."
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha do usuário administrador do RDS. Deve ter pelo menos 8 caracteres."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "A senha do RDS deve ter pelo menos 8 caracteres."
  }
}

variable "db_instance_class" {
  description = "Classe da instância RDS. Para laboratório, db.t3.micro costuma ser suficiente."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento alocado para o RDS em GB."
  type        = number
  default     = 20
}
