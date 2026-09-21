# RDS module: PostgreSQL in private subnets only, credentials generated and
# stored in Secrets Manager (never in tfvars/state-visible plaintext outputs,
# never in git). External Secrets Operator reads this same secret into the cluster.

resource "aws_db_subnet_group" "this" {
  name       = "${var.cluster_name}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "db" {
  name_prefix = "${var.cluster_name}-db-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from EKS nodes only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_instance" "this" {
  identifier             = "${var.cluster_name}-db"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  storage_encrypted      = true
  db_name                = "appdb"
  username               = "appadmin"
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = var.multi_az
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot    = var.skip_final_snapshot
  deletion_protection    = var.deletion_protection

  tags = var.tags
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.cluster_name}/app/db-credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = aws_db_instance.this.db_name
    username = aws_db_instance.this.username
    password = random_password.db.result
  })
}
