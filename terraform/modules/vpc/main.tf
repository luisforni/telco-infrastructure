variable "name"         { type = string }
variable "cidr"         { type = string; default = "10.0.0.0/16" }
variable "environment"  { type = string }

data "aws_availability_zones" "available" { state = "available" }

locals {
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets  = cidrsubnets(var.cidr, 4, 4, 4)
  private_subnets = cidrsubnets(cidrsubnet(var.cidr, 4, 1), 4, 4, 4)
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = var.name }
}

resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnets[count.index]
  availability_zone = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags = {
    Name = "${var.name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_eip" "nat" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name}-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

output "vpc_id"             { value = aws_vpc.main.id }
output "public_subnet_ids"  { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
