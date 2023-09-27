# iscsi server network configuration

locals {
  provisioning_addresses = data.azurerm_public_ip.iscsisrv.*.ip_address
  hostname               = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

resource "azurerm_network_interface" "iscsisrv" {
  count               = var.iscsi_count
  name                = "nic-iscsisrv${format("%02d", count.index + 1)}"
  location            = var.az_region
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconf-primary"
    subnet_id                     = var.network_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = element(var.host_ips, count.index)
    public_ip_address_id          = element(azurerm_public_ip.iscsisrv.*.id, count.index)
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

resource "azurerm_public_ip" "iscsisrv" {
  count                   = var.iscsi_count
  name                    = "pip-iscsisrv${format("%02d", count.index + 1)}"
  location                = var.az_region
  resource_group_name     = var.resource_group_name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

# iscsi server custom image. only available if iscsi_image_uri is used

resource "azurerm_image" "iscsi_srv" {
  count               = var.iscsi_srv_uri != "" ? 1 : 0
  name                = "IscsiSrvImg"
  location            = var.az_region
  resource_group_name = var.resource_group_name

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = var.iscsi_srv_uri
    size_gb  = "32"
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

# iSCSI server VM
module "os_image_reference" {
  source           = "../../modules/os_image_reference"
  os_image         = var.os_image
  os_image_srv_uri = var.iscsi_srv_uri != ""
}

resource "azurerm_managed_disk" "iscsisrv_data" {
  count                = var.iscsi_count
  name                 = "disk-iscsisrv${format("%02d", count.index + 1)}-Data01"
  location             = var.az_region
  resource_group_name  = var.resource_group_name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.iscsi_disk_size
}

resource "azurerm_virtual_machine_data_disk_attachment" "iscsisrv_data" {
  count              = var.iscsi_count
  managed_disk_id    = azurerm_managed_disk.iscsisrv_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.iscsisrv[count.index].id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_linux_virtual_machine" "iscsisrv" {
  count                 = var.iscsi_count
  name                  = "${var.name}${format("%02d", count.index + 1)}"
  location              = var.az_region
  network_interface_ids = [element(azurerm_network_interface.iscsisrv.*.id, count.index)]
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
    name                 = "disk-iscsisrv${format("%02d", count.index + 1)}-Os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  dynamic "source_image_reference" {
    for_each = var.iscsi_srv_uri != "" ? [] : [1]
    content {
      publisher = module.os_image_reference.publisher
      offer     = module.os_image_reference.offer
      sku       = module.os_image_reference.sku
      version   = module.os_image_reference.version
    }
  }

  source_image_id = var.iscsi_srv_uri != "" ? join(",", azurerm_image.iscsi_srv.*.id) : null

  boot_diagnostics {
    storage_account_uri = var.storage_account
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}
