variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "name" {
  description = "hostname, without the domain part"
  type        = string
}

variable "drbd_count" {
  description = "Number of DRBD machines to deploy"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "The instance type of DRBD node"
  type        = string
}

variable "os_image" {
  description = "sles4sap image used to create this module machines."
  type        = string
}

variable "compute_zones" {
  description = "gcp compute zones data"
  type        = list(string)
}

variable "network_name" {
  description = "Network to attach the static route (temporary solution)"
  type        = string
}

variable "network_subnet_name" {
  description = "Subnet name to attach the network interface of the nodes"
  type        = string
}


variable "network_domain" {
  description = "hostname's network domain"
  type        = string
}

variable "drbd_data_disk_size" {
  description = "drbd data disk size"
  type        = string
  default     = "10"
}

variable "drbd_data_disk_type" {
  description = "drbd data disk type"
  type        = string
  default     = "pd-standard"
}

variable "gcp_credentials_file" {
  description = "Path to your local gcp credentials file"
  type        = string
}

variable "host_ips" {
  description = "ip addresses to set to the nodes"
  type        = list(string)
}

variable "nfs_mounting_point" {
  description = "Mounting point of the NFS share created in to of DRBD (`/mnt` must not be used in Azure)"
  type        = string
}

variable "nfs_export_name" {
  description = "Name of the created export in the NFS service. Usually, the `sid` of the SAP instances is used"
  type        = string
}

variable "iscsi_srv_ip" {
  description = "iscsi server address"
  type        = list(string)
}

