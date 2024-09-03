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
  description = "The instance type of netweaver node."
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

variable "efs_performance_mode" {
  description = "Performance mode of the EFS storage used by Netweaver"
  type        = string
  default     = "generalPurpose"
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

variable "s3_bucket" {
  description = "S3 bucket where Netwaever installation files are stored"
  type        = string
}

variable "host_ips" {
  description = "ip addresses of the machines.  The addresses must belong to the the subnet provided in subnet_address_range"
  type        = list(string)
  default     = ["10.0.2.7", "10.0.3.8", "10.0.2.9", "10.0.3.10"]
}

variable "virtual_host_ips" {
  description = "virtual ip addresses to set to the nodes. They must have a different IP range than the used range in the vpc"
  type        = list(string)
  default     = ["192.168.1.20", "192.168.1.21", "192.168.1.22", "192.168.1.23"]
}

variable "iscsi_srv_ip" {
  description = "iscsi server address"
  type        = string
}

