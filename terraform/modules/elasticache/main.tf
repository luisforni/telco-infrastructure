variable "cluster_id"  { type = string }
variable "vpc_id"      { type = string }
variable "subnet_ids"  { type = list(string) }
variable "environment" { type = string }
variable "node_type"   { type = string; default = "cache.r7g.large" }

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.cluster_id}-sng"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "redis" {
  name   = "${var.cluster_id}-redis-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = var.cluster_id
  description          = "Telco Redis — session and queue state"
  node_type            = var.node_type
  num_cache_clusters   = 3
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true
  automatic_failover_enabled  = true
  multi_az_enabled            = true

  snapshot_retention_limit = 7
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:07:00"

  parameter_group_name = aws_elasticache_parameter_group.redis.name
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.cluster_id}-params"
  family = "redis7"
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
  parameter {
    name  = "activedefrag"
    value = "yes"
  }
}

output "endpoint"    { value = aws_elasticache_replication_group.redis.primary_endpoint_address }
output "reader_endpoint" { value = aws_elasticache_replication_group.redis.reader_endpoint_address }
