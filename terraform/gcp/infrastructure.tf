data "google_compute_zones" "available" {
  region = var.region
  status = "UP"
}

data "google_compute_subnetwork" "current-subnet" {
  count  = var.ip_cidr_range == "" ? 1 : 0
  name   = var.subnet_name
  region = var.region
}

locals {
  deployment_name = var.deployment_name != "" ? var.deployment_name : terraform.workspace
  # only use 2 compute zones to have an even distribution of nodes
  compute_zones = slice(data.google_compute_zones.available.names, 0, 2)

  network_link = var.vpc_name == "" ? google_compute_network.ha_network.0.self_link : format(
  "https://www.googleapis.com/compute/v1/projects/%s/global/networks/%s", var.project, var.vpc_name)
  vpc_name             = var.vpc_name == "" ? google_compute_network.ha_network.0.name : var.vpc_name
  subnet_name          = var.subnet_name == "" ? google_compute_subnetwork.ha_subnet.0.name : var.subnet_name
  subnet_address_range = var.subnet_name == "" ? var.ip_cidr_range : (var.ip_cidr_range == "" ? data.google_compute_subnetwork.current-subnet.0.ip_cidr_range : var.ip_cidr_range)

  create_firewall = var.create_firewall_rules ? 1 : 0
  ibsm_count      = (var.ibsm_vpc_name != "" && var.ibsm_subnet_name != "" && var.ibsm_subnet_region != "") ? 1 : 0
}

# Network resources: Network, Subnet
resource "google_compute_network" "ha_network" {
  count                   = var.vpc_name == "" ? 1 : 0
  name                    = "${local.deployment_name}-network"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "ha_subnet" {
  count         = var.subnet_name == "" ? 1 : 0
  name          = "${local.deployment_name}-subnet"
  network       = local.network_link
  region        = var.region
  ip_cidr_range = local.subnet_address_range
}

# Network firewall rules
# All ports open for internal traffic, in line with what google suggests for cases like 
# the load balancer and health checks. Outside traffic is only allowed through select ports.
resource "google_compute_firewall" "ha_firewall_allow_internal" {
  name          = "${local.deployment_name}-fw-internal"
  network       = local.vpc_name
  source_ranges = [local.subnet_address_range]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
}

resource "google_compute_firewall" "ha_firewall_allow_icmp" {
  count         = local.create_firewall
  name          = "${local.deployment_name}-fw-icmp"
  network       = local.vpc_name
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "ha_firewall_allow_tcp" {
  count         = local.create_firewall
  name          = "${local.deployment_name}-fw-tcp"
  network       = local.vpc_name
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3000", "7630", "9668", "9100", "9664", "9090", "9680"]
  }
}

# IBSM related network imports

data "google_compute_network" "ibsm_vpc" {
  count = local.ibsm_count
  name  = var.ibsm_vpc_name
}

data "google_compute_subnetwork" "ibsm_subnet" {
  count  = local.ibsm_count
  name   = var.ibsm_subnet_name
  region = var.ibsm_subnet_region
}

# IBSM Peering resources

# Peering from HANA VPC to ibsm VPC
resource "google_compute_network_peering" "hana_to_ibsm" {
  count = local.ibsm_count

  name                 = "${local.deployment_name}-hana-to-ibsm"
  network              = local.network_link
  peer_network         = data.google_compute_network.ibsm_vpc[0].self_link
  export_custom_routes = true
  import_custom_routes = true
}

# Peering from ibsm VPC to HANA VPC
resource "google_compute_network_peering" "ibsm_to_hana" {
  count = local.ibsm_count

  name                 = "ibsm-to-${local.deployment_name}-hana"
  network              = data.google_compute_network.ibsm_vpc[0].self_link
  peer_network         = local.network_link
  export_custom_routes = true
  import_custom_routes = true
}

# Allow internal traffic from HANA VPC to ibsm VPC
resource "google_compute_firewall" "allow_internal_from_hana" {
  count = local.ibsm_count

  name    = "${local.deployment_name}-fw-allow-from-hana"
  network = data.google_compute_network.ibsm_vpc[0].name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  source_ranges = [local.subnet_address_range]
  description   = "Allow internal traffic from HANA VPC to ibsm VPC"
}

# Allow internal traffic from ibsm VPC to HANA VPC
resource "google_compute_firewall" "allow_internal_from_ibsm" {
  count = local.ibsm_count

  name    = "${local.deployment_name}-fw-allow-from-ibsm"
  network = local.vpc_name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  source_ranges = [data.google_compute_subnetwork.ibsm_subnet[0].ip_cidr_range]
  description   = "Allow internal traffic from ibsm VPC to HANA VPC"
}

