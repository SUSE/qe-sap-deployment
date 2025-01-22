variable "provider_type" {
  description = "Used provider for the deployment"
  type        = string
  validation {
    condition = (
      can(regex("^(aws|azure|gcp|libvirt|openstack)$", var.provider_type))
    )
    error_message = "Invalid provider type. Options: aws|azure|gcp|libvirt|openstack ."
  }
}

variable "region" {
  description = "Region where the machines are created"
  type        = string
  default     = ""
}

variable "deployment_name" {
  description = "Suffix string added to some of the infrastructure resources names. If it is not provided, the terraform workspace string is used as suffix"
  type        = string
  default     = ""
}

variable "deployment_name_in_hostname" {
  description = "Add deployment_name as a prefix to all hostnames."
  type        = bool
}

variable "public_key" {
  description = "Content of a SSH public key or path to an already existing SSH public key. The key is only used to provision the machines and it is authorized for future accesses"
  type        = string
  default     = ""
}

variable "private_key" {
  description = "Content of a SSH private key or path to an already existing SSH private key. The key is only used to provision the machines. It is not uploaded to the machines in any case"
  type        = string
  default     = ""
}

variable "authorized_keys" {
  description = "List of additional authorized SSH public keys content or path to already existing SSH public keys to access the created machines with the used admin user (admin_user variable in this case)"
  type        = list(string)
  default     = []
}

variable "authorized_user" {
  description = "Authorized user for the given authorized_keys"
  type        = string
}

variable "monitoring_enabled" {
  description = "Enable centralized monitoring via Prometheus/Grafana/Loki"
  type        = bool
  default     = false
}

variable "monitoring_srv_ip" {
  description = "Monitoring server address"
  type        = string
  default     = ""
}

