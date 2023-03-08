locals {
  bastion_count      = 0
  deployment_name    = var.common_variables["deployment_name"]
  private_ip_address = cidrhost(var.snet_address_range, 5)
  firewall_ports     = var.common_variables["monitoring_enabled"] ? ["22", "3000"] : ["22"]
  hostname           = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

# Bastion subnet
resource "google_compute_subnetwork" "bastion_subnet" {
  count         = local.bastion_count
  name          = "${local.deployment_name}-bastion-subnet"
  network       = var.network_link
  region        = var.region
  ip_cidr_range = var.snet_address_range
}

# Connection to the bastion
resource "google_compute_firewall" "bastion_ingress_firewall" {
  count         = local.bastion_count
  name          = "${local.deployment_name}-bastion-ingress-firewall"
  network       = var.network_link
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["bastion"]

  allow {
    protocol = "tcp"
    ports    = local.firewall_ports
  }
}

# Connection between bastion and other machines
resource "google_compute_firewall" "bastion_egress_firewall" {
  count       = local.bastion_count
  name        = "${local.deployment_name}-bastion-egress-firewall"
  network     = var.network_link
  source_tags = ["bastion"]

  allow {
    protocol = "tcp"
    ports    = local.firewall_ports
  }
}

resource "google_compute_instance" "bastion" {
  count        = local.bastion_count
  name         = "${local.deployment_name}-${var.name}"
  description  = "Bastion server"
  machine_type = var.vm_size
  zone         = element(var.compute_zones, 0)

  network_interface {
    subnetwork = google_compute_subnetwork.bastion_subnet.*.name[0]
    network_ip = local.private_ip_address

    access_config {
      nat_ip = ""
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

  metadata = {
    sshKeys = "${var.common_variables["authorized_user"]}:${var.common_variables["bastion_public_key"]}"
  }

  tags = ["bastion"]
}
