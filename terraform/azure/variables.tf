# Azure related variables

variable "az_region" {
  description = "Azure region where the deployment machines will be created"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Already existing resource group where the infrastructure is created. If it's not set a new one will be created named rg-ha-sap-{{var.deployment_name/terraform.workspace}}"
  type        = string
  default     = ""
}

variable "vnet_name" {
  description = "Already existing virtual network name used by the created infrastructure. If it's not set a new one will be created named vnet-{{var.deployment_name/terraform.workspace}}"
  type        = string
  default     = ""
}

variable "vnet_address_range" {
  description = "vnet address range in CIDR notation (only used if the vnet is created by terraform or the user doesn't have read permissions in this resource. To use the current vnet address range set the value to an empty string)"
  type        = string
  default     = "10.74.0.0/16"
  validation {
    condition = (
      can(cidrnetmask(var.vnet_address_range))
    )
    error_message = "Must be a valid IPv4 CIDR block address."
  }
}

variable "subnet_name" {
  description = "Already existing subnet name used by the created infrastructure. If it's not set a new one will be created named snet-{{var.deployment_name/terraform.workspace}}"
  type        = string
  default     = ""
}

variable "subnet_address_range" {
  description = "subnet address range in CIDR notation (only used if the subnet is created by terraform or the user doesn't have read permissions in this resource. To use the current vnet address range set the value to an empty string)"
  type        = string
  default     = ""
  validation {
    condition = (
      var.subnet_address_range == "" || can(cidrnetmask(var.subnet_address_range))
    )
    error_message = "Must be a valid IPv4 CIDR block address."
  }
}

variable "subnet_netapp_name" {
  description = "Already existing subnet name used by the created infrastructure. If it's not set a new one will be created named snet-{{var.deployment_name/terraform.workspace}}"
  type        = string
  default     = ""
}

variable "subnet_netapp_address_range" {
  description = "subnet address range in CIDR notation (only used if the subnet is created by terraform or the user doesn't have read permissions in this resource. To use the current vnet address range set the value to an empty string)"
  type        = string
  default     = ""
  validation {
    condition = (
      var.subnet_netapp_address_range == "" || can(cidrnetmask(var.subnet_netapp_address_range))
    )
    error_message = "Must be a valid IPv4 CIDR block address."
  }
}

variable "admin_user" {
  description = "Administration user used to create the machines"
  type        = string
  default     = "cloudadmin"
  validation {
    condition = (
      var.admin_user != "admin"
    )
    error_message = "The value 'admin' cannot be used for admin_user, input a different value."
  }
}

variable "public_key" {
  description = "Content of a SSH public key or path to an already existing SSH public key. The key is only used to provision the machines and it is authorized for future accesses"
  type        = string
}

variable "authorized_keys" {
  description = "List of additional authorized SSH public keys content or path to already existing SSH public keys to access the created machines with the used admin user (admin_user variable in this case)"
  type        = list(string)
  default     = []
}

# Deployment variables
variable "deployment_name" {
  description = "Suffix string added to some of the infrastructure resources names. If it is not provided, the terraform workspace string is used as suffix"
  type        = string
  default     = ""
  validation {
    condition = (
      var.deployment_name != "default"
    )
    error_message = "Invalid deployment_name (default) ."
  }
}

variable "deployment_name_in_hostname" {
  description = "Add deployment_name as a prefix to all hostnames."
  type        = bool
  default     = false
}

variable "network_domain" {
  description = "hostname's network domain for all hosts. Can be overwritten by modules."
  type        = string
  default     = "tf.local"
}

variable "os_image" {
  description = "Default OS image for all the machines. Composed by 'Publisher:Offer:Sku:Version' syntax. Example: 'SUSE:sles-sap-15-sp3:gen2:latest'. This value is not used if the specific nodes os_image is set (e.g. hana_os_image)"
  type        = string
  default     = ""
}

variable "os_image_uri" {
  description = "Path to a custom azure image in a storage account. Used for all the machines."
  type        = string
  default     = ""
}

variable "timezone" {
  description = "Timezone setting for all VMs"
  default     = "Europe/Berlin"
}

variable "reg_code" {
  description = "If informed, register the product using SUSEConnect"
  type        = string
  default     = ""
}

variable "reg_email" {
  description = "Email used for the registration"
  default     = ""
}

# The module format must follow SUSEConnect convention:
# <module_name>/<product_version>/<architecture>
# Example: Suggested modules for SLES for SAP 15
# - sle-module-basesystem/15/x86_64
# - sle-module-desktop-applications/15/x86_64
# - sle-module-server-applications/15/x86_64
# - sle-ha/15/x86_64 (Need the same regcode as SLES for SAP)
# - sle-module-sap-applications/15/x86_64

variable "reg_additional_modules" {
  description = "Map of the modules to be registered. Module name = Regcode, when needed."
  type        = map(string)
  default     = {}
}

variable "additional_packages" {
  description = "Extra packages to be installed"
  default     = []
}

# Hana related variables
variable "hana_name" {
  description = "hostname, without the domain part"
  type        = string
  default     = "vmhana"
}

variable "hana_network_domain" {
  description = "hostname's network domain"
  type        = string
  default     = ""
}

variable "hana_count" {
  description = "Number of hana nodes"
  type        = string
  default     = "2"
}

variable "hana_os_image" {
  description = "sles4sap image used to create the HANA machines. Composed by 'Publisher:Offer:Sku:Version' syntax. Example: SUSE:sles-sap-15-sp3:gen2:latest"
  type        = string
  default     = ""
}

variable "sles4sap_uri" {
  description = "Path to a custom azure image in a storage account used to create the hana machines"
  type        = string
  default     = ""
}

# For reference:
# Standard_E4s_v3 has 4 VCPU, 32GiB RAM, 64 GiB SSD
# You could find other supported instances in Azure documentation
variable "hana_vm_size" {
  description = "VM size for the hana machine"
  type        = string
  default     = "Standard_E4s_v3"
}

variable "hana_majority_maker_vm_size" {
  description = "VM size for the HANA Majority Maker machine"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "hana_data_disks_configuration" {
  type = map(any)
  default = {
    disks_type       = "Premium_LRS,Premium_LRS,Premium_LRS,Premium_LRS,Premium_LRS,Premium_LRS,Premium_LRS"
    disks_size       = "32,32,16,16,32,64,32"
    caching          = "None,None,None,None,None,None,None"
    writeaccelerator = "false,false,false,false,false,false,false"
    # The next variables are used during the provisioning
    luns     = "0,1#2,3#4#5#6"
    names    = "data#log#shared#usrsap#backup"
    lv_sizes = "100#100#100#100#100"
    paths    = "/hana/data#/hana/log#/hana/shared#/usr/sap#/hana/backup"
  }
  description = <<EOF
    This map describes how the disks will be formatted to create the definitive configuration during the provisioning.
    disks_type, disks_size, caching and writeaccelerator are used during the disks creation. The number of elements must match in all of them
    "#" character is used to split the volume groups, while "," is used to define the logical volumes for each group
    The number of groups split by "#" must match in all of the entries
    names -> The names of the volume groups (example datalog#shared#usrsap#backup#sapmnt)
    luns  -> The luns or disks used for each volume group. The number of luns must match with the configured in the previous disks variables (example 0,1,2#3#4#5#6)
    sizes -> The size dedicated for each logical volume and folder (example 70,100#100#100#100#100)
    paths -> Folder where each volume group will be mounted (example /hana/data,/hana/log#/hana/shared#/usr/sap#/hana/backup#/sapmnt/)
  EOF
}

variable "hana_enable_accelerated_networking" {
  description = "Enable accelerated networking. This function is mandatory for certified HANA environments and are not available for all kinds of instances. Check https://docs.microsoft.com/en-us/azure/virtual-network/create-vm-accelerated-networking-cli for more details"
  type        = bool
  default     = false
}

variable "hana_ips" {
  description = "ip addresses to set to the hana nodes. If it's not set the addresses will be auto generated from the provided vnet address range"
  type        = list(string)
  default     = []
  validation {
    condition = (
      can([for v in var.hana_ips : regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", v)])
    )
    error_message = "Invalid IP address format."
  }
}

variable "cluster_ip" {
  description = "Cluster alias ip. If it's not set the address will be auto generated from the provided vnet address range"
  type        = string
  default     = ""
  validation {
    condition = (
      var.cluster_ip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.cluster_ip))
    )
    error_message = "Invalid IP address format."
  }
}

variable "hana_majority_maker_ip" {
  description = "ip address to set to the HANA Majority Maker node. If it's not set the addresses will be auto generated from the provided vnet address range"
  type        = string
  default     = ""
  validation {
    condition = (
      var.hana_majority_maker_ip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.hana_majority_maker_ip))
    )
    error_message = "Invalid IP address format."
  }
}

variable "hana_fstype" {
  description = "Filesystem type used by the disk where HANA is installed"
  type        = string
  default     = "xfs"
}

variable "hana_sid" {
  description = "System identifier of the HANA system. It must be a 3 characters string (check the restrictions in the SAP documentation pages). Examples: PRD, HA1"
  type        = string
  default     = "PRD"
}

variable "hana_cost_optimized_sid" {
  description = "System identifier of the HANA cost-optimized system. It must be a 3 characters string (check the restrictions in the SAP documentation pages). Examples: PRD, HA1"
  type        = string
  default     = "QAS"
}

variable "hana_instance_number" {
  description = "Instance number of the HANA system. It must be a 2 digits string. Examples: 00, 01, 10"
  type        = string
  default     = "00"
}

variable "hana_cost_optimized_instance_number" {
  description = "Instance number of the HANA cost-optimized system. It must be a 2 digits string. Examples: 00, 01, 10"
  type        = string
  default     = "01"
}

variable "hana_primary_site" {
  description = "HANA system replication primary site name"
  type        = string
  default     = "Site1"
}

variable "hana_secondary_site" {
  description = "HANA system replication secondary site name"
  type        = string
  default     = "Site2"
}

variable "hana_cluster_vip" {
  description = "Virtual ip for the hana cluster. If it's not set the address will be auto generated from the provided vnet address range"
  type        = string
  default     = ""
  validation {
    condition = (
      var.hana_cluster_vip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.hana_cluster_vip))
    )
    error_message = "Invalid IP address format."
  }
}

variable "hana_cluster_fencing_mechanism" {
  description = "Select the HANA cluster fencing mechanism. Options: sbd, native"
  type        = string
  default     = "sbd"
  validation {
    condition = (
      can(regex("^(sbd|native)$", var.hana_cluster_fencing_mechanism))
    )
    error_message = "Invalid HANA cluster fencing mechanism. Options: sbd|native ."
  }
}

variable "hana_ha_enabled" {
  description = "Enable HA cluster in top of HANA system replication"
  type        = bool
  default     = true
}

variable "hana_active_active" {
  description = "Enable an Active/Active HANA system replication setup"
  type        = bool
  default     = false
}

variable "hana_cluster_vip_secondary" {
  description = "IP address used to configure the hana cluster floating IP for the secondary node in an Active/Active mode. Let empty to use an auto generated address"
  type        = string
  default     = ""
  validation {
    condition = (
      var.hana_cluster_vip_secondary == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.hana_cluster_vip_secondary))
    )
    error_message = "Invalid IP address format."
  }
}

variable "hana_ignore_min_mem_check" {
  description = "Disable the min mem check imposed by hana allowing it to run with under 24 GiB"
  type        = bool
  default     = false
}

variable "scenario_type" {
  description = "Deployed scenario type. Available options: performance-optimized, cost-optimized"
  default     = "performance-optimized"
}

variable "hana_scale_out_enabled" {
  description = "Enable HANA scale out deployment"
  type        = bool
  default     = false
}

variable "hana_scale_out_shared_storage_type" {
  description = "Storage type to use for HANA scale out deployment"
  type        = string
  default     = ""
  validation {
    condition = (
      can(regex("^(|anf)$", var.hana_scale_out_shared_storage_type))
    )
    error_message = "Invalid HANA scale out storage type. Options: anf."
  }
}

variable "hana_scale_out_addhosts" {
  type        = map(any)
  default     = {}
  description = <<EOF
    Additional hosts to pass to HANA scale-out installation
  EOF
}

variable "hana_scale_out_standby_count" {
  description = "Number of HANA scale-out standby nodes to be deployed per site"
  type        = number
  default     = "1"
}

# SBD related variables
# In order to enable SBD, an ISCSI server is needed as right now is the unique option
# All the clusters will use the same mechanism

variable "sbd_storage_type" {
  description = "Choose the SBD storage type. Options: iscsi"
  type        = string
  default     = "iscsi"
  validation {
    condition = (
      can(regex("^(iscsi)$", var.sbd_storage_type))
    )
    error_message = "Invalid SBD storage type. Options: iscsi ."
  }
}

# If iscsi is selected as sbd_storage_type
# Use the next variables for advanced configuration

variable "iscsi_count" {
  description = "The number of iscsi servers to deploy"
  type        = number
  default     = 1
  validation {
    condition = (
      var.iscsi_count >= 1 && var.iscsi_count <= 3
    )
    error_message = "The number of iscsi server must be 1, 2 or 3."
  }
}

variable "iscsi_name" {
  description = "hostname, without the domain part"
  type        = string
  default     = "vmiscsi"
}

variable "iscsi_network_domain" {
  description = "hostname's network domain"
  type        = string
  default     = ""
}

variable "iscsi_os_image" {
  description = "sles4sap image used to create the ISCSI machines. Composed by 'Publisher:Offer:Sku:Version' syntax. Example: SUSE:sles-sap-15-sp3:gen2:latest"
  type        = string
  default     = ""
}

variable "iscsi_srv_uri" {
  description = "Path to a custom azure image in a storage account used to create the iscsi machines"
  type        = string
  default     = ""
}

variable "iscsi_vm_size" {
  description = "VM size for the iscsi server machine"
  type        = string
  default     = "Standard_DS1_v2"
}

variable "iscsi_srv_ip" {
  description = "iscsi server address. If it's not set the address will be auto generated from the provided vnet address range"
  type        = string
  default     = ""
  validation {
    condition = (
      var.iscsi_srv_ip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.iscsi_srv_ip))
    )
    error_message = "Invalid IP address format."
  }
}

variable "iscsi_ips" {
  description = "ip addresses to set to the iscsi nodes. If it's not set the addresses will be auto generated from the provided vnet address range.  Up to three IP addresses may be set"
  type        = list(string)
  default     = []
  validation {
    condition = (
      can([for v in var.iscsi_ips : regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", v)])
    )
    error_message = "Invalid IP address format."
  }
}

variable "iscsi_lun_count" {
  description = "Number of LUN (logical units) to serve with the iscsi server. Each LUN can be used as a unique sbd disk"
  default     = 3
}

variable "iscsi_disk_size" {
  description = "Disk size in GB used to create the LUNs and partitions to be served by the ISCSI service"
  type        = number
  default     = 10
}

# Monitoring related variables

variable "monitoring_name" {
  description = "hostname, without the domain part"
  type        = string
  default     = "vmmonitoring"
}

variable "monitoring_network_domain" {
  description = "hostname's network domain"
  type        = string
  default     = ""
}

variable "monitoring_enabled" {
  description = "Enable the host to be monitored by exporters, e.g node_exporter"
  type        = bool
  default     = false
}

variable "monitoring_vm_size" {
  description = "VM size for the monitoring machine"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "monitoring_os_image" {
  description = "sles4sap image used to create the Monitoring server machines. Composed by 'Publisher:Offer:Sku:Version' syntax. Example: SUSE:sles-sap-15-sp3:gen2:latest"
  type        = string
  default     = ""
}

variable "monitoring_uri" {
  description = "Path to a custom azure image in a storage account used to create the monitoring machines"
  type        = string
  default     = ""
}

variable "monitoring_srv_ip" {
  description = "monitoring server address. If it's not set the address will be auto generated from the provided vnet address range"
  type        = string
  default     = ""
  validation {
    condition = (
      var.monitoring_srv_ip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.monitoring_srv_ip))
    )
    error_message = "Invalid IP address format."
  }
}

# DRBD related variables

variable "drbd_name" {
  description = "hostname, without the domain part"
  type        = string
  default     = "vmdrbd"
}

variable "drbd_network_domain" {
  description = "hostname's network domain"
  type        = string
  default     = ""
}

variable "drbd_enabled" {
  description = "Enable the DRBD cluster for nfs"
  type        = bool
  default     = false
}

variable "drbd_vm_size" {
  description = "VM size for the DRBD machine"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "drbd_ips" {
  description = "ip addresses to set to the drbd cluster nodes. If it's not set the addresses will be auto generated from the provided vnet address range"
  type        = list(string)
  default     = []
}

variable "drbd_os_image" {
  description = "sles4sap image used to create the DRBD machines. Composed by 'Publisher:Offer:Sku:Version' syntax. Example: SUSE:sles-sap-15-sp3:gen2:latest"
  type        = string
  default     = ""
}

variable "drbd_image_uri" {
  description = "Path to a custom azure image in a storage account used to create the drbd machines"
  type        = string
  default     = ""
}

variable "drbd_cluster_vip" {
  description = "Virtual ip for the drbd cluster. If it's not set the address will be auto generated from the provided vnet address range"
  type        = string
  default     = ""
  validation {
    condition = (
      var.drbd_cluster_vip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.drbd_cluster_vip))
    )
    error_message = "Invalid IP address format."
  }
}

variable "drbd_cluster_fencing_mechanism" {
  description = "Select the DRBD cluster fencing mechanism. Options: sbd, native"
  type        = string
  default     = "sbd"
  validation {
    condition = (
      can(regex("^(sbd|native)$", var.drbd_cluster_fencing_mechanism))
    )
    error_message = "Invalid DRBD cluster fencing mechanism. Options: sbd|native ."
  }
}

variable "drbd_nfs_mounting_point" {
  description = "Mounting point of the NFS share created in to of DRBD (`/mnt` must not be used in Azure)"
  type        = string
  default     = "/mnt_permanent/sapdata"
}

# Netweaver related variables

variable "netweaver_name" {
  description = "hostname, without the domain part"
  type        = string
  default     = "vmnetweaver"
}

variable "netweaver_network_domain" {
  description = "hostname's network domain"
  type        = string
  default     = ""
}

variable "netweaver_enabled" {
  description = "Enable SAP Netweaver cluster deployment"
  type        = bool
  default     = false
}

variable "netweaver_app_server_count" {
  description = "Number of PAS/AAS servers (1 PAS and the rest will be AAS). 0 means that the PAS is installed in the same machines as the ASCS"
  type        = number
  default     = 2
}

variable "netweaver_os_image" {
  description = "sles4sap image used to create the Netweaver machines. Composed by 'Publisher:Offer:Sku:Version' syntax. Example: SUSE:sles-sap-15-sp3:gen2:latest"
  type        = string
  default     = ""
}

variable "netweaver_image_uri" {
  description = "Path to a custom azure image in a storage account used to create the netweaver machines"
  type        = string
  default     = ""
}

variable "netweaver_xscs_vm_size" {
  description = "VM size for the Netweaver xSCS machines"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "netweaver_app_vm_size" {
  description = "VM size for the Netweaver application servers"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "netweaver_data_disk_type" {
  description = "Disk type of the disks used to store netweaver content in the application servers"
  type        = string
  default     = "Premium_LRS"
}

variable "netweaver_data_disk_size" {
  description = "Size of the netweaver data disks in the application servers, informed in GB"
  type        = string
  default     = "128"
}

variable "netweaver_data_disk_caching" {
  description = "Disk caching of the disks used to store netweaver content in the application servers"
  type        = string
  default     = "ReadWrite"
}

variable "netweaver_xscs_accelerated_networking" {
  description = "Enable accelerated networking for netweaver xSCS machines"
  type        = bool
  default     = false
}

variable "netweaver_app_accelerated_networking" {
  description = "Enable accelerated networking for netweaver application server machines"
  type        = bool
  default     = false
}

variable "netweaver_ips" {
  description = "ip addresses to set to the netweaver cluster nodes. If it's not set the addresses will be auto generated from the provided vnet address range"
  type        = list(string)
  default     = []
  validation {
    condition = (
      can([for v in var.netweaver_ips : regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", v)])
    )
    error_message = "Invalid IP address format."
  }
}

variable "netweaver_virtual_ips" {
  description = "Virtual ip addresses to set to the netweaver cluster nodes. If it's not set the addresses will be auto generated from the provided vnet address range"
  type        = list(string)
  default     = []
  validation {
    condition = (
      can([for v in var.netweaver_virtual_ips : regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", v)])
    )
    error_message = "Invalid IP address format."
  }
}

variable "netweaver_sid" {
  description = "System identifier of the Netweaver installation (e.g.: HA1 or PRD)"
  type        = string
  default     = "HA1"
}

variable "netweaver_ascs_instance_number" {
  description = "Instance number of the ASCS system. It must be a 2 digits string. Examples: 00, 01, 10"
  type        = string
  default     = "00"
}

variable "netweaver_ers_instance_number" {
  description = "Instance number of the ERS system. It must be a 2 digits string. Examples: 00, 01, 10"
  type        = string
  default     = "10"
}

variable "netweaver_pas_instance_number" {
  description = "Instance number of the PAS system. It must be a 2 digits string. Examples: 00, 01, 10"
  type        = string
  default     = "01"
}

variable "netweaver_master_password" {
  description = "Master password for the Netweaver system (sidadm user included)"
  type        = string
  default     = ""
}

variable "netweaver_cluster_fencing_mechanism" {
  description = "Select the Netweaver cluster fencing mechanism. Options: sbd, native"
  type        = string
  default     = "sbd"
  validation {
    condition = (
      can(regex("^(native|sbd)$", var.netweaver_cluster_fencing_mechanism))
    )
    error_message = "Invalid Netweaver cluster fencing mechanism. Options: native|sbd ."
  }
}

variable "netweaver_nfs_share" {
  description = "URL of the NFS share where /sapmnt and /usr/sap/{sid}/SYS will be mounted. This folder must have the sapmnt and usrsapsys folders. This parameter can be omitted if drbd_enabled is set to true, as a HA nfs share will be deployed by the project. Finally, if it is not used or set empty, these folders are created locally (for single machine deployments)"
  type        = string
  default     = ""
}

variable "netweaver_sapmnt_path" {
  description = "Path where sapmnt folder is stored"
  type        = string
  default     = "/sapmnt"
}

variable "netweaver_product_id" {
  description = "Netweaver installation product. Even though the module is about Netweaver, it can be used to install other SAP instances like S4/HANA"
  type        = string
  default     = "NW750.HDB.ABAPHA"
}

variable "netweaver_inst_folder" {
  description = "Folder where SAP Netweaver installation files are mounted"
  type        = string
  default     = "/sapmedia/NW"
}

variable "netweaver_extract_dir" {
  description = "Extraction path for Netweaver media archives of SWPM and netweaver additional dvds"
  type        = string
  default     = "/sapmedia_extract/NW"
}

variable "netweaver_additional_dvds" {
  description = "Software folder with additional SAP software needed to install netweaver (NW export folder and HANA HDB client for example), path relative from the `netweaver_inst_media` mounted point"
  type        = list(any)
  default     = []
}

variable "netweaver_ha_enabled" {
  description = "Enable HA cluster in top of Netweaver ASCS and ERS instances"
  type        = bool
  default     = true
}

variable "netweaver_shared_storage_type" {
  description = "shared Storage type to use for Netweaver deployment"
  type        = string
  default     = "drbd"
  validation {
    condition = (
      can(regex("^(|drbd|anf)$", var.netweaver_shared_storage_type))
    )
    error_message = "Invalid Netweaver shared storage type. Options: drbd|anf."
  }
}

# Testing and QA variables

# Execute HANA Hardware Configuration Check Tool to bench filesystems.
# The test takes several hours. See results in /root/hwcct_out
variable "hwcct" {
  description = "Execute HANA Hardware Configuration Check Tool to bench filesystems"
  type        = bool
  default     = false
}

# native fencing
variable "fence_agent_app_id" {
  description = "ID of the azure service principal / application that is used for native fencing."
  type        = string
  default     = ""
}

variable "fence_agent_client_secret" {
  description = "Secret for the azure service principal / application that is used for native fencing."
  type        = string
  default     = ""
}

# ANF shared storage
variable "anf_account_name" {
  description = "Name of ANF Accounts"
  type        = string
  default     = ""
}

variable "anf_pool_name" {
  description = "Name if ANF Pool"
  type        = string
  default     = ""
}

variable "anf_pool_size" {
  description = "pool size for ANF shared Storage. Must be >=4 TB"
  type        = number
  default     = "4"
}

variable "anf_pool_service_level" {
  description = "service level for ANF shared Storage"
  type        = string
  default     = "Ultra"
  validation {
    condition = (
      can(regex("^(Standard|Premium|Ultra)$", var.anf_pool_service_level))
    )
    error_message = "Invalid ANF Pool service level. Options: Standard|Premium|Ultra."
  }
}

variable "netweaver_anf_quota_sapmnt" {
  description = "Quota for ANF shared storage volume Netweaver"
  type        = number
  default     = "1000"
}

variable "hana_scale_out_anf_quota_data" {
  description = "Quota for ANF shared storage volume HANA scale-out data"
  type        = number
  default     = "2000"
}

variable "hana_scale_out_anf_quota_log" {
  description = "Quota for ANF shared storage volume HANA scale-out log"
  type        = number
  default     = "2000"
}

variable "hana_scale_out_anf_quota_backup" {
  description = "Quota for ANF shared storage volume HANA scale-out backup"
  type        = number
  default     = "1000"
}

variable "hana_scale_out_anf_quota_shared" {
  description = "Quota for ANF shared storage volume HANA scale-out shared"
  type        = number
  default     = "2000"
}

variable "hana_remote_python" {
  description = "Remote python interpreter that Ansible will use on HANA nodes"
  type        = string
  default     = "/usr/bin/python3"
}

variable "iscsi_remote_python" {
  description = "Remote python interpreter that Ansible will use on iscsi nodes"
  type        = string
  default     = "/usr/bin/python3"
}

