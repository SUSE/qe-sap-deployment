# GCP related variables

variable "project" {
  description = "GCP project name where the infrastructure will be created"
  type        = string
}

variable "region" {
  description = "GCP region where the deployment machines will be created"
  type        = string
}

variable "gcp_credentials_file" {
  description = "GCP credentials file path in local machine"
  type        = string
}

variable "vpc_name" {
  description = "Already existing vpc name used by the created infrastructure. If it's not set a new one will be created"
  type        = string
  default     = ""
}

variable "subnet_name" {
  description = "Already existing subnet name used by the created infrastructure. If it's not set a new one will be created"
  type        = string
  default     = ""
}

variable "create_firewall_rules" {
  description = "Create predefined firewall rules for the connections outside the network (internal connections are always allowed). Set to false if custom firewall rules are already created for the used network"
  type        = bool
  default     = true
}

variable "ip_cidr_range" {
  description = "Internal IPv4 range of the created network"
  type        = string
  default     = "10.0.0.0/24"
  validation {
    condition = (
      can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.ip_cidr_range))
    )
    error_message = "Invalid IP range format. It must be something like: 102.168.10.5/24 ."
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
  description = "List of additional authorized SSH public keys content or path to already existing SSH public keys to access the created machines with the used admin user (root in this case)"
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
  default     = true
}

variable "network_domain" {
  description = "hostname's network domain for all hosts. Can be overwritten by modules."
  type        = string
  default     = "tf.local"
}

variable "os_image" {
  description = "Default OS image for all the machines. This value is not used if the specific nodes os_image is set (e.g. hana_os_image)"
  type        = string
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

variable "machine_type" {
  description = "The instance type of the hana nodes"
  type        = string
  default     = "n1-highmem-32"
}

variable "hana_os_image" {
  description = "The image used to create the hana machines"
  type        = string
  default     = ""
}

variable "hana_ips" {
  description = "ip addresses to set to the hana nodes. They must be in the same network addresses range defined in `ip_cidr_range`"
  type        = list(string)
  default     = []
  validation {
    condition = (
      can([for v in var.hana_ips : regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", v)])
    )
    error_message = "Invalid IP address format."
  }
}

variable "hana_data_disk_type" {
  description = "Disk type of the disks used to store hana database content"
  type        = string
  default     = "pd-ssd"
}

variable "hana_data_disk_size" {
  description = "Disk size of the disks used to store hana database content"
  type        = string
  default     = "350"
}

variable "hana_log_disk_type" {
  description = "Disk type of the disks used to store hana log"
  type        = string
  default     = "pd-ssd"
}

variable "hana_log_disk_size" {
  description = "Disk size of the disks used to store hana log"
  type        = string
  default     = "128"
}

variable "hana_backup_disk_type" {
  description = "Disk type of the disks used to store hana database backup content"
  type        = string
  default     = "pd-standard"
}

variable "hana_backup_disk_size" {
  description = "Disk size of the disks used to store hana database backup content"
  type        = string
  default     = "128"
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

variable "hana_cluster_vip_mechanism" {
  description = "Mechanism used to manage the virtual IP address in the hana cluster. Options: load-balancer, route"
  type        = string
  default     = "load-balancer"
  validation {
    condition = (
      can(regex("^(load-balancer|route)$", var.hana_cluster_vip_mechanism))
    )
    error_message = "Invalid HANA cluster vip mechanism. Options: load-balancer|route ."
  }
}

variable "hana_cluster_vip" {
  description = "IP address used to configure the hana cluster floating IP. It must be in other subnet than the machines!"
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
  default     = "native"
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
  description = "Storage type to use for HANA scale out deployment - not supported for this cloud provider yet"
  type        = string
  default     = ""
  validation {
    condition = (
      can(regex("^(|)$", var.hana_scale_out_shared_storage_type))
    )
    error_message = "Invalid HANA scale out storage type. Options: none."
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

variable "monitoring_srv_ip" {
  description = "Monitoring server address"
  type        = string
  default     = ""
  validation {
    condition = (
      var.monitoring_srv_ip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.monitoring_srv_ip))
    )
    error_message = "Invalid IP address format."
  }
}

variable "monitoring_os_image" {
  description = "The image used to create the monitoring machines"
  type        = string
  default     = ""
}

variable "monitoring_enabled" {
  description = "Enable the host to be monitored by exporters, e.g node_exporter"
  type        = bool
  default     = false
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

variable "iscsi_os_image" {
  description = "The image used to create the iscsi machines"
  type        = string
  default     = ""
}

variable "machine_type_iscsi_server" {
  description = "The instance type of the iscsi nodes"
  type        = string
  default     = "custom-1-2048"
}

variable "iscsi_ips" {
  description = "IP for iSCSI server. It must be in the same network addresses range defined in `ip_cidr_range`"
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

variable "drbd_machine_type" {
  description = "VM size for the DRBD machine"
  type        = string
  default     = "n1-standard-4"
}

variable "drbd_os_image" {
  description = "The image used to create the DRBD machines"
  type        = string
  default     = ""
}

variable "drbd_data_disk_size" {
  description = "Disk size of the disks used to store DRBD content"
  type        = string
  default     = "10"
}

variable "drbd_data_disk_type" {
  description = "Disk type of the disks used to store DRBD content"
  type        = string
  default     = "pd-standard"
}

variable "drbd_ips" {
  description = "ip addresses to set to the drbd cluster nodes. They must be in the same network addresses range defined in `ip_cidr_range`"
  type        = list(string)
  default     = []
  validation {
    condition = (
      can([for v in var.drbd_ips : regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", v)])
    )
    error_message = "Invalid IP address format."
  }
}

variable "drbd_cluster_vip" {
  description = "IP address used to configure the drbd cluster floating IP. It must be in other subnet than the machines!"
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
  default     = "native"
  validation {
    condition = (
      can(regex("^(sbd|native)$", var.drbd_cluster_fencing_mechanism))
    )
    error_message = "Invalid DRBD cluster fencing mechanism. Options: sbd|native ."
  }
}

variable "drbd_cluster_vip_mechanism" {
  description = "Mechanism used to manage the virtual IP address in the drbd cluster. Options: load-balancer, route"
  type        = string
  default     = "load-balancer"
  validation {
    condition = (
      can(regex("^(load-balancer|route)$", var.drbd_cluster_vip_mechanism))
    )
    error_message = "Invalid DRBD cluster vip mechanism. Options: load-balancer|route ."
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
  description = "Enable netweaver cluster deployment"
  type        = bool
  default     = false
}

variable "netweaver_app_server_count" {
  description = "Number of PAS/AAS servers (1 PAS and the rest will be AAS). 0 means that the PAS is installed in the same machines as the ASCS"
  type        = number
  default     = 2
}

variable "netweaver_machine_type" {
  description = "The instance type of the netweaver nodes"
  type        = string
  default     = "n1-highmem-8"
}

variable "netweaver_os_image" {
  description = "The image used to create the netweaver machines"
  type        = string
  default     = ""
}

variable "netweaver_software_bucket" {
  description = "GCP storage bucket that contains the netweaver installation files"
  type        = string
  default     = ""
}

variable "netweaver_ips" {
  description = "ip addresses to set to the netweaver cluster nodes. They must be in the same network addresses range defined in `ip_cidr_range`"
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
  description = "virtual ip addresses to set to the nodes. The first 2 nodes will be part of the HA cluster so they addresses must be outside of the subnet mask"
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
  default     = "native"
  validation {
    condition = (
      can(regex("^(native|sbd)$", var.netweaver_cluster_fencing_mechanism))
    )
    error_message = "Invalid Netweaver cluster fending mechanism. Options: native|sbd ."
  }
}

variable "netweaver_cluster_vip_mechanism" {
  description = "Mechanism used to manage the virtual IP address in the netweaver cluster. Options: load-balancer, route"
  type        = string
  default     = "load-balancer"
  validation {
    condition = (
      can(regex("^(load-balancer|route)$", var.netweaver_cluster_vip_mechanism))
    )
    error_message = "Invalid Netweaver cluster vip mechanism. Options: load-balancer|route ."
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
  description = "shared Storage type to use for Netweaver deployment - not supported yet for this cloud provider yet"
  type        = string
  default     = ""
  validation {
    condition = (
      can(regex("^(|)$", var.netweaver_shared_storage_type))
    )
    error_message = "Invalid Netweaver shared storage type. Options: none."
  }
}

# Testing and QA variables

# Execute HANA Hardware Configuration Check Tool to bench filesystems.
# The test takes several hours. See results in /root/hwcct_out and in global log file /var/log/salt-result.log.
variable "hwcct" {
  description = "Execute HANA Hardware Configuration Check Tool to bench filesystems"
  type        = bool
  default     = false
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
