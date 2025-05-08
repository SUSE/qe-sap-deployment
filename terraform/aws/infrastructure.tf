# Query for VPC id if user does not provide one
# for an existing VPC created outside of this deployment
data "aws_vpc" "current-vpc" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

data "aws_internet_gateway" "current-gateway" {
  count = var.vpc_id != "" ? 1 : 0
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

locals {
  deployment_name = var.deployment_name != "" ? var.deployment_name : terraform.workspace

  vpc_id            = var.vpc_id == "" ? aws_vpc.vpc.0.id : var.vpc_id
  internet_gateway  = var.vpc_id == "" ? aws_internet_gateway.igw.0.id : data.aws_internet_gateway.current-gateway.0.internet_gateway_id
  security_group_id = var.security_group_id != "" ? var.security_group_id : aws_security_group.secgroup.0.id
}

# AWS key pair
resource "aws_key_pair" "key-pair" {
  key_name   = "${local.deployment_name} - terraform"
  public_key = module.common_variables.configuration["public_key"]
}

# AWS availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Network resources: VPC, Internet Gateways, Security Groups for the EC2 instances and for the EFS file system
resource "aws_vpc" "vpc" {
  count                = var.vpc_id == "" ? 1 : 0
  cidr_block           = local.vpc_address_range
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    name      = "${local.deployment_name}-vpc"
    workspace = local.deployment_name
  }
}

resource "aws_internet_gateway" "igw" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = local.vpc_id

  tags = {
    name      = "${local.deployment_name}-igw"
    workspace = local.deployment_name
  }
}

resource "aws_subnet" "infra-subnet" {
  vpc_id            = local.vpc_id
  cidr_block        = local.infra_subnet_address_range
  availability_zone = element(data.aws_availability_zones.available.names, 0)

  tags = {
    name      = "${local.deployment_name}-infra-subnet"
    workspace = local.deployment_name
  }
}

resource "aws_route_table" "route-table" {
  vpc_id = local.vpc_id

  tags = {
    name      = "${local.deployment_name}-hana-route-table"
    workspace = local.deployment_name
  }
}

resource "aws_route_table_association" "infra-subnet-route-association" {
  subnet_id      = aws_subnet.infra-subnet.id
  route_table_id = aws_route_table.route-table.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = local.internet_gateway
}

locals {
  create_security_group            = var.security_group_id == "" ? 1 : 0
  create_security_group_monitoring = var.security_group_id == "" && var.monitoring_enabled == true ? 1 : 0
}

resource "aws_security_group" "secgroup" {
  count  = local.create_security_group
  name   = "${local.deployment_name}-sg"
  vpc_id = local.vpc_id

  tags = {
    name      = "${local.deployment_name}-sg"
    workspace = local.deployment_name
  }
}

resource "aws_security_group_rule" "outall" {
  count       = local.create_security_group
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}

resource "aws_security_group_rule" "local" {
  count       = local.create_security_group
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = [local.vpc_address_range]

  security_group_id = local.security_group_id
}

resource "aws_security_group_rule" "http" {
  count       = local.create_security_group
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}

resource "aws_security_group_rule" "https" {
  count       = local.create_security_group
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}

resource "aws_security_group_rule" "hawk" {
  count       = local.create_security_group
  type        = "ingress"
  from_port   = 7630
  to_port     = 7630
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}

resource "aws_security_group_rule" "ssh" {
  count       = local.create_security_group
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}


# Monitoring rules
resource "aws_security_group_rule" "hanadb_exporter" {
  count       = local.create_security_group_monitoring
  type        = "ingress"
  from_port   = 9668
  to_port     = 9668
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}


resource "aws_security_group_rule" "node_exporter" {
  count       = local.create_security_group_monitoring
  type        = "ingress"
  from_port   = 9100
  to_port     = 9100
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}

resource "aws_security_group_rule" "ha_exporter" {
  count       = local.create_security_group_monitoring
  type        = "ingress"
  from_port   = 9664
  to_port     = 9664
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}

resource "aws_security_group_rule" "saphost_exporter" {
  count       = local.create_security_group_monitoring
  type        = "ingress"
  from_port   = 9680
  to_port     = 9680
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}

resource "aws_security_group_rule" "prometheus_server" {
  count       = local.create_security_group_monitoring
  type        = "ingress"
  from_port   = 9090
  to_port     = 9090
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}

resource "aws_security_group_rule" "grafana_server" {
  count       = local.create_security_group_monitoring
  type        = "ingress"
  from_port   = 3000
  to_port     = 3000
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = local.security_group_id
}

# IBSM Peering resources

data "aws_vpc" "ibsm" {
  count = var.ibsm_vpc_id != "" ? 1 : 0
  id    = var.ibsm_vpc_id
}

data "aws_route_tables" "ibsm" {
  count = var.ibsm_vpc_id != "" ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.ibsm_vpc_id]
  }
}

resource "aws_vpc_peering_connection" "ibsm" {
  # created only when ibsm_vpc_id is provided
  count = var.ibsm_vpc_id != "" ? 1 : 0

  vpc_id      = local.vpc_id
  peer_vpc_id = var.ibsm_vpc_id

  auto_accept = true

  tags = {
    Name      = "${local.deployment_name}-ibsm-peer"
    workspace = local.deployment_name
  }
}

# Route to IBSM
resource "aws_route" "to_ibsm" {
  count                     = var.ibsm_vpc_id != "" ? 1 : 0
  route_table_id            = aws_route_table.route-table.id
  destination_cidr_block    = data.aws_vpc.ibsm[0].cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.ibsm[0].id
  depends_on                = [aws_vpc_peering_connection.ibsm]
}

resource "aws_route" "from_ibsm_" {
  for_each = var.ibsm_vpc_id != "" ? toset(data.aws_route_tables.ibsm[0].ids) : toset([])

  route_table_id            = each.value
  destination_cidr_block    = local.vpc_address_range
  vpc_peering_connection_id = aws_vpc_peering_connection.ibsm[0].id

  lifecycle {
    create_before_destroy = true
  }
}
