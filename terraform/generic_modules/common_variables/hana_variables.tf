variable "hana_sid" {
  description = "System identifier of the HANA system. It must be a 3 characters string (check the restrictions in the SAP documentation pages). Examples: prd, ha1"
  type        = string
  validation {
    condition = (
      can(regex("^[A-Z][A-Z0-9]{2}$", var.hana_sid))
    )
    error_message = "The HANA system identifier must be composed by 3 uppercase chars/digits string starting always with a character (there are some restricted options)."
  }
}

variable "hana_cost_optimized_sid" {
  description = "System identifier of the HANA cost-optimized system. It must be a 3 characters string (check the restrictions in the SAP documentation pages). Examples: prd, ha1"
  type        = string
  validation {
    condition = (
      can(regex("^[A-Z][A-Z0-9]{2}$", var.hana_cost_optimized_sid))
    )
    error_message = "The HANA system identifier must be composed by 3 uppercase chars/digits string starting always with a character (there are some restricted options)."
  }
}

variable "hana_instance_number" {
  description = "Instance number of the HANA system. It must be a 2 digits string. Examples: 00, 01, 10"
  type        = string
  validation {
    condition = (
      can(regex("^[0-9]{2}$", var.hana_instance_number))
    )
    error_message = "The HANA instance number must be composed by 2 digits string."
  }
}

variable "hana_cost_optimized_instance_number" {
  description = "Instance number of the HANA cost-optimized system. It must be a 2 digits string. Examples: 00, 01, 10"
  type        = string
  validation {
    condition = (
      can(regex("^[0-9]{2}$", var.hana_cost_optimized_instance_number))
    )
    error_message = "The HANA instance number must be composed by 2 digits string."
  }
}

variable "hana_primary_site" {
  description = "HANA system replication primary site name"
  type        = string
}

variable "hana_secondary_site" {
  description = "HANA system replication secondary site name"
  type        = string
}

variable "hana_fstype" {
  description = "Filesystem type used by the disk where hana is installed"
  type        = string
}

variable "hana_scenario_type" {
  description = "Deployed scenario type. Available options: performance-optimized, cost-optimized"
  type        = string
  validation {
    condition = (
      can(regex("^(performance-optimized|cost-optimized)$", var.hana_scenario_type))
    )
    error_message = "Invalid HANA scenario type. Options: performance-optimized|cost-optimized ."
  }
}

variable "hana_cluster_vip_mechanism" {
  description = "Mechanism used to manage the virtual IP address in the hana cluster."
  type        = string
}

variable "hana_cluster_vip" {
  description = "IP address used to configure the hana cluster floating IP. It must be in other subnet than the machines!"
  type        = string
}

variable "hana_cluster_vip_secondary" {
  description = "IP address used to configure the hana cluster floating IP for the secondary node in an Active/Active mode"
  type        = string
}

variable "hana_hwcct" {
  description = "Execute HANA Hardware Configuration Check Tool to bench filesystems"
  type        = bool
  default     = false
}

variable "hana_ha_enabled" {
  description = "Enable HA cluster in top of HANA system replication"
  type        = bool
}

variable "hana_ignore_min_mem_check" {
  description = "Disable the min mem check imposed by hana allowing it to run with under 24 GiB"
  type        = bool
}

variable "hana_cluster_fencing_mechanism" {
  description = "Select the HANA cluster fencing mechanism. Options: sbd"
  type        = string
}

variable "hana_sbd_storage_type" {
  description = "Choose the SBD storage type. Options: iscsi, shared-disk(this option available in Libvirt only)"
  type        = string
}

variable "hana_scale_out_enabled" {
  description = "Enable HANA scale out deployment"
  type        = bool
}

variable "hana_scale_out_shared_storage_type" {
  description = "Storage type to use for HANA scale out deployment"
  type        = string
  validation {
    condition = (
      can(regex("^(|anf|nfs)$", var.hana_scale_out_shared_storage_type))
    )
    error_message = "Invalid HANA scale out storage type. Options: anf, nfs."
  }
}

variable "hana_scale_out_addhosts" {
  type        = map(any)
  description = <<EOF
    Additional hosts to pass to HANA scale-out installation
  EOF
}

variable "hana_scale_out_standby_count" {
  description = "Number of HANA scale-out standby nodes to be deployed per site"
  type        = number
}
