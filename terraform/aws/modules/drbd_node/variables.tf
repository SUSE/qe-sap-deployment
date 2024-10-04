variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "name" {
  description = "hostname, without the domain part"
  type        = string
}

variable "drbd_count" {
  description = "Number of drbd machines to create the cluster"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "The instance type of DRBD node"
  type        = string
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

variable "availability_zones" {
  description = "Used availability zones"
  type        = list(string)
}

variable "vpc_id" {
  description = "Id of the vpc used for this deployment"
  type        = string
}

variable "subnet_address_range" {
  description = "List with subnet address ranges in cidr notation to create the netweaver subnets"
  type        = list(string)
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
}

variable "security_group_id" {
  description = "Security group id"
  type        = string
}

variable "route_table_id" {
  description = "Route table id"
  type        = string
}

variable "aws_credentials" {
  description = "AWS credentials file path in local machine"
  type        = string
  default     = "~/.aws/credentials"
}

variable "aws_access_key_id" {
  type = string
}

variable "aws_secret_access_key" {
  type = string
}

variable "host_ips" {
  description = "ip addresses to set to the nodes"
  type        = list(string)
}

variable "drbd_data_disk_size" {
  description = "Disk size of the disks used to store drbd content"
  type        = string
  default     = "10"
}

variable "drbd_data_disk_type" {
  description = "Disk type of the disks used to store drbd content"
  type        = string
  default     = "gp2"
}

variable "iscsi_srv_ip" {
  description = "iscsi server address"
  type        = string
}

variable "nfs_mounting_point" {
  description = "Mounting point of the NFS share created in to of DRBD (`/mnt` must not be used in Azure)"
  type        = string
}

variable "nfs_export_name" {
  description = "Name of the created export in the NFS service. Usually, the `sid` of the SAP instances is used"
  type        = string
}
