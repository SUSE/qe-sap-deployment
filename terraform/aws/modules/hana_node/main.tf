locals {
  hana_disk_device = "/dev/xvdd"
  create_scale_out = var.hana_count > 1 && var.common_variables["hana"]["scale_out_enabled"] ? 1 : 0
  create_ha_infra  = var.hana_count > 1 && var.common_variables["hana"]["ha_enabled"] ? 1 : 0
  hostname         = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

# Network resources: subnets, routes, etc

resource "aws_subnet" "hana-subnet" {
  count             = var.hana_count
  vpc_id            = var.vpc_id
  cidr_block        = element(var.subnet_address_range, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name      = "${var.common_variables["deployment_name"]}-hana-subnet-${count.index + 1}"
    Workspace = var.common_variables["deployment_name"]
  }
}

resource "aws_route_table_association" "hana-subnet-route-association" {
  count          = var.hana_count
  subnet_id      = element(aws_subnet.hana-subnet.*.id, count.index)
  route_table_id = var.route_table_id
}

resource "aws_route" "hana-cluster-vip" {
  count                  = local.create_ha_infra
  route_table_id         = var.route_table_id
  destination_cidr_block = "${var.common_variables["hana"]["cluster_vip"]}/32"
  network_interface_id   = aws_instance.hana.0.primary_network_interface_id
}

resource "aws_route" "hana-cluster-vip-secondary" {
  count                  = local.create_ha_infra == 1 && var.common_variables["hana"]["cluster_vip_secondary"] != "" ? 1 : 0
  route_table_id         = var.route_table_id
  destination_cidr_block = "${var.common_variables["hana"]["cluster_vip_secondary"]}/32"
  network_interface_id   = aws_instance.hana.1.primary_network_interface_id
}

module "get_os_image" {
  source   = "../../modules/get_os_image"
  os_image = var.os_image
  os_owner = var.os_owner
}

## EC2 HANA Instance
resource "aws_instance" "hana" {
  count                       = var.hana_count
  ami                         = module.get_os_image.image_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  subnet_id                   = element(aws_subnet.hana-subnet.*.id, count.index)
  private_ip                  = element(var.host_ips, count.index)
  vpc_security_group_ids      = [var.security_group_id]
  availability_zone           = element(var.availability_zones, count.index)
  source_dest_check           = false
  user_data                   = templatefile("${path.root}/adminuser.tpl", { username = var.common_variables["authorized_user"], publickey = var.common_variables["public_key"] })

  root_block_device {
    volume_type = "gp2"
    volume_size = "60"
  }

  ebs_block_device {
    volume_type = var.hana_data_disk_type
    volume_size = var.hana_data_disk_size
    device_name = "/dev/sdb"
  }

  volume_tags = {
    Name = "${var.common_variables["deployment_name"]}-${var.name}${format("%02d", count.index + 1)}"
  }

  tags = {
    Name                                                 = "${var.common_variables["deployment_name"]}-${var.name}${format("%02d", count.index + 1)}"
    Workspace                                            = var.common_variables["deployment_name"]
    "${var.common_variables["deployment_name"]}-cluster" = "${var.name}${format("%02d", count.index + 1)}"
  }
}
