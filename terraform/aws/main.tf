locals {
  # Check if iscsi server has to be created
  use_sbd = (
    var.hana_cluster_fencing_mechanism == "sbd" ||
    var.drbd_cluster_fencing_mechanism == "sbd" ||
    var.netweaver_cluster_fencing_mechanism == "sbd"
  )
  iscsi_enabled = (
    var.sbd_storage_type == "iscsi" &&
    (
      (var.hana_count > 1 && var.hana_ha_enabled) ||
      var.drbd_enabled ||
      (local.netweaver_count > 1 && var.netweaver_ha_enabled)
    ) &&
    local.use_sbd ?
    true : false
  )

  # Obtain machines os_image and os_owner values
  hana_os_image       = var.hana_os_image != "" ? var.hana_os_image : var.os_image
  hana_os_owner       = var.hana_os_owner != "" ? var.hana_os_owner : var.os_owner
  iscsi_os_image      = var.iscsi_os_image != "" ? var.iscsi_os_image : var.os_image
  iscsi_os_owner      = var.iscsi_os_owner != "" ? var.iscsi_os_owner : var.os_owner
  monitoring_os_image = var.monitoring_os_image != "" ? var.monitoring_os_image : var.os_image
  monitoring_os_owner = var.monitoring_os_owner != "" ? var.monitoring_os_owner : var.os_owner
  drbd_os_image       = var.drbd_os_image != "" ? var.drbd_os_image : var.os_image
  drbd_os_owner       = var.drbd_os_owner != "" ? var.drbd_os_owner : var.os_owner
  netweaver_os_image  = var.netweaver_os_image != "" ? var.netweaver_os_image : var.os_image
  netweaver_os_owner  = var.netweaver_os_owner != "" ? var.netweaver_os_owner : var.os_owner

  netweaver_xscs_server_count = var.netweaver_enabled ? (var.netweaver_ha_enabled ? 2 : 1) : 0
  netweaver_count             = var.netweaver_enabled ? local.netweaver_xscs_server_count + var.netweaver_app_server_count : 0

  # Netweaver password checking
  # If Netweaver is not enabled, a dummy password is passed to pass the variable validation and not require
  # a password in this case
  # Otherwise, the validation will fail unless a correct password is provided
  netweaver_master_password = var.netweaver_enabled ? var.netweaver_master_password : "DummyPassword1234"
}

module "common_variables" {
  source                              = "../generic_modules/common_variables"
  provider_type                       = "aws"
  deployment_name                     = local.deployment_name
  deployment_name_in_hostname         = var.deployment_name_in_hostname
  public_key                          = var.public_key
  authorized_keys                     = var.authorized_keys
  authorized_user                     = var.admin_user
  monitoring_enabled                  = var.monitoring_enabled
  monitoring_srv_ip                   = var.monitoring_enabled ? local.monitoring_ip : ""
  hana_instance_number                = var.hana_instance_number
  hana_cost_optimized_instance_number = var.hana_cost_optimized_instance_number
  hana_primary_site                   = var.hana_primary_site
  hana_secondary_site                 = var.hana_secondary_site
  hana_fstype                         = var.hana_fstype
  hana_scenario_type                  = var.scenario_type
  hana_cluster_vip_mechanism          = "route"
  hana_cluster_vip                    = local.hana_cluster_vip
  hana_cluster_vip_secondary          = var.hana_active_active ? local.hana_cluster_vip_secondary : ""
  hana_ha_enabled                     = var.hana_ha_enabled
  hana_ignore_min_mem_check           = var.hana_ignore_min_mem_check
  hana_sbd_storage_type               = var.sbd_storage_type
  hana_scale_out_enabled              = var.hana_scale_out_enabled
  hana_scale_out_shared_storage_type  = var.hana_scale_out_shared_storage_type
  hana_scale_out_addhosts             = var.hana_scale_out_addhosts
  hana_scale_out_standby_count        = var.hana_scale_out_standby_count
  netweaver_sid                       = var.netweaver_sid
  netweaver_ascs_instance_number      = var.netweaver_ascs_instance_number
  netweaver_ers_instance_number       = var.netweaver_ers_instance_number
  netweaver_pas_instance_number       = var.netweaver_pas_instance_number
  netweaver_master_password           = local.netweaver_master_password
  netweaver_product_id                = var.netweaver_product_id
  netweaver_inst_folder               = var.netweaver_inst_folder
  netweaver_extract_dir               = var.netweaver_extract_dir
  netweaver_additional_dvds           = var.netweaver_additional_dvds
  netweaver_nfs_share                 = var.drbd_enabled ? "${local.drbd_cluster_vip}:/${var.netweaver_sid}" : var.netweaver_nfs_share
  netweaver_sapmnt_path               = var.netweaver_sapmnt_path
  netweaver_hana_ip                   = var.hana_ha_enabled ? local.hana_cluster_vip : element(local.hana_ips, 0)
  netweaver_hana_instance_number      = var.hana_instance_number
  netweaver_ha_enabled                = var.netweaver_ha_enabled
  netweaver_cluster_vip_mechanism     = "route"
  netweaver_sbd_storage_type          = var.sbd_storage_type
  netweaver_shared_storage_type       = var.netweaver_shared_storage_type
  monitoring_hana_targets             = local.hana_ips
  monitoring_hana_targets_ha          = var.hana_ha_enabled ? local.hana_ips : []
  monitoring_hana_targets_vip         = var.hana_ha_enabled ? [local.hana_cluster_vip] : [local.hana_ips[0]] # we use the vip for HA scenario and 1st hana machine for non HA to target the active hana instance
  monitoring_drbd_targets             = var.drbd_enabled ? local.drbd_ips : []
  monitoring_drbd_targets_ha          = var.drbd_enabled ? local.drbd_ips : []
  monitoring_drbd_targets_vip         = var.drbd_enabled ? [local.drbd_cluster_vip] : []
  monitoring_netweaver_targets        = var.netweaver_enabled ? local.netweaver_ips : []
  monitoring_netweaver_targets_ha     = var.netweaver_enabled && var.netweaver_ha_enabled ? [local.netweaver_ips[0], local.netweaver_ips[1]] : []
  monitoring_netweaver_targets_vip    = var.netweaver_enabled ? local.netweaver_virtual_ips : []
  drbd_cluster_vip                    = local.drbd_cluster_vip
  drbd_cluster_vip_mechanism          = "route"
  drbd_sbd_storage_type               = var.sbd_storage_type
}

module "drbd_node" {
  source               = "./modules/drbd_node"
  common_variables     = module.common_variables.configuration
  name                 = var.drbd_name
  network_domain       = var.drbd_network_domain == "" ? var.network_domain : var.drbd_network_domain
  drbd_count           = var.drbd_enabled == true ? 2 : 0
  vm_size              = var.drbd_instancetype
  availability_zones   = data.aws_availability_zones.available.names
  os_image             = local.drbd_os_image
  os_owner             = local.drbd_os_owner
  vpc_id               = local.vpc_id
  subnet_address_range = local.drbd_subnet_address_range
  key_name             = aws_key_pair.key-pair.key_name
  security_group_id    = local.security_group_id
  route_table_id       = aws_route_table.route-table.id
  host_ips             = local.drbd_ips
  drbd_data_disk_size  = var.drbd_data_disk_size
  drbd_data_disk_type  = var.drbd_data_disk_type
  iscsi_srv_ip         = join("", module.iscsi_server.iscsisrv_ip)
  nfs_mounting_point   = var.drbd_nfs_mounting_point
  nfs_export_name      = var.netweaver_sid
}

module "netweaver_node" {
  source               = "./modules/netweaver_node"
  common_variables     = module.common_variables.configuration
  name                 = var.netweaver_name
  network_domain       = var.netweaver_network_domain == "" ? var.network_domain : var.netweaver_network_domain
  xscs_server_count    = local.netweaver_xscs_server_count
  app_server_count     = var.netweaver_enabled ? var.netweaver_app_server_count : 0
  vm_size              = var.netweaver_instancetype
  availability_zones   = data.aws_availability_zones.available.names
  os_image             = local.netweaver_os_image
  os_owner             = local.netweaver_os_owner
  vpc_id               = local.vpc_id
  subnet_address_range = local.netweaver_subnet_address_range
  key_name             = aws_key_pair.key-pair.key_name
  security_group_id    = local.security_group_id
  route_table_id       = aws_route_table.route-table.id
  efs_performance_mode = var.netweaver_efs_performance_mode
  s3_bucket            = var.netweaver_s3_bucket
  host_ips             = local.netweaver_ips
  virtual_host_ips     = local.netweaver_virtual_ips
  iscsi_srv_ip         = join("", module.iscsi_server.iscsisrv_ip)
}

module "hana_node" {
  source               = "./modules/hana_node"
  common_variables     = module.common_variables.configuration
  name                 = var.hana_name
  network_domain       = var.hana_network_domain == "" ? var.network_domain : var.hana_network_domain
  hana_count           = var.hana_count
  vm_size              = var.hana_instancetype
  availability_zones   = data.aws_availability_zones.available.names
  os_image             = local.hana_os_image
  os_owner             = local.hana_os_owner
  vpc_id               = local.vpc_id
  subnet_address_range = local.hana_subnet_address_range
  key_name             = aws_key_pair.key-pair.key_name
  security_group_id    = local.security_group_id
  route_table_id       = aws_route_table.route-table.id
  host_ips             = local.hana_ips
  hana_data_disk_type  = var.hana_data_disk_type
  hana_data_disk_size  = var.hana_data_disk_size
  iscsi_srv_ip         = join("", module.iscsi_server.iscsisrv_ip)
}

module "monitoring" {
  source             = "./modules/monitoring"
  common_variables   = module.common_variables.configuration
  name               = var.monitoring_name
  network_domain     = var.monitoring_network_domain == "" ? var.network_domain : var.monitoring_network_domain
  monitoring_enabled = var.monitoring_enabled
  vm_size            = var.monitor_instancetype
  key_name           = aws_key_pair.key-pair.key_name
  security_group_id  = local.security_group_id
  monitoring_srv_ip  = local.monitoring_ip
  availability_zones = data.aws_availability_zones.available.names
  os_image           = local.monitoring_os_image
  os_owner           = local.monitoring_os_owner
  subnet_ids         = aws_subnet.infra-subnet.*.id
  timezone           = var.timezone
}

module "iscsi_server" {
  source             = "./modules/iscsi_server"
  common_variables   = module.common_variables.configuration
  name               = var.iscsi_name
  network_domain     = var.iscsi_network_domain == "" ? var.network_domain : var.iscsi_network_domain
  iscsi_count        = local.iscsi_enabled == true ? var.iscsi_count : 0
  availability_zones = data.aws_availability_zones.available.names
  subnet_ids         = aws_subnet.infra-subnet.*.id
  os_image           = local.iscsi_os_image
  os_owner           = local.iscsi_os_owner
  vm_size            = var.iscsi_instancetype
  key_name           = aws_key_pair.key-pair.key_name
  security_group_id  = local.security_group_id
  host_ips           = local.iscsi_ips
  lun_count          = var.iscsi_lun_count
  iscsi_disk_size    = var.iscsi_disk_size
}

