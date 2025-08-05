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

  timeouts {
    delete = "${var.hana_destroy_timeout + 10}m"
  }

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

# IBSM imported resources

locals {
  ibsm_peering_count = var.ibsm_project_tag != "" ? 1 : 0

  # The subnets defined in this file in the form of an
  # AZ -> subnet map. If more than one subnets exist in the same AZ,
  # only one is kept.
  infra_subnets_by_az = {
    for s in [aws_subnet.infra-subnet] :
    s.availability_zone => s.id
  }
  # The subnets from the root and all modules, merged in the form of an
  # AZ -> subnet map. The module maps are exported by the modules.
  all_subnets_by_az = merge(
    local.infra_subnets_by_az,
    module.hana_node.subnets_by_az,
    module.drbd_node.subnets_by_az,
    module.netweaver_node.subnets_by_az,
  )
  one_per_az_subnet_ids = values(local.all_subnets_by_az)
}

data "aws_vpc" "ibsm" {
  count = local.ibsm_peering_count

  filter {
    name   = "tag:Project"
    values = [var.ibsm_project_tag]
  }
}


data "aws_ec2_transit_gateway" "ibsm" {
  count = local.ibsm_peering_count

  filter {
    name   = "tag:Project"
    values = [var.ibsm_project_tag]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "ibsm" {
  count = local.ibsm_peering_count

  vpc_id             = local.vpc_id
  transit_gateway_id = data.aws_ec2_transit_gateway.ibsm[0].id
  subnet_ids         = local.one_per_az_subnet_ids # One subnet per AZ

  tags = {
    Name      = "${local.deployment_name}-tgw-attach"
    workspace = local.deployment_name
  }
}

resource "aws_route" "to_ibsm_via_tgw" {
  count                  = local.ibsm_peering_count
  route_table_id         = aws_route_table.route-table.id
  destination_cidr_block = data.aws_vpc.ibsm[0].cidr_block
  transit_gateway_id     = data.aws_ec2_transit_gateway.ibsm[0].id
}
