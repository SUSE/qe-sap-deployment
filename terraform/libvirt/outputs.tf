# Outputs: IP address and port where the service will be listening on
# iSCSI server

output "iscsisrv_ip" {
  value = module.iscsi_server.output_data.private_addresses
}

output "iscsisrv_public_ip" {
  value = module.iscsi_server.output_data.addresses
}

output "iscsisrv_name" {
  value = module.iscsi_server.output_data.name
}

output "iscsisrv_public_name" {
  value = []
}

# Hana nodes

output "hana_ip" {
  value = module.hana_node.output_data.private_addresses
}

#output "hana_public_ip" {
#  value = module.hana_node.output_data.addresses
#}

output "hana_name" {
  value = module.hana_node.output_data.name
}

output "hana_public_name" {
  value = []
}

# Monitoring

output "monitoring_ip" {
  value = module.monitoring.output_data.private_address
}

output "monitoring_public_ip" {
  value = module.monitoring.output_data.address
}

output "monitoring_name" {
  value = module.monitoring.output_data.name
}

output "monitoring_public_name" {
  value = ""
}

# drbd

output "drbd_ip" {
  value = module.drbd_node.output_data.private_addresses
}

output "drbd_public_ip" {
  value = module.drbd_node.output_data.addresses
}

output "drbd_name" {
  value = module.drbd_node.output_data.name
}

output "drbd_public_name" {
  value = []
}

# netweaver

output "netweaver_ip" {
  value = module.netweaver_node.output_data.private_addresses
}

output "netweaver_public_ip" {
  value = module.netweaver_node.output_data.addresses
}

output "netweaver_name" {
  value = module.netweaver_node.output_data.name
}

output "netweaver_public_name" {
  value = []
}
