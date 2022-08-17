locals {
  hostname = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

module "get_os_image" {
  source   = "../../modules/get_os_image"
  os_image = var.os_image
  os_owner = var.os_owner
}

resource "aws_instance" "monitoring" {
  count                       = var.monitoring_enabled == true ? 1 : 0
  ami                         = module.get_os_image.image_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  subnet_id                   = element(var.subnet_ids, 0)
  private_ip                  = var.monitoring_srv_ip
  vpc_security_group_ids      = [var.security_group_id]
  availability_zone           = element(var.availability_zones, 0)
  user_data                   = templatefile("${path.root}/adminuser.tpl", { username = var.common_variables["authorized_user"], publickey = var.common_variables["public_key"] })

  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
  }

  ebs_block_device {
    volume_type = "gp2"
    volume_size = "10"
    device_name = "/dev/sdb"
  }

  volume_tags = {
    Name = "${var.common_variables["deployment_name"]}-${var.name}"
  }

  tags = {
    Name      = "${var.common_variables["deployment_name"]}-${var.name}"
    Workspace = var.common_variables["deployment_name"]
  }
}
