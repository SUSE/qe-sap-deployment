variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "availability_zones" {
  description = "Used availability zones"
  type        = list(string)
}

variable "subnet_ids" {
  description = "Subnet ids to attach the machines network interface"
  type        = list(string)
}

variable "os_image" {
  description = "sles4sap AMI image identifier or a pattern used to find the image name (e.g. suse-sles-sap-15-sp1-byos)"
  type        = string
}

variable "os_owner" {
  description = "OS image owner"
  type        = string
}

variable "name" {
  description = "hostname, without the domain part"
  type        = string
}

variable "vm_size" {
  description = "The instance type of iscsi server node."
  type        = string
}

variable "network_domain" {
  description = "hostname's network domain"
  type        = string
}

variable "iscsi_count" {
  description = "Number of iscsi machines to deploy"
  type        = number
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
}

variable "security_group_id" {
  description = "Security group id"
  type        = string
}

variable "host_ips" {
  description = "List of ip addresses to set to the machines"
  type        = list(string)
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
