# monitoring network configuration

locals {
  provisioning_addresses = data.azurerm_public_ip.monitoring.*.ip_address
  hostname               = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

resource "azurerm_network_interface" "monitoring" {
  name                = "nic-monitoring"
  count               = var.monitoring_enabled == true ? 1 : 0
  location            = var.az_region
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconf-primary"
    subnet_id                     = var.network_subnet_id
    private_ip_address_allocation = "static"
    private_ip_address            = var.monitoring_srv_ip
    public_ip_address_id          = azurerm_public_ip.monitoring.0.id
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

resource "azurerm_public_ip" "monitoring" {
  name                    = "pip-monitoring"
  count                   = var.monitoring_enabled ? 1 : 0
  location                = var.az_region
  resource_group_name     = var.resource_group_name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

# monitoring custom image. only available if monitoring_image_uri is used

resource "azurerm_image" "monitoring" {
  count               = var.monitoring_uri != "" ? 1 : 0
  name                = "monitoringSrvImg"
  location            = var.az_region
  resource_group_name = var.resource_group_name

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = var.monitoring_uri
    size_gb  = "32"
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

# monitoring VM
module "os_image_reference" {
  source           = "../../modules/os_image_reference"
  os_image         = var.os_image
  os_image_srv_uri = var.monitoring_uri != ""
}

resource "azurerm_managed_disk" "monitoring_data" {
  count                = var.monitoring_enabled == true ? 1 : 0
  name                 = "disk-monitoring-Data01"
  location             = var.az_region
  resource_group_name  = var.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "monitoring_data" {
  count              = var.monitoring_enabled == true ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.monitoring_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.monitoring[count.index].id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_linux_virtual_machine" "monitoring" {
  name                  = var.name
  count                 = var.monitoring_enabled == true ? 1 : 0
  location              = var.az_region
  network_interface_ids = [azurerm_network_interface.monitoring[0].id]
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  # os_profile replaced with top level arguments in azurerm_linux_virtual_machine
  admin_username                  = var.common_variables["authorized_user"]
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.common_variables["authorized_user"]
    public_key = var.common_variables["public_key"]
  }

  os_disk {
    name                 = "disk-monitoring-Os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  dynamic "source_image_reference" {
    for_each = var.monitoring_uri != "" ? [] : [1]
    content {
      publisher = module.os_image_reference.publisher
      offer     = module.os_image_reference.offer
      sku       = module.os_image_reference.sku
      version   = module.os_image_reference.version
    }
  }

  source_image_id = var.monitoring_uri != "" ? azurerm_image.monitoring.0.id : null

  boot_diagnostics {
    storage_account_uri = var.storage_account
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}
