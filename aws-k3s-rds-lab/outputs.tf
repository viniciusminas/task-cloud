output "master_public_ip" {
  description = "IP público da instância master."
  value       = aws_instance.master.public_ip
}

output "master_private_ip" {
  description = "IP privado da instância master."
  value       = aws_instance.master.private_ip
}

output "workers_public_ips" {
  description = "IPs públicos dos workers."
  value       = aws_instance.workers[*].public_ip
}

output "workers_private_ips" {
  description = "IPs privados dos workers."
  value       = aws_instance.workers[*].private_ip
}

output "load_balancer_dns" {
  description = "DNS público do Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL."
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "Endereço sem porta do RDS PostgreSQL."
  value       = aws_db_instance.postgres.address
}

output "rds_database" {
  description = "Nome do banco criado no RDS."
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "Usuário administrador do RDS."
  value       = aws_db_instance.postgres.username
}

output "rds_port" {
  description = "Porta do RDS PostgreSQL."
  value       = aws_db_instance.postgres.port
}

output "ssh_master_command" {
  description = "Comando para acessar o master via SSH."
  value       = "ssh -i <CAMINHO_DA_CHAVE_PRIVADA> ubuntu@${aws_instance.master.public_ip}"
}

output "kubectl_check_command" {
  description = "Comando para verificar os nodes depois de acessar o master."
  value       = "sudo k3s kubectl get nodes"
}
