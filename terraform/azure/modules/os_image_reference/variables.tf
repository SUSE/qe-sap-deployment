variable "os_image" {
  description = "sles4sap image used to create the this module machines. Composed by 'Publisher:Offer:Sku:Version' syntax. Example: SUSE:sles-sap-15-sp2:gen2:latest"
  type        = string
}

variable "os_image_srv_uri" {
  description = "image_uri is used"
  type        = bool
  default     = false
}

