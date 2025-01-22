locals {
  # fileexists doesn't work properly with empty strings ("")
  public_key  = var.public_key != "" ? (fileexists(var.public_key) ? file(var.public_key) : var.public_key) : ""
  private_key = var.private_key != "" ? (fileexists(var.private_key) ? file(var.private_key) : var.private_key) : ""
  authorized_keys = join(", ", formatlist("\"%s\"",
    concat(
      local.public_key != "" ? [trimspace(local.public_key)] : [],
    [for key in var.authorized_keys : trimspace(fileexists(key) ? file(key) : key)])
    )
  )

  requirements_file = "${path.module}/../../requirements.yml"
  requirements      = fileexists(local.requirements_file) ? yamlencode({ pkg_requirements : yamldecode(trimspace(file(local.requirements_file))) }) : yamlencode({ pkg_requirements : null })
}

output "configuration" {
  value = {
    provider_type               = var.provider_type
    region                      = var.region
    deployment_name             = var.deployment_name
    deployment_name_in_hostname = var.deployment_name_in_hostname
    public_key                  = local.public_key
    private_key                 = local.private_key
    authorized_keys             = var.authorized_keys
    authorized_user             = var.authorized_user
    monitoring_enabled          = var.monitoring_enabled
    monitoring_srv_ip           = var.monitoring_srv_ip
    hana = {
      instance_number                = var.hana_instance_number
      cost_optimized_instance_number = var.hana_cost_optimized_instance_number
      primary_site                   = var.hana_primary_site
      secondary_site                 = var.hana_secondary_site
      fstype                         = var.hana_fstype
      scenario_type                  = var.hana_scenario_type
      cluster_vip_mechanism          = var.hana_cluster_vip_mechanism
      cluster_vip                    = var.hana_cluster_vip
      cluster_vip_secondary          = var.hana_cluster_vip_secondary
      ha_enabled                     = var.hana_ha_enabled
      ignore_min_mem_check           = var.hana_ignore_min_mem_check
      fencing_mechanism              = var.hana_cluster_fencing_mechanism
      sbd_storage_type               = var.hana_sbd_storage_type
      scale_out_enabled              = var.hana_scale_out_enabled
      scale_out_shared_storage_type  = var.hana_scale_out_shared_storage_type
      scale_out_addhosts             = var.hana_scale_out_addhosts
      scale_out_standby_count        = var.hana_scale_out_standby_count
    }
    netweaver = {
      ha_enabled            = var.netweaver_ha_enabled
      cluster_vip_mechanism = var.netweaver_cluster_vip_mechanism
      fencing_mechanism     = var.netweaver_cluster_fencing_mechanism
      sbd_storage_type      = var.netweaver_sbd_storage_type
      sid                   = var.netweaver_sid
      ascs_instance_number  = var.netweaver_ascs_instance_number
      ers_instance_number   = var.netweaver_ers_instance_number
      pas_instance_number   = var.netweaver_pas_instance_number
      master_password       = var.netweaver_master_password
      product_id            = var.netweaver_product_id
      inst_folder           = var.netweaver_inst_folder
      extract_dir           = var.netweaver_extract_dir
      additional_dvds       = var.netweaver_additional_dvds
      nfs_share             = var.netweaver_nfs_share
      sapmnt_path           = var.netweaver_sapmnt_path
      hana_ip               = var.netweaver_hana_ip
      hana_instance_number  = var.netweaver_hana_instance_number
      hana_sr_enabled       = var.hana_ha_enabled
      shared_storage_type   = var.netweaver_shared_storage_type
    }
    monitoring = {
      hana_targets          = var.monitoring_hana_targets
      hana_targets_ha       = var.monitoring_hana_targets_ha
      hana_targets_vip      = var.monitoring_hana_targets_vip
      drbd_targets          = var.monitoring_drbd_targets
      drbd_targets_ha       = var.monitoring_drbd_targets_ha
      drbd_targets_vip      = var.monitoring_drbd_targets_vip
      netweaver_targets     = var.monitoring_netweaver_targets
      netweaver_targets_ha  = var.monitoring_netweaver_targets_ha
      netweaver_targets_vip = var.monitoring_netweaver_targets_vip
    }
    drbd = {
      cluster_vip           = var.drbd_cluster_vip
      cluster_vip_mechanism = var.drbd_cluster_vip_mechanism
      fencing_mechanism     = var.drbd_cluster_fencing_mechanism
      sbd_storage_type      = var.drbd_sbd_storage_type
    }
  }
}
