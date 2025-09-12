# HANA deployment in GCP

locals {
  create_scale_out       = var.hana_count > 1 && var.common_variables["hana"]["scale_out_enabled"] ? 1 : 0
  create_ha_infra        = var.hana_count > 1 && var.common_variables["hana"]["ha_enabled"] ? 1 : 0
  provisioning_addresses = google_compute_instance.clusternodes.*.network_interface.0.access_config.0.nat_ip
  hostname               = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
  balancer_groups        = var.hana_count > 1 && var.common_variables["hana"]["ha_enabled"] ? ["${var.common_variables["deployment_name"]}-hana-primary-group", "${var.common_variables["deployment_name"]}-hana-secondary-group"] : []
}

# HANA disks configuration information: https://cloud.google.com/solutions/sap/docs/sap-hana-planning-guide#storage_configuration
resource "google_compute_disk" "data" {
  count = var.hana_count
  name  = "${var.common_variables["deployment_name"]}-hana-data"
  type  = var.hana_data_disk_type
  size  = var.hana_data_disk_size
  zone  = element(var.compute_zones, count.index)
}

resource "google_compute_disk" "log" {
  count = var.hana_count
  name  = "${var.common_variables["deployment_name"]}-hana-log"
  type  = var.hana_log_disk_type
  size  = var.hana_log_disk_size
  zone  = element(var.compute_zones, count.index)
}

resource "google_compute_disk" "shared" {
  count = var.hana_count
  name  = "${var.common_variables["deployment_name"]}-hana-shared"
  type  = var.hana_shared_disk_type
  size  = var.hana_shared_disk_size
  zone  = element(var.compute_zones, count.index)
}

resource "google_compute_disk" "backup" {
  count = var.hana_count
  name  = "${var.common_variables["deployment_name"]}-hana-backup"
  type  = var.hana_backup_disk_type
  size  = var.hana_backup_disk_size
  zone  = element(var.compute_zones, count.index)
}

resource "google_compute_disk" "usr_sap" {
  count = var.hana_count
  name  = "${var.common_variables["deployment_name"]}-usr-sap"
  type  = var.hana_usr_sap_disk_type
  size  = var.hana_usr_sap_disk_size
  zone  = element(var.compute_zones, count.index)
}

# Don't remove the routes! Even though the RA gcp-vpc-move-route creates them, if they are not created here, the terraform destroy cannot work as it will find new route names
resource "google_compute_route" "hana-route" {
  name                   = "${var.common_variables["deployment_name"]}-hana-route"
  count                  = local.create_ha_infra == 1 && var.common_variables["hana"]["cluster_vip_mechanism"] == "route" ? 1 : 0
  dest_range             = "${var.common_variables["hana"]["cluster_vip"]}/32"
  network                = var.network_name
  next_hop_instance      = google_compute_instance.clusternodes.0.name
  next_hop_instance_zone = element(var.compute_zones, 0)
  priority               = 1000
}

# Route for Active/Active setup
resource "google_compute_route" "hana-route-secondary" {
  name                   = "${var.common_variables["deployment_name"]}-hana-route-secondary"
  count                  = local.create_ha_infra == 1 && var.common_variables["hana"]["cluster_vip_mechanism"] == "route" && var.common_variables["hana"]["cluster_vip_secondary"] != "" ? 1 : 0
  dest_range             = "${var.common_variables["hana"]["cluster_vip_secondary"]}/32"
  network                = var.network_name
  next_hop_instance      = google_compute_instance.clusternodes.1.name
  next_hop_instance_zone = element(var.compute_zones, 1)
  priority               = 1000
}

# GCP load balancer resource
resource "google_compute_instance_group" "hana-lb-groups" {
  for_each  = toset(local.balancer_groups)
  name      = each.value
  zone      = element(var.compute_zones, index(local.balancer_groups, each.value))
  instances = [google_compute_instance.clusternodes[index(local.balancer_groups, each.value)].id]
}

module "hana-load-balancer" {
  count                 = local.create_ha_infra == 1 && var.common_variables["hana"]["cluster_vip_mechanism"] == "load-balancer" ? 1 : 0
  source                = "../../modules/load_balancer"
  name                  = "${var.common_variables["deployment_name"]}-hana"
  region                = var.common_variables["region"]
  network_name          = var.network_name
  network_subnet_name   = var.network_subnet_name
  primary_node_group    = google_compute_instance_group.hana-lb-groups["${var.common_variables["deployment_name"]}-hana-primary-group"].id
  secondary_node_group  = google_compute_instance_group.hana-lb-groups["${var.common_variables["deployment_name"]}-hana-secondary-group"].id
  tcp_health_check_port = tonumber("625${var.common_variables["hana"]["instance_number"]}")
  target_tags           = ["hana-group"]
  ip_address            = var.common_variables["hana"]["cluster_vip"]
}

# Load balancer for Active/Active setup
module "hana-secondary-load-balancer" {
  count                 = local.create_ha_infra == 1 && var.common_variables["hana"]["cluster_vip_mechanism"] == "load-balancer" && var.common_variables["hana"]["cluster_vip_secondary"] != "" ? 1 : 0
  source                = "../../modules/load_balancer"
  name                  = "${var.common_variables["deployment_name"]}-hana-secondary"
  region                = var.common_variables["region"]
  network_name          = var.network_name
  network_subnet_name   = var.network_subnet_name
  primary_node_group    = google_compute_instance_group.hana-lb-groups["${var.common_variables["deployment_name"]}-hana-primary-group"].id
  secondary_node_group  = google_compute_instance_group.hana-lb-groups["${var.common_variables["deployment_name"]}-hana-secondary-group"].id
  tcp_health_check_port = tonumber("626${var.common_variables["hana"]["instance_number"]}")
  target_tags           = ["hana-group"]
  ip_address            = var.common_variables["hana"]["cluster_vip_secondary"]
}

resource "google_compute_instance" "clusternodes" {
  machine_type = var.vm_size
  name         = "${var.common_variables["deployment_name"]}-${var.name}${format("%02d", count.index + 1)}"
  count        = var.hana_count
  zone         = element(var.compute_zones, count.index)

  can_ip_forward = true

  network_interface {
    subnetwork = var.network_subnet_name
    network_ip = element(var.host_ips, count.index)

    # Set public IP address.
    dynamic "access_config" {
      for_each = [1]
      content {}
    }
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  boot_disk {
    initialize_params {
      image = var.os_image
    }

    auto_delete = true
  }

  attached_disk {
    source      = element(google_compute_disk.data.*.self_link, count.index)
    device_name = element(google_compute_disk.data.*.name, count.index)
    mode        = "READ_WRITE"
  }

  attached_disk {
    source      = element(google_compute_disk.log.*.self_link, count.index)
    device_name = element(google_compute_disk.log.*.name, count.index)
    mode        = "READ_WRITE"
  }

  attached_disk {
    source      = element(google_compute_disk.shared.*.self_link, count.index)
    device_name = element(google_compute_disk.shared.*.name, count.index)
    mode        = "READ_WRITE"
  }

  attached_disk {
    source      = element(google_compute_disk.backup.*.self_link, count.index)
    device_name = element(google_compute_disk.backup.*.name, count.index)
    mode        = "READ_WRITE"
  }

  attached_disk {
    source      = element(google_compute_disk.usr_sap.*.self_link, count.index)
    device_name = element(google_compute_disk.usr_sap.*.name, count.index)
    mode        = "READ_WRITE"
  }


  metadata = {
    sshKeys = "${var.common_variables["authorized_user"]}:${var.common_variables["public_key"]}"
  }

  service_account {
    scopes = ["compute-rw", "storage-rw", "logging-write", "monitoring-write", "service-control", "service-management"]
  }

  tags = ["hana-group"]
}
