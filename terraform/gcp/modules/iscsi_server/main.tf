locals {
  provisioning_addresses = google_compute_instance.iscsisrv.*.network_interface.0.access_config.0.nat_ip
  hostname               = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

resource "google_compute_disk" "iscsi_data" {
  count = var.iscsi_count
  name  = "${var.common_variables["deployment_name"]}-iscsi-data-${count.index + 1}"
  type  = "pd-standard"
  size  = var.iscsi_disk_size
  zone  = element(var.compute_zones, 0)
}

resource "google_compute_instance" "iscsisrv" {
  count        = var.iscsi_count
  name         = "${var.common_variables["deployment_name"]}-${var.name}${format("%02d", count.index + 1)}"
  description  = "iSCSI server"
  machine_type = var.machine_type
  zone         = element(var.compute_zones, 0)

  can_ip_forward = true

  network_interface {
    subnetwork = var.network_subnet_name
    network_ip = element(var.host_ips, count.index)

    # Set public IP address.
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
    source      = element(google_compute_disk.iscsi_data.*.self_link, count.index)
    device_name = element(google_compute_disk.iscsi_data.*.name, count.index)
    mode        = "READ_WRITE"
  }

  metadata = {
    sshKeys = "${var.common_variables["authorized_user"]}:${var.common_variables["public_key"]}"
  }

  service_account {
    scopes = ["compute-rw", "storage-rw", "logging-write", "monitoring-write", "service-control", "service-management"]
  }
}
