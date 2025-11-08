# ハンズオン用VPC
resource "aws_vpc" "handson_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "handson-vpc" }
}

data "aws_availability_zones" "available" {}

# サブネット
resource "aws_subnet" "handson_subnet" {
  vpc_id = aws_vpc.handson_vpc.id
  cidr_block = var.vpc_cidr_block
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, var.az_index)
  tags = { Name = "handson-subnet" }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "handson_gw" {
  vpc_id = aws_vpc.handson_vpc.id
  tags = { Name = "handson-gw" }
}

# ルートテーブル
resource "aws_route_table" "handson_rt" {
  vpc_id = aws_vpc.handson_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.handson_gw.id
  }
}

# ルートテーブルの関連付け
resource "aws_route_table_association" "handson_rt_assoc" {
  subnet_id = aws_subnet.handson_subnet.id
  route_table_id = aws_route_table.handson_rt.id
}

# セキュリティグループ 
resource "aws_security_group" "handson_sg" {
  vpc_id = aws_vpc.handson_vpc.id
  name = "handson-sg"
}

locals {
  ingress_ports_map = {
    for port in var.handson_ingress_ports : tostring(port) => port
  }
}

resource "aws_security_group_rule" "handson_ingress" {
  for_each = local.ingress_ports_map

  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.handson_sg.id
}

resource "aws_security_group_rule" "handson_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # all protocols
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.handson_sg.id
}