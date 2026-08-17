# ------------------------------------------------------------------------- #
# Supervisor Module
#
# Enables vSphere Kubernetes (Workload Management) on a workload domain
# cluster using NSX networking:
#
#   * Subscribes a content library to the Kubernetes release feed
#   * Enables the Supervisor with NSX-backed ingress/egress networking
#
# Requires an NSX edge cluster with a functional Tier-0 (stage 50).
# ------------------------------------------------------------------------- #

terraform {
  required_version = ">= 1.7"

  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = ">= 2.16.0"
    }
    nsxt = {
      source  = "vmware/nsxt"
      version = ">= 3.12.0"
    }
  }
}

# --------------------------------------------------------------------------#
# Inventory discovery
# --------------------------------------------------------------------------#
data "vsphere_datacenter" "datacenter" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_storage_policy" "policy" {
  name = var.storage_policy
}

data "vsphere_distributed_virtual_switch" "vds" {
  name          = var.vds_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "management" {
  name          = var.management_network.portgroup
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "nsxt_policy_edge_cluster" "edges" {
  display_name = var.edge_cluster_name
}

# --------------------------------------------------------------------------#
# Kubernetes release content library
# --------------------------------------------------------------------------#
data "vsphere_datastore" "library_datastore" {
  name          = var.content_library.datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

resource "vsphere_content_library" "kubernetes_releases" {
  name            = var.content_library.name
  description     = "Kubernetes release images for the Supervisor (managed by Terraform)"
  storage_backing = [data.vsphere_datastore.library_datastore.id]

  subscription {
    subscription_url      = var.content_library.subscription_url
    automatic_sync        = true
    on_demand             = true
    authentication_method = "NONE"
  }
}

# --------------------------------------------------------------------------#
# Supervisor activation
# --------------------------------------------------------------------------#
resource "vsphere_supervisor" "supervisor" {
  cluster         = data.vsphere_compute_cluster.cluster.id
  storage_policy  = data.vsphere_storage_policy.policy.name
  content_library = vsphere_content_library.kubernetes_releases.id
  dvs_uuid        = data.vsphere_distributed_virtual_switch.vds.id
  edge_cluster    = data.nsxt_policy_edge_cluster.edges.id
  sizing_hint     = var.control_plane_size

  main_dns       = var.dns_servers
  worker_dns     = var.dns_servers
  main_ntp       = var.ntp_servers
  worker_ntp     = var.ntp_servers
  search_domains = [var.dns_domain]

  management_network {
    network          = data.vsphere_network.management.id
    starting_address = var.management_network.starting_address
    subnet_mask      = var.management_network.subnet_mask
    gateway          = var.management_network.gateway
    address_count    = var.management_network.address_count
  }

  ingress_cidr {
    address = split("/", var.networks.ingress_cidr)[0]
    prefix  = tonumber(split("/", var.networks.ingress_cidr)[1])
  }

  egress_cidr {
    address = split("/", var.networks.egress_cidr)[0]
    prefix  = tonumber(split("/", var.networks.egress_cidr)[1])
  }

  pod_cidr {
    address = split("/", var.networks.pod_cidr)[0]
    prefix  = tonumber(split("/", var.networks.pod_cidr)[1])
  }

  service_cidr {
    address = split("/", var.networks.service_cidr)[0]
    prefix  = tonumber(split("/", var.networks.service_cidr)[1])
  }

  dynamic "namespace" {
    for_each = var.namespaces

    content {
      name              = namespace.key
      content_libraries = [vsphere_content_library.kubernetes_releases.id]
    }
  }
}
