variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "name" {
  description = "hostname, without the domain part"
  type        = string
}

variable "hana_count" {
  description = "Number of HANA machines to deploy"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "The instance type of HANA node"
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

variable "host_ips" {
  description = "ip addresses to set to the nodes"
  type        = list(string)
}

variable "iscsi_srv_ip" {
  description = "iscsi server address"
  type        = list(string)
}

variable "hana_data_disk_type" {
  description = "Disk type of the hana data volume"
  type        = string
  default     = "pd-ssd"
}

variable "hana_data_disk_size" {
  description = "Disk size of the data volume"
  type        = string
  default     = "350"
}

variable "hana_log_disk_type" {
  description = "Disk type of the hana log volume"
  type        = string
  default     = "pd-ssd"
}

variable "hana_log_disk_size" {
  description = "Disk size of the hana log volume"
  type        = string
  default     = "128"
}

variable "hana_shared_disk_type" {
  description = "Disk type of /hana/shared"
  type        = string
  default     = "pd-standard"
}

variable "hana_shared_disk_size" {
  description = "Disk size of /hana/shared"
  type        = string
  default     = "128"
}

variable "hana_backup_disk_type" {
  description = "Disk type of the disk used for /hana/backup"
  type        = string
  default     = "pd-standard"
}

variable "hana_backup_disk_size" {
  description = "Disk size of the disk used for /hana/backup"
  type        = string
  default     = "256"
}

variable "hana_usr_sap_disk_type" {
  description = "Disk type of the disk used for /usr/sap"
  type        = string
  default     = "pd-standard"
}

variable "hana_usr_sap_disk_size" {
  description = "Disk size of the disk used for /hana/backup"
  type        = string
  default     = "64"
}
