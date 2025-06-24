# AWS related variables

variable "aws_region" {
  description = "AWS region where the deployment machines will be created. If not provided the current configured region will be used"
  type        = string
}

variable "vpc_id" {
  description = "Id of a currently existing vpc to use in the deployment. It must have an internet gateway attached. If not provided a new one will be created."
  type        = string
  default     = ""
}

variable "security_group_id" {
  description = "Id of a currently existing security group to use in the deployment. If not provided a new one will be created"
  type        = string
  default     = ""
}

variable "vpc_address_range" {
  description = "vpc address range in CIDR notation"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition = (
      can(cidrnetmask(var.vpc_address_range))
    )
    error_message = "Must be a valid IPv4 CIDR block address."
  }
}

variable "virtual_address_range" {
  description = "address range for virtual addresses for the clusters. It must be in a different range than `vpc_address_range`"
  type        = string
  default     = "192.168.1.0/24"
  validation {
    condition = (
      can(cidrnetmask(var.virtual_address_range))
    )
    error_message = "Invalid IP range format. It must be something like: 102.168.10.5/24 ."
  }
}

variable "infra_subnet_address_range" {
  description = "Address range to create the subnet for the infrastructure (iscsi, monitoring, etc) machines. If not given the addresses will be generated based on vpc_address_range"
  type        = string
  default     = ""
}

variable "public_key" {
  description = "Content of a SSH public key or path to an already existing SSH public key. The key is only used to provision the machines and it is authorized for future accesses"
  type        = string
}

variable "authorized_keys" {
  description = "List of additional authorized SSH public keys content or path to already existing SSH public keys to access the created machines with the used admin user (cloudadmin in this case)"
  type        = list(string)
  default     = []
}

variable "admin_user" {
  description = "User name of the admin user to deploy in the provisioned machines"
  type        = string
  default     = "cloudadmin"
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

variable "os_owner" {
  description = "Default OS image owner. For BYOS images the owner usually is 'amazon'"
  type        = string
  default     = "679593333241"
}

variable "timezone" {
  description = "Timezone setting for all VMs"
  default     = "Europe/Berlin"
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
  type        = number
  default     = 2
}

variable "hana_os_image" {
  description = "sles4sap AMI image identifier or a pattern used to find the image name (e.g. suse-sles-sap-15-sp3-byos)"
  type        = string
  default     = ""
}

variable "hana_os_owner" {
  description = "OS image owner. For BYOS images the owner usually is 'amazon'"
  type        = string
  default     = ""
}

variable "hana_instancetype" {
  description = "The instance type of the hana nodes"
  type        = string
  default     = "r6i.xlarge"
}

variable "hana_subnet_address_range" {
  description = "List of address ranges to create the subnets for the hana machines. If not given the addresses will be generated based on vpc_address_range"
  type        = list(string)
  default     = []
}

variable "hana_ips" {
  description = "ip addresses to set to the HANA nodes. The first ip must be in 10.0.0.0/24 subnet and the second in 10.0.1.0/24 subnet"
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
  description = "Disk type of the disks used to store HANA database content"
  type        = string
  default     = "gp2"
}

variable "hana_data_disk_size" {
  description = "Disk size in GB for the disk used to store HANA database content"
  type        = number
  default     = 1024
}

variable "hana_fstype" {
  description = "Filesystem type used by the disk where HANA is installed"
  type        = string
  default     = "xfs"
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

variable "drbd_os_image" {
  description = "sles4sap AMI image identifier or a pattern used to find the image name (e.g. suse-sles-sap-15-sp3-byos)"
  type        = string
  default     = ""
}

variable "drbd_os_owner" {
  description = "OS image owner. For BYOS images the owner usually is 'amazon'"
  type        = string
  default     = ""
}

variable "drbd_instancetype" {
  description = "The instance type of the drbd node"
  type        = string
  default     = "t3.medium"
}

variable "drbd_cluster_vip" {
  description = "IP address used to configure the drbd cluster floating IP"
  type        = string
  default     = ""
  validation {
    condition = (
      var.drbd_cluster_vip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.drbd_cluster_vip))
    )
    error_message = "Invalid IP address format."
  }
}

variable "drbd_ips" {
  description = "ip addresses to set to the drbd cluster nodes. If it's not set the addresses will be auto generated from the provided vnet address range"
  type        = list(string)
  default     = []
  validation {
    condition = (
      can([for v in var.drbd_ips : regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", v)])
    )
    error_message = "Invalid IP address format."
  }
}

variable "drbd_subnet_address_range" {
  description = "List of address ranges to create the subnets for the drbd machines. If not given the addresses will be generated based on vpc_address_range"
  type        = list(string)
  default     = []
}

variable "drbd_data_disk_size" {
  description = "Disk size of the disks used to store drbd content"
  type        = string
  default     = "15"
}

variable "drbd_data_disk_type" {
  description = "Disk type of the disks used to store drbd content"
  type        = string
  default     = "gp2"
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

variable "drbd_nfs_mounting_point" {
  description = "Mounting point of the NFS share created in to of DRBD (`/mnt` must not be used in Azure)"
  type        = string
  default     = "/mnt_permanent/sapdata"
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

# If iscsi is selected as sbd_storage_type
# Use the next variables for advanced configuration

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
  description = "sles4sap AMI image identifier or a pattern used to find the image name (e.g. suse-sles-sap-15-sp3-byos)"
  type        = string
  default     = ""
}

variable "iscsi_os_owner" {
  description = "OS image owner. For BYOS images the owner usually is 'amazon'"
  type        = string
  default     = ""
}

variable "iscsi_instancetype" {
  description = "The instance type of the iscsi server node."
  type        = string
  default     = "t3.small"
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

variable "monitoring_os_image" {
  description = "sles4sap AMI image identifier or a pattern used to find the image name (e.g. suse-sles-sap-15-sp3-byos)"
  type        = string
  default     = ""
}

variable "monitoring_os_owner" {
  description = "OS image owner. For BYOS images the owner usually is 'amazon'"
  type        = string
  default     = ""
}

variable "monitor_instancetype" {
  description = "The instance type of the monitoring node."
  type        = string
  default     = "t3.micro"
}

variable "monitoring_srv_ip" {
  description = "monitoring server address. Must be in 10.0.0.0/24 subnet"
  type        = string
  default     = ""
  validation {
    condition = (
      var.monitoring_srv_ip == "" || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.monitoring_srv_ip))
    )
    error_message = "Invalid IP address format."
  }
}

variable "monitoring_enabled" {
  description = "enable the host to be monitored by exporters, e.g node_exporter"
  type        = bool
  default     = false
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
  description = "sles4sap AMI image identifier or a pattern used to find the image name (e.g. suse-sles-sap-15-sp3-byos)"
  type        = string
  default     = ""
}

variable "netweaver_os_owner" {
  description = "OS image owner. For BYOS images the owner usually is 'amazon'"
  type        = string
  default     = ""
}

variable "netweaver_instancetype" {
  description = "Instance type for the Netweaver machines"
  type        = string
  default     = "r5.large"
}

variable "netweaver_s3_bucket" {
  description = "S3 bucket where Netwaever installation files are stored"
  type        = string
  default     = ""
}

variable "netweaver_efs_performance_mode" {
  type        = string
  description = "Performance mode of the EFS storage used by Netweaver"
  default     = "generalPurpose"
}

variable "netweaver_subnet_address_range" {
  description = "List of address ranges to create the subnets for the netweaver machines. If not given the addresses will be generated based on vpc_address_range"
  type        = list(string)
  default     = []
}

variable "netweaver_ips" {
  description = "ip addresses to set to the netweaver cluster nodes"
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
  description = "Virtual ip addresses to set to the netweaver cluster nodes"
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
  default     = "efs"
  validation {
    condition = (
      can(regex("^(drbd|efs)$", var.netweaver_shared_storage_type))
    )
    error_message = "Invalid Netweaver shared storage type. Options: drbd|efs."
  }
}

# Testing and QA variables

# TODO: Execute HANA Hardware Configuration Check Tool to bench filesystems.
# The test takes several hours. See results in /root/hwcct_out

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

variable "ibsm_project_tag" {
  description = "IBSM tgw 'Project' tag - leave empty to disable terraform peering."
  type        = string
  default     = ""
}
