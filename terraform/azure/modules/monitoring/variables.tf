variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "name" {
  description = "hostname, without the domain part"
  type        = string
}

variable "vm_size" {
  description = "The instance type of MONITOR node"
  type        = string
}

variable "monitoring_enabled" {
  description = "enable the host to be monitored by exporters, e.g node_exporter"
  type        = bool
  default     = false
}

variable "os_image" {
  description = "sles4sap image used to create this module machines. Composed by 'Publisher:Offer:Sku:Version' syntax. Example: SUSE:sles-sap-15-sp2:gen2:latest"
  type        = string
}

variable "monitoring_uri" {
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

variable "storage_account" {
  description = "Storage account name needed for the boot diagnostic"
  type        = string
}

variable "network_domain" {
  description = "hostname's network domain"
  type        = string
}

variable "network_subnet_id" {
  type = string
}

variable "timezone" {
  description = "Timezone setting for all VMs"
  default     = "Europe/Berlin"
}

variable "monitoring_srv_ip" {
  description = "monitoring server address"
  type        = string
  default     = ""
}
