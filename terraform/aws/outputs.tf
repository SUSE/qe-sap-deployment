# Outputs:
# - Private IP
# - Public IP
# - Private node name
# - Public node name

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
      hana_hostname       = var.hana_name,
      hana-pip            = module.hana_node.hana_public_ip,
      hana-major-version  = local.hana_major_version,
      iscsi_hostname      = var.iscsi_name,
      iscsi-pip           = module.iscsi_server.iscsisrv_public_ip,
      iscsi-enabled       = local.iscsi_enabled,
      iscsi-major-version = local.iscsi_major_version
  })
  filename = "inventory.yaml"
}

# Additional cluster information
resource "local_file" "cluster_data" {
  content = templatefile("aws_cluster_data.tftpl",
    {
      routetable_id = aws_route_table.route-table.id,
      virtual_ip    = local.hana_cluster_vip
  })
  filename = "aws_cluster_data.yaml"
}
