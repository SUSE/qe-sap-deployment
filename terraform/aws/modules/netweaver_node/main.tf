locals {
  vm_count           = var.xscs_server_count + var.app_server_count
  create_ha_infra    = local.vm_count > 1 && var.common_variables["netweaver"]["ha_enabled"] ? 1 : 0
  app_start_index    = local.create_ha_infra == 1 ? 2 : 1
  hostname           = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
  shared_storage_efs = var.common_variables["netweaver"]["shared_storage_type"] == "efs" ? 1 : 0
}

# Network resources: subnets, routes, etc

resource "aws_subnet" "netweaver-subnet" {
  count             = min(local.vm_count, 2) # Create 2 subnets max
  vpc_id            = var.vpc_id
  cidr_block        = element(var.subnet_address_range, count.index)
  availability_zone = element(var.availability_zones, count.index)
  tags = {
    name      = "${var.common_variables["deployment_name"]}-netweaver-subnet-${count.index + 1}"
    workspace = var.common_variables["deployment_name"]
  }
}

resource "aws_route_table_association" "netweaver-subnet-route-association" {
  count          = min(local.vm_count, 2)
  subnet_id      = element(aws_subnet.netweaver-subnet.*.id, count.index)
  route_table_id = var.route_table_id
}

resource "aws_route" "nw-ascs-route" {
  count                  = local.vm_count > 0 ? 1 : 0
  route_table_id         = var.route_table_id
  destination_cidr_block = "${element(var.virtual_host_ips, 0)}/32"
  network_interface_id   = aws_instance.netweaver.0.primary_network_interface_id
}

resource "aws_route" "nw-ers-route" {
  count                  = local.create_ha_infra
  route_table_id         = var.route_table_id
  destination_cidr_block = "${element(var.virtual_host_ips, 1)}/32"
  network_interface_id   = aws_instance.netweaver.1.primary_network_interface_id
}

# deploy if PAS on same machine as ASCS
resource "aws_route" "nw-pas-route" {
  count                  = local.vm_count > 0 && var.app_server_count == 0 ? 1 : 0
  route_table_id         = var.route_table_id
  destination_cidr_block = "${element(var.virtual_host_ips, local.app_start_index)}/32"
  network_interface_id   = aws_instance.netweaver.0.primary_network_interface_id
}

# deploy if PAS and AAS on separate hosts
resource "aws_route" "nw-app-route" {
  count                  = var.app_server_count
  route_table_id         = var.route_table_id
  destination_cidr_block = "${element(var.virtual_host_ips, local.app_start_index + count.index)}/32"
  network_interface_id   = aws_instance.netweaver[local.app_start_index + count.index].primary_network_interface_id
}

# EFS storage for nfs share used by Netweaver for /usr/sap/{sid} and /sapmnt
# It will be created for netweaver only when drbd is disabled
resource "aws_efs_file_system" "netweaver-efs" {
  count            = local.vm_count > 0 ? local.shared_storage_efs : 0
  creation_token   = "${var.common_variables["deployment_name"]}-netweaver-efs"
  performance_mode = var.efs_performance_mode

  tags = {
    Name = "${var.common_variables["deployment_name"]}-efs"
  }
}

resource "aws_efs_mount_target" "netweaver-efs-mount-target" {
  count           = local.vm_count > 0 && local.shared_storage_efs == 1 ? min(local.vm_count, 2) : 0
  file_system_id  = aws_efs_file_system.netweaver-efs.0.id
  subnet_id       = element(aws_subnet.netweaver-subnet.*.id, count.index)
  security_groups = [var.security_group_id]
}

module "get_os_image" {
  source   = "../../modules/get_os_image"
  os_image = var.os_image
  os_owner = var.os_owner
}

resource "aws_instance" "netweaver" {
  count                       = local.vm_count
  ami                         = module.get_os_image.image_id
  instance_type               = var.vm_size
  key_name                    = var.key_name
  associate_public_ip_address = true
  subnet_id                   = element(aws_subnet.netweaver-subnet.*.id, count.index % 2) # %2 is used because there are not more than 2 subnets
  private_ip                  = element(var.host_ips, count.index)
  vpc_security_group_ids      = [var.security_group_id]
  availability_zone           = element(var.availability_zones, count.index % 2)
  source_dest_check           = false
  user_data                   = templatefile("${path.root}/adminuser.tpl", { username = var.common_variables["authorized_user"], publickey = var.common_variables["public_key"], hostname = "${var.name}${format("%02d", count.index + 1)}", domain = var.network_domain })

  root_block_device {
    volume_type = "gp2"
    volume_size = "60"
  }

  # Disk to store Netweaver software installation files
  ebs_block_device {
    volume_type = "gp2"
    volume_size = "60"
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
