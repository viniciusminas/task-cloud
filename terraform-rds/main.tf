terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# =========================================
# VARIABLES
# =========================================

variable "db_username" {
  default = "postgres"
}

variable "db_password" {
  sensitive = true
}

variable "db_name" {
  default = "task_cloud"
}

variable "vpc_id" {
  description = "ID da VPC do cluster K3s"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets privadas da VPC"
}

variable "k3s_security_group_id" {
  description = "Security Group utilizado pelos nodes do K3s"
}

# =========================================
# SECURITY GROUP DO RDS
# =========================================

resource "aws_security_group" "rds_postgres_sg" {
  name        = "rds-postgres-sg"
  description = "Permite acesso PostgreSQL do cluster K3s"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from K3s"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.k3s_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-postgres-sg"
  }
}

# =========================================
# SUBNET GROUP
# =========================================

resource "aws_db_subnet_group" "taskcloud_subnet_group" {
  name       = "taskcloud-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "taskcloud-subnet-group"
  }
}

# =========================================
# RDS POSTGRESQL
# =========================================

resource "aws_db_instance" "taskcloud_postgres" {
  identifier = "taskcloud-postgres"

  engine         = "postgres"
  engine_version = "15"

  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  port = 5432

  publicly_accessible = false

  multi_az = false

  skip_final_snapshot = true

  backup_retention_period = 1

  performance_insights_enabled = false

  enabled_cloudwatch_logs_exports = []

  vpc_security_group_ids = [
    aws_security_group.rds_postgres_sg.id
  ]

  db_subnet_group_name = aws_db_subnet_group.taskcloud_subnet_group.name

  deletion_protection = false

  auto_minor_version_upgrade = true

  tags = {
    Name = "taskcloud-postgres"
  }
}

# =========================================
# OUTPUTS
# =========================================

output "rds_endpoint" {
  value = aws_db_instance.taskcloud_postgres.endpoint
}

output "rds_database" {
  value = aws_db_instance.taskcloud_postgres.db_name
}

output "rds_username" {
  value = aws_db_instance.taskcloud_postgres.username
}

output "rds_port" {
  value = aws_db_instance.taskcloud_postgres.port
}
