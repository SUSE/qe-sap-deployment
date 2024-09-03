variable "common_variables" {
  description = "Output of the common_variables module"
}

variable "name" {
  description = "hostname, without the domain part"
  type        = string
}

variable "network_domain" {
  description = "hostname's network domain"
  type        = string
}

variable "hana_count" {
  description = "Number of hana nodes"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "The instance type of hana node"
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
  description = "ip addresses to set to the nodes. The first ip must be in 10.0.0.0/24 subnet and the second in 10.0.1.0/24 subnet"
  type        = list(string)
}

variable "hana_data_disk_type" {
  type    = string
  default = "gp2"
}

variable "hana_data_disk_size" {
  description = "Disk size in GB for the disk used to store HANA database content"
  type        = number
}

variable "hana_data_disks_configuration" {
  type = list(object({
    device_name = string
    disk_type   = string
    disk_size   = number
  }))
  default = [{
    device_name = "/dev/sdb"
    disk_type   = "gp2"
    disk_size   = 128
    },
    {
      device_name = "/dev/sdc"
      disk_type   = "gp2"
      disk_size   = 128
    },
    {
      device_name = "/dev/sdd"
      disk_type   = "gp2"
      disk_size   = 128
    },
    {
      device_name = "/dev/sde"
      disk_type   = "gp2"
      disk_size   = 128
    },
    {
      device_name = "/dev/sdf"
      disk_type   = "gp2"
      disk_size   = 128
    },
    {
      device_name = "/dev/sdg"
      disk_type   = "gp2"
      disk_size   = 128
    },
    {
      device_name = "/dev/sdh"
      disk_type   = "gp2"
      disk_size   = 128
  }]
  description = <<EOF
    This list of object describes how the disks will be created for AWS HANA Nodes and is very similar to Azure. Ansible expects seven disks for HANA
    2 disks for /hana/data (would be three in a real production system)
    2 disks for /hana/log
    1 disk  for /hana/shared
    1 disk  for /usr/sap
    1 disk  for /backup
    The default size for all disks is 128GiB, which provides a balance of performance and cost
  EOF
}

variable "iscsi_srv_ip" {
  description = "iscsi server address"
  type        = string
}

variable "reg_code" {
  description = "If informed, register the product using SUSEConnect"
  default     = ""
}

variable "os_image" {
  description = "sles4sap AMI image identifier or a pattern used to find the image name (e.g. suse-sles-sap-15-sp1-byos)"
  type        = string
}

variable "os_owner" {
  description = "OS image owner"
  type        = string
}
