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
  description = "sles4sap AMI image identifier or a pattern used to find the image name (e.g. suse-sles-sap-15-sp1-byos)"
  type        = string
}

variable "os_owner" {
  description = "OS image owner"
  type        = string
}

variable "network_domain" {
  description = "hostname's network domain"
  type        = string
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
}

variable "security_group_id" {
  description = "Security group id"
  type        = string
}

variable "monitoring_srv_ip" {
  description = "monitoring server address"
  type        = string
  default     = ""
}

variable "availability_zones" {
  description = "Used availability zones"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "timezone" {
  description = "Timezone setting for all VMs"
  default     = "Europe/Berlin"
}

