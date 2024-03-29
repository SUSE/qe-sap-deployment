output "hana_ip" {
  value = google_compute_instance.clusternodes.*.network_interface.0.network_ip
}

output "hana_public_ip" {
  value = google_compute_instance.clusternodes.*.network_interface.0.access_config.0.nat_ip
}

output "hana_name" {
  value = google_compute_instance.clusternodes.*.name
}

output "hana_public_name" {
  value = []
}

output "hana_vip" {
  description = "The cluster IP address"
  value       = var.common_variables["hana"]["cluster_vip"]
}
