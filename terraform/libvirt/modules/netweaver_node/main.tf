terraform {
  required_version = ">= 1.1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.6.14"
    }
  }
}

locals {
  vm_count = var.xscs_server_count + var.app_server_count
  hostname = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

resource "libvirt_volume" "netweaver_image_disk" {
  count            = local.vm_count
  name             = "${var.common_variables["deployment_name"]}-${var.name}-${count.index + 1}-main-disk"
  source           = var.source_image
  base_volume_name = var.volume_name
  pool             = var.storage_pool
}

resource "libvirt_domain" "netweaver_domain" {
  name       = "${var.common_variables["deployment_name"]}-${var.name}${format("%02d", count.index + 1)}"
  memory     = var.memory
  vcpu       = var.vcpu
  count      = local.vm_count
  cloudinit  = var.userdata
  qemu_agent = true

  dynamic "disk" {
    for_each = slice([
      {
        "vol_id" = element(libvirt_volume.netweaver_image_disk.*.id, count.index)
      },
      {
        "vol_id" = var.shared_disk_id
      },
    ], 0, var.common_variables["netweaver"]["ha_enabled"] ? 2 : 1)
    content {
      volume_id = disk.value.vol_id
    }
  }

  network_interface {
    wait_for_lease = true
    network_name   = var.network_name
    bridge         = var.bridge
    mac            = var.mac
  }

  network_interface {
    wait_for_lease = false
    network_name   = var.isolated_network_name
    network_id     = var.isolated_network_id
    addresses      = [element(var.host_ips, count.index)]
  }

  xml {
    xslt = file("modules/netweaver_node/shareable.xls")
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  cpu {
    mode = "host-passthrough"
  }
}

output "output_data" {
  value = {
    id                = libvirt_domain.netweaver_domain.*.id
    name              = libvirt_domain.netweaver_domain.*.name
    private_addresses = var.host_ips
    addresses         = libvirt_domain.netweaver_domain.*.network_interface.0.addresses.0
  }
}
