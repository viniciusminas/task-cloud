# =========================================
# DATA SOURCES
# =========================================

data "aws_availability_zones" "available" {
  state = "available"
}

# AMI oficial Ubuntu 22.04 LTS da Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Token compartilhado entre master e workers para entrada no cluster K3s
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# =========================================
# NETWORK
# =========================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# Subnets públicas: EC2 e ALB
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "public"
  })
}

# Subnets privadas: RDS
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "private"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# As subnets privadas ficam apenas com a rota local da VPC.
# Para RDS privado, não é necessário NAT Gateway neste laboratório.

# =========================================
# SSH KEY
# =========================================

resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-key"
  })
}

# =========================================
# SECURITY GROUPS
# =========================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security Group do Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida geral"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security Group das instancias EC2 do cluster K3s"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH restrito"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description     = "HTTP vindo do ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "HTTPS vindo do ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Comunicacao interna do cluster K3s"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Saida geral"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2-sg"
  })
}

# Security Group do RDS adaptado do arquivo enviado.
# Ele permite PostgreSQL somente a partir do Security Group das EC2/K3s.
resource "aws_security_group" "rds_postgres" {
  name        = "${var.project_name}-rds-postgres-sg"
  description = "Permite acesso PostgreSQL do cluster K3s"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from K3s nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "Saida geral"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-postgres-sg"
  })
}

# =========================================
# EC2 + K3S
# =========================================

resource "aws_instance" "master" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    apt-get update -y
    apt-get install -y curl

    curl -sfL https://get.k3s.io | K3S_TOKEN="${random_password.k3s_token.result}" sh -s - server \
      --node-name master \
      --write-kubeconfig-mode 644

    echo 'alias kubectl="sudo k3s kubectl"' >> /home/ubuntu/.bashrc
    chown ubuntu:ubuntu /home/ubuntu/.bashrc
  EOF

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-master"
    Role = "master"
  })
}

resource "aws_instance" "workers" {
  count = var.worker_count

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    apt-get update -y
    apt-get install -y curl

    sleep 60

    curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.master.private_ip}:6443" K3S_TOKEN="${random_password.k3s_token.result}" sh -s - agent \
      --node-name worker-${count.index + 1}
  EOF

  depends_on = [
    aws_instance.master
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-worker-${count.index + 1}"
    Role = "worker"
  })
}

# =========================================
# APPLICATION LOAD BALANCER
# =========================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.alb.id]
  subnets         = aws_subnet.public[*].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb"
  })
}

resource "aws_lb_target_group" "http" {
  name        = "${var.project_name}-tg-http"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-tg-http"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_target_group_attachment" "master_http" {
  target_group_arn = aws_lb_target_group.http.arn
  target_id        = aws_instance.master.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "workers_http" {
  count = var.worker_count

  target_group_arn = aws_lb_target_group.http.arn
  target_id        = aws_instance.workers[count.index].id
  port             = 80
}

# =========================================
# RDS POSTGRESQL
# =========================================

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-postgres-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-postgres-subnet-group"
  })
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = "15"

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  port                = 5432
  publicly_accessible = false
  multi_az            = false

  skip_final_snapshot     = true
  backup_retention_period = 1
  deletion_protection     = false

  performance_insights_enabled    = false
  enabled_cloudwatch_logs_exports = []

  vpc_security_group_ids = [
    aws_security_group.rds_postgres.id
  ]

  db_subnet_group_name = aws_db_subnet_group.postgres.name

  auto_minor_version_upgrade = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-postgres"
  })
}
