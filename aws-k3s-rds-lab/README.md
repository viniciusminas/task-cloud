# AWS K3s Lab com RDS PostgreSQL

Este projeto provisiona uma infraestrutura de laboratório na AWS com:

- VPC própria.
- 2 subnets públicas para EC2 e Application Load Balancer.
- 2 subnets privadas para RDS.
- 3 instâncias EC2 Ubuntu.
- 1 nó master K3s.
- 2 nós workers K3s.
- Application Load Balancer HTTP.
- RDS PostgreSQL privado.
- Security Group do RDS permitindo acesso apenas a partir das EC2 do cluster.

## Arquivos

- `provider.tf`: versões dos providers e configuração da região AWS.
- `variables.tf`: variáveis usadas no projeto.
- `main.tf`: recursos AWS, EC2, K3s, ALB e RDS.
- `outputs.tf`: dados úteis após o provisionamento.
- `terraform.tfvars.example`: exemplo de valores para execução.

## Como executar

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars` e ajuste principalmente:

- `ssh_allowed_cidr`
- `public_key_path`
- `key_name`
- `db_password`

Crie a chave SSH, se ainda não existir:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/k3s-lab
```

Inicialize:

```bash
terraform init
```

Valide:

```bash
terraform validate
```

Veja o plano:

```bash
terraform plan
```

Aplique:

```bash
terraform apply
```

Acesse a master:

```bash
ssh -i ~/.ssh/k3s-lab ubuntu@<MASTER_PUBLIC_IP>
```

Verifique os nodes:

```bash
sudo k3s kubectl get nodes
```

Para testar conexão com o RDS a partir da master:

```bash
sudo apt-get update
sudo apt-get install -y postgresql-client
psql -h <RDS_ADDRESS> -U postgres -d task_cloud
```

Para destruir tudo ao final do laboratório:

```bash
terraform destroy
```

## Observações

O RDS fica privado, sem IP público, e só aceita conexão PostgreSQL na porta 5432 a partir do Security Group das EC2 do cluster.

As subnets privadas não usam NAT Gateway porque o RDS não precisa sair para a internet neste laboratório. Isso ajuda a reduzir custo.

O `skip_final_snapshot = true` e `deletion_protection = false` foram mantidos para facilitar o `terraform destroy` em ambiente de estudos. Em produção, essas configurações devem ser revistas.
