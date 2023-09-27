locals {
  provisioning_address = data.azurerm_public_ip.majority_maker.*.ip_address
}


# majority maker network configuration

resource "azurerm_network_interface" "majority_maker" {
  count                         = var.node_count
  name                          = "nic-${var.name}majority_maker"
  location                      = var.az_region
  resource_group_name           = var.resource_group_name
  enable_accelerated_networking = var.enable_accelerated_networking

  ip_configuration {
    name                          = "ipconf-primary"
    subnet_id                     = var.network_subnet_id
    private_ip_address_allocation = "static"
    private_ip_address            = var.majority_maker_ip
    public_ip_address_id          = element(azurerm_public_ip.majority_maker.*.id, count.index)
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

resource "azurerm_public_ip" "majority_maker" {
  count                   = var.node_count
  name                    = "pip-${var.name}majority_maker"
  location                = var.az_region
  resource_group_name     = var.resource_group_name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

# majority maker instance

resource "azurerm_image" "sles4sap" {
  count               = var.sles4sap_uri != "" ? 1 : 0
  name                = "BVSles4SapImg"
  location            = var.az_region
  resource_group_name = var.resource_group_name

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = var.sles4sap_uri
    size_gb  = "32"
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

module "os_image_reference" {
  source           = "../../modules/os_image_reference"
  os_image         = var.os_image
  os_image_srv_uri = var.sles4sap_uri != ""
}

resource "azurerm_linux_virtual_machine" "majority_maker" {
  count                 = var.node_count
  name                  = "vm${var.name}mm"
  location              = var.az_region
  network_interface_ids = [element(azurerm_network_interface.majority_maker.*.id, count.index)]
  resource_group_name   = var.resource_group_name
  # availability_set_id              = var.common_variables["hana"]["ha_enabled"] ? azurerm_availability_set.hana-availability-set[0].id : null
  size = var.vm_size

  # os_profile replaced with top level arguments in azurerm_linux_virtual_machine
  admin_username                  = var.common_variables["authorized_user"]
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.common_variables["authorized_user"]
    public_key = var.common_variables["public_key"]
  }

  os_disk {
    name                 = "disk-${var.name}majority_maker-Os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  dynamic "source_image_reference" {
    for_each = var.sles4sap_uri != "" ? [] : [1]
    content {
      publisher = module.os_image_reference.publisher
      offer     = module.os_image_reference.offer
      sku       = module.os_image_reference.sku
      version   = module.os_image_reference.version
    }
  }

  source_image_id = var.sles4sap_uri != "" ? join(",", azurerm_image.sles4sap.*.id) : null

  boot_diagnostics {
    storage_account_uri = var.storage_account
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}
