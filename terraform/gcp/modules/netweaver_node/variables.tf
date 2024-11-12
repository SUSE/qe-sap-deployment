variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "name" {
  description = "hostname, without the domain part"
  type        = string
}

variable "xscs_server_count" {
  description = "Number of xscs nodes"
  type        = number
  default     = 2
}

variable "app_server_count" {
  type    = number
  default = 2
}

variable "vm_size" {
  type = string
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

variable "netweaver_software_bucket" {
  description = "gcp bucket where netweaver software is available"
  type        = string
}

variable "virtual_host_ips" {
  description = "virtual ip addresses to set to the nodes"
  type        = list(string)
}
