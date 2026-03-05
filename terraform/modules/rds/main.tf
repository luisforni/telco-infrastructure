variable "identifier"  { type = string }
variable "vpc_id"      { type = string }
variable "subnet_ids"  { type = list(string) }
variable "environment" { type = string }
variable "instance_class" { type = string; default = "db.r6g.large" }

resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-sng"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "rds" {
  name   = "${var.identifier}-rds-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}

resource "aws_rds_cluster" "postgres" {
  cluster_identifier      = var.identifier
  engine                  = "aurora-postgresql"
  engine_version          = "15.4"
  database_name           = "telco_analytics"
  master_username         = "telco"
  manage_master_user_password = true   
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  storage_encrypted       = true
  deletion_protection     = true
  backup_retention_period = 30
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.identifier}-final"

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 32
  }
}

resource "aws_rds_cluster_instance" "instances" {
  count              = 2
  cluster_identifier = aws_rds_cluster.postgres.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.postgres.engine
  engine_version     = aws_rds_cluster.postgres.engine_version
}

output "endpoint"      { value = aws_rds_cluster.postgres.endpoint }
output "reader_endpoint" { value = aws_rds_cluster.postgres.reader_endpoint }
