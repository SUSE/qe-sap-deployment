
data "azurerm_subscription" "current" {
}

data "azurerm_virtual_network" "mynet" {
  count               = var.vnet_name != "" && var.vnet_address_range == "" ? 1 : 0
  name                = var.vnet_name
  resource_group_name = local.resource_group_name
}

data "azurerm_subnet" "mysubnet" {
  count                = var.subnet_name != "" && var.subnet_address_range == "" ? 1 : 0
  name                 = var.subnet_name
  virtual_network_name = local.vnet_name
  resource_group_name  = local.resource_group_name
}

locals {
  deployment_name = var.deployment_name != "" ? var.deployment_name : terraform.workspace

  resource_group_name = var.resource_group_name == "" ? azurerm_resource_group.myrg.0.name : var.resource_group_name
  vnet_name           = var.vnet_name == "" ? azurerm_virtual_network.mynet.0.name : var.vnet_name

  subnet_id = (
    var.subnet_name == "" ?
    azurerm_subnet.mysubnet.0.id :
    format(
      "/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Network/virtualNetworks/%s/subnets/%s",
      data.azurerm_subscription.current.subscription_id,
      var.resource_group_name,
      var.vnet_name,
      var.subnet_name
    )
  )

  subnet_netapp_id = (
    ((var.hana_scale_out_shared_storage_type == "anf" || var.netweaver_shared_storage_type == "anf") && var.subnet_netapp_name == "") ?
    azurerm_subnet.mysubnet-netapp.0.id :
    format(
      "/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Network/virtualNetworks/%s/subnets/%s",
      data.azurerm_subscription.current.subscription_id,
      var.resource_group_name,
      var.vnet_name,
      var.subnet_netapp_name
    )
  )

  shared_storage_anf = (var.hana_scale_out_shared_storage_type == "anf" || var.netweaver_shared_storage_type == "anf") ? 1 : 0
  anf_account_name   = local.shared_storage_anf == 1 ? (var.anf_account_name == "" ? azurerm_netapp_account.mynetapp-acc.0.name : var.anf_account_name) : ""
  anf_pool_name      = local.shared_storage_anf == 1 ? (var.anf_pool_name == "" ? azurerm_netapp_pool.mynetapp-pool.0.name : var.anf_pool_name) : ""
}

# Azure resource group and storage account resources. Create one here
# if not provided by external.
resource "azurerm_resource_group" "myrg" {
  count    = var.resource_group_name == "" ? 1 : 0
  name     = "rg-ha-sap-${local.deployment_name}"
  location = var.az_region
}

resource "azurerm_storage_account" "mytfstorageacc" {
  name                     = "stdiag${lower(local.deployment_name)}"
  resource_group_name      = local.resource_group_name
  location                 = var.az_region
  account_replication_type = "LRS"
  account_tier             = "Standard"

  tags = {
    workspace = local.deployment_name
  }
}

# Network resources: Virtual Network, Subnet, Netapp Subnet
resource "azurerm_virtual_network" "mynet" {
  count               = var.vnet_name == "" ? 1 : 0
  name                = "vnet-${lower(local.deployment_name)}"
  address_space       = [local.vnet_address_range]
  location            = var.az_region
  resource_group_name = local.resource_group_name

  tags = {
    workspace = local.deployment_name
  }
}

resource "azurerm_subnet" "mysubnet" {
  count                = var.subnet_name == "" ? 1 : 0
  name                 = "snet-${lower(local.deployment_name)}"
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [local.subnet_address_range]
}

resource "azurerm_subnet_network_security_group_association" "mysubnet" {
  subnet_id                 = local.subnet_id
  network_security_group_id = azurerm_network_security_group.mysecgroup.id
}

resource "azurerm_subnet_route_table_association" "mysubnet" {
  subnet_id      = local.subnet_id
  route_table_id = azurerm_route_table.myroutes.id
}

# Subnet route table

resource "azurerm_route_table" "myroutes" {
  name                = "route-${lower(local.deployment_name)}"
  location            = var.az_region
  resource_group_name = local.resource_group_name

  route {
    name           = "default"
    address_prefix = local.vnet_address_range
    next_hop_type  = "VnetLocal"
  }

  tags = {
    workspace = local.deployment_name
  }
}

# Azure Netapp Files resources (see README for ANF setup)
data "azurerm_subnet" "mysubnet-netapp" {
  count                = var.subnet_netapp_name != "" && var.subnet_netapp_address_range == "" ? 1 : 0
  name                 = var.subnet_netapp_name
  virtual_network_name = local.vnet_name
  resource_group_name  = local.resource_group_name
}

resource "azurerm_subnet" "mysubnet-netapp" {

  count                = var.subnet_netapp_name == "" ? local.shared_storage_anf : 0
  name                 = "snet-netapp-${lower(local.deployment_name)}"
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [local.subnet_netapp_address_range]

  delegation {
    name = "netapp"

    service_delegation {
      name    = "Microsoft.Netapp/volumes"
      actions = ["Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_netapp_account" "mynetapp-acc" {
  count               = local.shared_storage_anf
  name                = "netapp-acc-${lower(local.deployment_name)}"
  resource_group_name = local.resource_group_name
  location            = var.az_region
}

resource "azurerm_netapp_pool" "mynetapp-pool" {
  count               = local.shared_storage_anf
  name                = "netapp-pool-${lower(local.deployment_name)}"
  account_name        = local.anf_account_name
  location            = var.az_region
  resource_group_name = local.resource_group_name
  service_level       = var.anf_pool_service_level
  size_in_tb          = var.anf_pool_size
}

# Security group

resource "azurerm_network_security_group" "mysecgroup" {
  name                = "nsg-${lower(local.deployment_name)}"
  location            = var.az_region
  resource_group_name = local.resource_group_name
  security_rule {
    name                       = "OUTALL"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "LOCAL"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = local.vnet_address_range
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HAWK"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7630"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  // monitoring rules
  security_rule {
    name                       = "nodeExporter"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "hanadbExporter"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9668"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "haExporter"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9664"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "SAPHostExporter"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9680"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "prometheus"
    priority                   = 1009
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "grafana"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    workspace = local.deployment_name
  }
}

# IBSM
data "azurerm_virtual_network" "ibsm_vnet" {
  count               = (var.ibsm_rg != "" && var.ibsm_vnet_name != "") ? 1 : 0
  name                = var.ibsm_vnet_name
  resource_group_name = var.ibsm_rg
}

# Peering from the IBSM vnet to deployment vnet
resource "azurerm_virtual_network_peering" "ibsm_to_target" {
  count = (var.ibsm_rg != "" && var.ibsm_vnet_name != "") ? 1 : 0

  name                      = "${var.ibsm_vnet_name}-${local.vnet_name}"
  resource_group_name       = var.ibsm_rg
  virtual_network_name      = data.azurerm_virtual_network.ibsm_vnet[0].name
  remote_virtual_network_id = azurerm_virtual_network.mynet[0].id

  allow_virtual_network_access = true
}

# Peering from deployment vnet back to the IBSM vnet
resource "azurerm_virtual_network_peering" "target_to_ibsm" {
  count = (var.ibsm_rg != "" && var.ibsm_vnet_name != "") ? 1 : 0

  name                      = "${local.vnet_name}-${var.ibsm_vnet_name}"
  resource_group_name       = local.resource_group_name
  virtual_network_name      = azurerm_virtual_network.mynet[0].name
  remote_virtual_network_id = data.azurerm_virtual_network.ibsm_vnet[0].id

  allow_virtual_network_access = true
}
