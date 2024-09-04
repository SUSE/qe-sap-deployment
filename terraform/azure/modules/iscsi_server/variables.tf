variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "name" {
  description = "hostname, without the domain part"
  type        = string
}

variable "iscsi_count" {
  description = "Number of ISCSI machines to deploy"
  type        = number
}

variable "vm_size" {
  description = "The instance type of ISCSI node"
  type        = string
}

variable "os_image" {
  description = "sles4sap image used to create this module machines. Composed by 'Publisher:Offer:Sku:Version' syntax. Example: SUSE:sles-sap-15-sp2:gen2:latest"
  type        = string
}

variable "iscsi_srv_uri" {
  type    = string
  default = ""
}

variable "az_region" {
  type    = string
  default = "westeurope"
}

variable "resource_group_name" {
  type = string
}

variable "network_subnet_id" {
  type = string
}

variable "storage_account" {
  description = "Storage account name needed for the boot diagnostic"
  type        = string
}

variable "host_ips" {
  description = "List of ip addresses to set to the machines"
  type        = list(string)
}

variable "network_domain" {
  description = "hostname's network domain"
  type        = string
}

variable "iscsi_disk_size" {
  description = "Disk size in GB used to create the LUNs and partitions to be served by the ISCSI service"
  type        = number
  default     = 10
}

variable "lun_count" {
  description = "Number of LUN (logical units) to serve with the iscsi server. Each LUN can be used as a unique sbd disk"
  type        = number
  default     = 3
}
