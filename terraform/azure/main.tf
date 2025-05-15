locals {
  netweaver_xscs_server_count = var.netweaver_enabled ? (var.netweaver_ha_enabled ? 2 : 1) : 0
  netweaver_count             = var.netweaver_enabled ? local.netweaver_xscs_server_count + var.netweaver_app_server_count : 0

  # Check if iscsi server has to be created
  use_sbd       = var.hana_cluster_fencing_mechanism == "sbd" || var.drbd_cluster_fencing_mechanism == "sbd" || var.netweaver_cluster_fencing_mechanism == "sbd"
  iscsi_enabled = var.sbd_storage_type == "iscsi" && ((var.hana_count > 1 && var.hana_ha_enabled) || var.drbd_enabled || (local.netweaver_count > 1 && var.netweaver_ha_enabled)) && local.use_sbd ? true : false

  # Obtain machines os_image value
  hana_os_image       = var.hana_os_image != "" ? var.hana_os_image : var.os_image
  iscsi_os_image      = var.iscsi_os_image != "" ? var.iscsi_os_image : var.os_image
  monitoring_os_image = var.monitoring_os_image != "" ? var.monitoring_os_image : var.os_image
  drbd_os_image       = var.drbd_os_image != "" ? var.drbd_os_image : var.os_image
  netweaver_os_image  = var.netweaver_os_image != "" ? var.netweaver_os_image : var.os_image

  hana_os_image_uri       = var.sles4sap_uri != "" ? var.sles4sap_uri : var.os_image_uri
  iscsi_os_image_uri      = var.iscsi_srv_uri != "" ? var.iscsi_srv_uri : var.os_image_uri
  monitoring_os_image_uri = var.monitoring_uri != "" ? var.monitoring_uri : var.os_image_uri
  drbd_os_image_uri       = var.drbd_image_uri != "" ? var.drbd_image_uri : var.os_image_uri
  netweaver_os_image_uri  = var.netweaver_image_uri != "" ? var.netweaver_image_uri : var.os_image_uri

  # Netweaver password checking
  # If Netweaver is not enabled, a dummy password is passed to pass the variable validation and not require
  # a password in this case
  # Otherwise, the validation will fail unless a correct password is provided
  netweaver_master_password = var.netweaver_enabled ? var.netweaver_master_password : "DummyPassword1234"
}

module "common_variables" {
  source                              = "../generic_modules/common_variables"
  provider_type                       = "azure"
  deployment_name                     = local.deployment_name
  deployment_name_in_hostname         = var.deployment_name_in_hostname
  public_key                          = var.public_key
  authorized_keys                     = var.authorized_keys
  authorized_user                     = var.admin_user
  monitoring_enabled                  = var.monitoring_enabled
  monitoring_srv_ip                   = var.monitoring_enabled ? local.monitoring_srv_ip : ""
  hana_hwcct                          = var.hwcct
  hana_instance_number                = var.hana_instance_number
  hana_cost_optimized_instance_number = var.hana_cost_optimized_instance_number
  hana_primary_site                   = var.hana_primary_site
  hana_secondary_site                 = var.hana_secondary_site
  hana_fstype                         = var.hana_fstype
  hana_scenario_type                  = var.scenario_type
  hana_cluster_vip_mechanism          = "load-balancer"
  hana_cluster_vip                    = var.hana_ha_enabled ? local.hana_cluster_vip : ""
  hana_cluster_vip_secondary          = var.hana_active_active ? local.hana_cluster_vip_secondary : ""
  hana_ha_enabled                     = var.hana_ha_enabled
  hana_ignore_min_mem_check           = var.hana_ignore_min_mem_check
  hana_cluster_fencing_mechanism      = var.hana_cluster_fencing_mechanism
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
  netweaver_cluster_vip_mechanism     = "load-balancer"
  netweaver_cluster_fencing_mechanism = var.netweaver_cluster_fencing_mechanism
  netweaver_sbd_storage_type          = var.sbd_storage_type
  netweaver_shared_storage_type       = var.netweaver_shared_storage_type
  monitoring_hana_targets             = var.hana_scale_out_enabled ? concat(local.hana_ips, [local.hana_majority_maker_ip]) : local.hana_ips
  monitoring_hana_targets_ha          = var.hana_ha_enabled ? (var.hana_scale_out_enabled ? concat(local.hana_ips, [local.hana_majority_maker_ip]) : local.hana_ips) : []
  monitoring_hana_targets_vip         = var.hana_ha_enabled ? [local.hana_cluster_vip] : [local.hana_ips[0]] # we use the vip for HA scenario and 1st hana machine for non HA to target the active hana instance
  monitoring_drbd_targets             = var.drbd_enabled ? local.drbd_ips : []
  monitoring_drbd_targets_ha          = var.drbd_enabled ? local.drbd_ips : []
  monitoring_drbd_targets_vip         = var.drbd_enabled ? [local.drbd_cluster_vip] : []
  monitoring_netweaver_targets        = var.netweaver_enabled ? local.netweaver_ips : []
  monitoring_netweaver_targets_ha     = var.netweaver_enabled && var.netweaver_ha_enabled ? [local.netweaver_ips[0], local.netweaver_ips[1]] : []
  monitoring_netweaver_targets_vip    = var.netweaver_enabled ? local.netweaver_virtual_ips : []
  drbd_cluster_vip                    = local.drbd_cluster_vip
  drbd_cluster_vip_mechanism          = "load-balancer"
  drbd_cluster_fencing_mechanism      = var.drbd_cluster_fencing_mechanism
  drbd_sbd_storage_type               = var.sbd_storage_type
}

module "drbd_node" {
  source              = "./modules/drbd_node"
  common_variables    = module.common_variables.configuration
  name                = var.drbd_name
  network_domain      = var.drbd_network_domain == "" ? var.network_domain : var.drbd_network_domain
  az_region           = var.az_region
  drbd_count          = var.drbd_enabled == true ? 2 : 0
  vm_size             = var.drbd_vm_size
  drbd_image_uri      = local.drbd_os_image_uri
  os_image            = local.drbd_os_image
  resource_group_name = local.resource_group_name
  network_subnet_id   = local.subnet_id
  storage_account     = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  host_ips            = local.drbd_ips
  iscsi_srv_ip        = join("", module.iscsi_server.iscsisrv_ip)
  nfs_mounting_point  = var.drbd_nfs_mounting_point
  nfs_export_name     = var.netweaver_sid
  # only used by azure fence agent (native fencing)
  subscription_id           = data.azurerm_subscription.current.subscription_id
  tenant_id                 = data.azurerm_subscription.current.tenant_id
  fence_agent_app_id        = var.fence_agent_app_id
  fence_agent_client_secret = var.fence_agent_client_secret
}

module "netweaver_node" {
  source                      = "./modules/netweaver_node"
  common_variables            = module.common_variables.configuration
  name                        = var.netweaver_name
  network_domain              = var.netweaver_network_domain == "" ? var.network_domain : var.netweaver_network_domain
  az_region                   = var.az_region
  xscs_server_count           = local.netweaver_xscs_server_count
  app_server_count            = var.netweaver_enabled ? var.netweaver_app_server_count : 0
  xscs_vm_size                = var.netweaver_xscs_vm_size
  app_vm_size                 = var.netweaver_app_vm_size
  xscs_accelerated_networking = var.netweaver_xscs_accelerated_networking
  app_accelerated_networking  = var.netweaver_app_accelerated_networking
  data_disk_caching           = var.netweaver_data_disk_caching
  data_disk_size              = var.netweaver_data_disk_size
  data_disk_type              = var.netweaver_data_disk_type
  netweaver_image_uri         = local.netweaver_os_image_uri
  os_image                    = local.netweaver_os_image
  resource_group_name         = local.resource_group_name
  network_subnet_id           = local.subnet_id
  network_subnet_netapp_id    = local.subnet_netapp_id
  storage_account             = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  ascs_instance_number        = var.netweaver_ascs_instance_number
  ers_instance_number         = var.netweaver_ers_instance_number
  host_ips                    = local.netweaver_ips
  virtual_host_ips            = local.netweaver_virtual_ips
  iscsi_srv_ip                = join("", module.iscsi_server.iscsisrv_ip)
  # ANF specific
  anf_account_name           = local.anf_account_name
  anf_pool_name              = local.anf_pool_name
  anf_pool_service_level     = var.anf_pool_service_level
  netweaver_anf_quota_sapmnt = var.netweaver_anf_quota_sapmnt
  # only used by azure fence agent (native fencing)
  subscription_id           = data.azurerm_subscription.current.subscription_id
  tenant_id                 = data.azurerm_subscription.current.tenant_id
  fence_agent_app_id        = var.fence_agent_app_id
  fence_agent_client_secret = var.fence_agent_client_secret
}

module "hana_node" {
  source                        = "./modules/hana_node"
  common_variables              = module.common_variables.configuration
  name                          = var.hana_name
  network_domain                = var.hana_network_domain == "" ? var.network_domain : var.hana_network_domain
  az_region                     = var.az_region
  hana_count                    = var.hana_count
  vm_size                       = var.hana_vm_size
  host_ips                      = local.hana_ips
  resource_group_name           = local.resource_group_name
  network_subnet_id             = local.subnet_id
  network_subnet_netapp_id      = local.subnet_netapp_id
  storage_account               = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  enable_accelerated_networking = var.hana_enable_accelerated_networking
  sles4sap_uri                  = local.hana_os_image_uri
  hana_instance_number          = var.hana_instance_number
  hana_data_disks_configuration = var.hana_data_disks_configuration
  os_image                      = local.hana_os_image
  iscsi_srv_ip                  = join("", module.iscsi_server.iscsisrv_ip)
  # ANF specific
  anf_account_name                = local.anf_account_name
  anf_pool_name                   = local.anf_pool_name
  anf_pool_service_level          = var.anf_pool_service_level
  hana_scale_out_anf_quota_data   = var.hana_scale_out_anf_quota_data
  hana_scale_out_anf_quota_log    = var.hana_scale_out_anf_quota_log
  hana_scale_out_anf_quota_backup = var.hana_scale_out_anf_quota_backup
  hana_scale_out_anf_quota_shared = var.hana_scale_out_anf_quota_shared
  # only used by azure fence agent (native fencing)
  subscription_id           = data.azurerm_subscription.current.subscription_id
  tenant_id                 = data.azurerm_subscription.current.tenant_id
  fence_agent_app_id        = var.fence_agent_app_id
  fence_agent_client_secret = var.fence_agent_client_secret
  # passed to majority_maker module
  majority_maker_vm_size = var.hana_majority_maker_vm_size
  majority_maker_ip      = local.hana_majority_maker_ip
}

module "monitoring" {
  source              = "./modules/monitoring"
  common_variables    = module.common_variables.configuration
  name                = var.monitoring_name
  network_domain      = var.monitoring_network_domain == "" ? var.network_domain : var.monitoring_network_domain
  monitoring_enabled  = var.monitoring_enabled
  az_region           = var.az_region
  vm_size             = var.monitoring_vm_size
  resource_group_name = local.resource_group_name
  network_subnet_id   = local.subnet_id
  storage_account     = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  monitoring_uri      = local.monitoring_os_image_uri
  os_image            = local.monitoring_os_image
  monitoring_srv_ip   = local.monitoring_srv_ip
}

module "iscsi_server" {
  source              = "./modules/iscsi_server"
  common_variables    = module.common_variables.configuration
  name                = var.iscsi_name
  network_domain      = var.iscsi_network_domain == "" ? var.network_domain : var.iscsi_network_domain
  iscsi_count         = local.iscsi_enabled ? var.iscsi_count : 0
  az_region           = var.az_region
  vm_size             = var.iscsi_vm_size
  resource_group_name = local.resource_group_name
  network_subnet_id   = local.subnet_id
  storage_account     = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  iscsi_srv_uri       = local.iscsi_os_image_uri
  os_image            = local.iscsi_os_image
  host_ips            = local.iscsi_ips
  lun_count           = var.iscsi_lun_count
  iscsi_disk_size     = var.iscsi_disk_size
}
