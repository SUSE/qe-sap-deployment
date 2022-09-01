# Outputs:
# - Private IP
# - Public IP
# - Private node name
# - Public node name

# iSCSI server
output "hana_os_major_verion" {
  description = "The major version of the HANA OS"
  value       = local.hana_major_version
}


output "iscsisrv_ip" {
  value = module.iscsi_server.iscsisrv_ip
}

output "iscsisrv_public_ip" {
  value = module.iscsi_server.iscsisrv_public_ip
}

output "iscsisrv_name" {
  value = module.iscsi_server.iscsisrv_name
}

output "iscsisrv_public_name" {
  value = module.iscsi_server.iscsisrv_public_name
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

# bastion

output "bastion_public_ip" {
  value = module.bastion.public_ip
}

# Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tmpl",
    {
      hana-name           = module.hana_node.hana_name[0],
      hana-pip            = module.hana_node.hana_public_ip[0],
      hana-major-version  = local.hana_major_version
      iscsi-name          = module.iscsi_server.iscsisrv_name,
      iscsi-pip           = module.iscsi_server.iscsisrv_public_ip,
      iscsi-major-version = local.iscsi_major_version
      iscsi-enabled       = local.iscsi_enabled
  })
  filename = "inventory.yaml"
}

resource "local_file" "fence_data" {
  content = templatefile("fence_data.tmpl",
    {
      resource_group_name = local.resource_group_name
      subscription_id     = data.azurerm_subscription.current.subscription_id
      tenant_id           = data.azurerm_subscription.current.tenant_id
  })
  filename = "fence_data.json"
}
