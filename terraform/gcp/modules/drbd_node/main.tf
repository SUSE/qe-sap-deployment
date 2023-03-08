# drbd deployment in GCP to host a HA NFS share for SAP Netweaver
# disclaimer: only supports a single NW installation

locals {
  provisioning_addresses = google_compute_instance.drbd.*.network_interface.0.access_config.0.nat_ip
  hostname               = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

resource "google_compute_disk" "data" {
  count = var.drbd_count
  name  = "${var.common_variables["deployment_name"]}-disk-drbd-${count.index}"
  type  = var.drbd_data_disk_type
  size  = var.drbd_data_disk_size
  zone  = element(var.compute_zones, count.index)
}

# Don't remove the routes! Even though the RA gcp-vpc-move-route creates them, if they are not created here, the terraform destroy cannot work as it will find new route names
resource "google_compute_route" "drbd-route" {
  name                   = "${var.common_variables["deployment_name"]}-drbd-route"
  count                  = var.drbd_count > 0 && var.common_variables["drbd"]["cluster_vip_mechanism"] == "route" ? 1 : 0
  dest_range             = "${var.common_variables["drbd"]["cluster_vip"]}/32"
  network                = var.network_name
  next_hop_instance      = google_compute_instance.drbd.0.name
  next_hop_instance_zone = element(var.compute_zones, 0)
  priority               = 1000
}

# GCP load balancer resource

resource "google_compute_instance_group" "drbd-primary-group" {
  count     = var.drbd_count > 0 && var.common_variables["drbd"]["cluster_vip_mechanism"] == "load-balancer" ? 1 : 0
  name      = "${var.common_variables["deployment_name"]}-drbd-primary-group"
  zone      = element(var.compute_zones, 0)
  instances = [google_compute_instance.drbd.0.id]
}

resource "google_compute_instance_group" "drbd-secondary-group" {
  count     = var.drbd_count > 1 ? 1 : 0
  name      = "${var.common_variables["deployment_name"]}-drbd-secondary-group"
  zone      = element(var.compute_zones, 1)
  instances = [google_compute_instance.drbd.1.id]
}

module "drbd-load-balancer" {
  count                 = var.drbd_count > 0 && var.common_variables["drbd"]["cluster_vip_mechanism"] == "load-balancer" ? 1 : 0
  source                = "../../modules/load_balancer"
  name                  = "${var.common_variables["deployment_name"]}-drbd"
  region                = var.common_variables["region"]
  network_name          = var.network_name
  network_subnet_name   = var.network_subnet_name
  primary_node_group    = google_compute_instance_group.drbd-primary-group.0.id
  secondary_node_group  = google_compute_instance_group.drbd-secondary-group.0.id
  tcp_health_check_port = tonumber("61000")
  target_tags           = ["drbd-group"]
  ip_address            = var.common_variables["drbd"]["cluster_vip"]
}

resource "google_compute_instance" "drbd" {
  machine_type = var.machine_type
  name         = "${var.common_variables["deployment_name"]}-${var.name}${format("%02d", count.index + 1)}"
  count        = var.drbd_count
  zone         = element(var.compute_zones, count.index)

  can_ip_forward = true

  network_interface {
    subnetwork = var.network_subnet_name
    network_ip = element(var.host_ips, count.index)

    # Set public IP address. Only if the bastion is not used
    dynamic "access_config" {
      for_each = [1]
      content {
        nat_ip = ""
      }
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

  metadata = {
    sshKeys = "${var.common_variables["authorized_user"]}:${var.common_variables["public_key"]}"
  }

  service_account {
    scopes = ["compute-rw", "storage-rw", "logging-write", "monitoring-write", "service-control", "service-management"]
  }

  tags = ["drbd-group"]
}
