variable "cluster_name" { type = string }
variable "vpc_id"       { type = string }
variable "subnet_ids"   { type = list(string) }
variable "environment"  { type = string }
variable "kafka_version" { type = string; default = "3.6.0" }

resource "aws_security_group" "kafka" {
  name   = "${var.cluster_name}-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = 9092
    to_port     = 9096
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "MSK broker ports"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_msk_cluster" "kafka" {
  cluster_name           = var.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = "kafka.m5.xlarge"
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.kafka.id]
    storage_info {
      ebs_storage_info { volume_size = 500 }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.telco.arn
    revision = aws_msk_configuration.telco.latest_revision
  }

  enhanced_monitoring = "PER_TOPIC_PER_PARTITION"

  open_monitoring {
    prometheus {
      jmx_exporter  { enabled_in_broker = true }
      node_exporter { enabled_in_broker = true }
    }
  }
}

resource "aws_msk_configuration" "telco" {
  name = "${var.cluster_name}-config"
  kafka_versions = [var.kafka_version]
  server_properties = <<-PROPS
    auto.create.topics.enable=false
    default.replication.factor=3
    min.insync.replicas=2
    num.partitions=12
    log.retention.hours=168
    log.retention.bytes=107374182400
    compression.type=snappy
    message.max.bytes=10485760
    replica.fetch.max.bytes=10485760
  PROPS
}

output "bootstrap_brokers"     { value = aws_msk_cluster.kafka.bootstrap_brokers_tls }
output "zookeeper_connect_string" { value = aws_msk_cluster.kafka.zookeeper_connect_string }
