# Outputs:
# - Private IP
# - Public IP
# - Private node name
# - Public node name

# Timestamp of apply
output "Timestamp" {
  value = timestamp()
}

# iSCSI server

output "iscsisrv_ip" {
  value = module.iscsi_server.iscsisrv_ip
}

output "iscsisrv_public_ip" {
  value = join("", module.iscsi_server.iscsisrv_public_ip)
}

output "iscsisrv_name" {
  value = join("", module.iscsi_server.iscsisrv_name)
}

output "iscsisrv_public_name" {
  value = join("", module.iscsi_server.iscsisrv_public_name)
}

# Hana nodes

output "hana_ip" {
  value = module.hana_node.hana_ip
}

output "hana_public_ip" {
  value = module.hana_node.hana_public_ip
}

output "hana_name" {
  value = module.hana_node.hana_name
}

output "hana_public_name" {
  value = module.hana_node.hana_public_name
}

# Monitoring

output "monitoring_ip" {
  value = module.monitoring.monitoring_ip
}

output "monitoring_public_ip" {
  value = module.monitoring.monitoring_public_ip
}

output "monitoring_name" {
  value = module.monitoring.monitoring_name
}

output "monitoring_public_name" {
  value = module.monitoring.monitoring_public_name
}

# drbd

output "drbd_ip" {
  value = module.drbd_node.drbd_ip
}

output "drbd_public_ip" {
  value = module.drbd_node.drbd_public_ip
}

output "drbd_name" {
  value = module.drbd_node.drbd_name
}

output "drbd_public_name" {
  value = module.drbd_node.drbd_public_name
}

# netweaver

output "netweaver_ip" {
  value = module.netweaver_node.netweaver_ip
}

output "netweaver_public_ip" {
  value = module.netweaver_node.netweaver_public_ip
}

output "netweaver_name" {
  value = module.netweaver_node.netweaver_name
}

output "netweaver_public_name" {
  value = module.netweaver_node.netweaver_public_name
}

# Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tmpl",
    {
      hana_name           = var.hana_name,
      hana_pip            = module.hana_node.hana_public_ip,
      hana_remote_python  = var.hana_remote_python,
      hana_machinetype    = var.hana_instancetype,
      iscsi_name          = var.iscsi_name,
      iscsi_pip           = module.iscsi_server.iscsisrv_public_ip,
      iscsi_enabled       = local.iscsi_enabled,
      iscsi_remote_python = var.iscsi_remote_python,
      iscsi_machinetype   = var.iscsi_instancetype,
      routetable_id       = aws_route_table.route-table.id,
      cluster_ip          = local.hana_cluster_vip,
      stonith_tag         = module.hana_node.stonith_tag,
      region              = var.aws_region
      ebs_map             = module.hana_node.volume_id_to_device_name
  })
  filename = "inventory.yaml"
}

