variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "name" {
  description = "hostname, without the domain part"
  type        = string
}

variable "monitoring_enabled" {
  description = "enable the host to be monitored by exporters, e.g node_exporter"
  type        = bool
  default     = false
}

variable "os_image" {
  description = "sles4sap image used to create this module machines."
  type        = string
}

variable "compute_zones" {
  description = "gcp compute zones data"
  type        = list(string)
}

variable "network_subnet_name" {
  description = "Subnet name to attach the network interface of the nodes"
  type        = string
}

variable "network_domain" {
  description = "hostname's network domain"
  type        = string
}

variable "monitoring_srv_ip" {
  description = "monitoring server address"
  type        = string
  default     = ""
}
