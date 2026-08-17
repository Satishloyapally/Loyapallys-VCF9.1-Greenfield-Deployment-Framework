# ------------------------------------------------------------------------- #
# Management Domain (Bring-up) Module
#
# Drives the VCF 9.1 Installer appliance to perform the full greenfield
# bring-up of a VCF fleet:
#
#   * Validates and prepares the seed ESXi hosts
#   * Deploys the management vCenter, NSX Manager cluster and SDDC Manager
#   * Optionally deploys the VCF fleet components:
#     VCF Operations, Operations Collector, Fleet Management and Automation
#
# The module is intentionally opinionated: sane defaults are applied for
# everything that does not have to differ between sites, so a caller only
# supplies real design decisions (addressing, hostnames, sizes).
# ------------------------------------------------------------------------- #

terraform {
  required_version = ">= 1.7"

  required_providers {
    vcf = {
      source  = "vmware/vcf"
      version = ">= 0.18.0"
    }
  }
}

locals {
  # Networks that carry an IP range get an include block; the rest do not.
  ranged_networks = { for k, v in var.networks : k => v if v.ip_range != null }
}

resource "vcf_instance" "management_domain" {
  instance_id = var.instance_name
  version     = var.vcf_version

  ceip_enabled                   = var.ceip_enabled
  fips_enabled                   = var.fips_enabled
  skip_esx_thumbprint_validation = var.skip_host_thumbprint_validation

  management_pool_name = "${var.cluster.name}-np"

  dns {
    domain                = var.dns_domain
    name_server           = var.dns_servers[0]
    secondary_name_server = length(var.dns_servers) > 1 ? var.dns_servers[1] : null
  }

  ntp_servers = var.ntp_servers

  # ----------------------------------------------------------------------- #
  # Physical networks used by the management cluster
  # ----------------------------------------------------------------------- #
  dynamic "network" {
    for_each = var.networks

    content {
      network_type   = network.key
      port_group_key = network.value.portgroup
      vlan_id        = network.value.vlan_id
      subnet         = network.value.subnet
      gateway        = network.value.gateway
      mtu            = network.value.mtu
      active_uplinks = var.dvs.uplinks

      dynamic "include_ip_address_ranges" {
        for_each = network.value.ip_range != null ? [network.value.ip_range] : []

        content {
          start_ip_address = include_ip_address_ranges.value.start
          end_ip_address   = include_ip_address_ranges.value.end
        }
      }
    }
  }

  # ----------------------------------------------------------------------- #
  # Core appliances
  # ----------------------------------------------------------------------- #
  sddc_manager {
    hostname            = var.sddc_manager.hostname
    root_user_password  = var.credentials.sddc_manager_root_password
    ssh_password        = var.credentials.sddc_manager_ssh_password
    local_user_password = var.credentials.sddc_manager_admin_password
  }

  vcenter {
    vcenter_hostname      = var.vcenter.hostname
    vm_size               = var.vcenter.size
    storage_size          = var.vcenter.storage_size
    root_vcenter_password = var.credentials.vcenter_root_password
  }

  nsx {
    vip_fqdn                  = var.nsx.vip_fqdn
    nsx_manager_size          = var.nsx.manager_size
    transport_vlan_id         = var.nsx.transport_vlan_id
    root_nsx_manager_password = var.credentials.nsx_root_password
    nsx_admin_password        = var.credentials.nsx_admin_password
    nsx_audit_password        = var.credentials.nsx_audit_password

    dynamic "nsx_manager" {
      for_each = var.nsx.manager_hostnames

      content {
        hostname = nsx_manager.value
      }
    }

    ip_address_pool {
      name                           = "${var.cluster.name}-host-tep-pool"
      description                    = "Host TEP addresses for the management cluster"
      ignore_unavailable_nsx_cluster = true

      subnet {
        cidr    = var.nsx.host_tep_pool.cidr
        gateway = var.nsx.host_tep_pool.gateway

        ip_address_pool_range {
          start = var.nsx.host_tep_pool.range.start
          end   = var.nsx.host_tep_pool.range.end
        }
      }
    }
  }

  # ----------------------------------------------------------------------- #
  # Optional fleet components
  # ----------------------------------------------------------------------- #
  dynamic "operations" {
    for_each = var.operations != null ? [var.operations] : []

    content {
      appliance_size      = operations.value.appliance_size
      load_balancer_fqdn  = operations.value.load_balancer_fqdn
      admin_user_password = var.credentials.operations_admin_password

      dynamic "node" {
        for_each = operations.value.nodes

        content {
          hostname           = node.value.hostname
          type               = node.value.type
          root_user_password = var.credentials.appliance_root_password
        }
      }
    }
  }

  dynamic "operations_collector" {
    for_each = var.operations_collector != null ? [var.operations_collector] : []

    content {
      hostname           = operations_collector.value.hostname
      appliance_size     = operations_collector.value.appliance_size
      root_user_password = var.credentials.appliance_root_password
    }
  }

  dynamic "operations_fleet_management" {
    for_each = var.fleet_management != null ? [var.fleet_management] : []

    content {
      hostname            = operations_fleet_management.value.hostname
      root_user_password  = var.credentials.appliance_root_password
      admin_user_password = var.credentials.fleet_management_admin_password
    }
  }

  dynamic "automation" {
    for_each = var.automation != null ? [var.automation] : []

    content {
      hostname              = automation.value.hostname
      node_prefix           = automation.value.node_prefix
      ip_pool               = automation.value.ip_pool
      internal_cluster_cidr = automation.value.internal_cluster_cidr
      admin_user_password   = var.credentials.automation_admin_password
    }
  }

  # ----------------------------------------------------------------------- #
  # Management cluster: compute, storage, networking
  # ----------------------------------------------------------------------- #
  cluster {
    cluster_name    = var.cluster.name
    datacenter_name = var.cluster.datacenter
  }

  vsan {
    datastore_name       = coalesce(var.vsan.datastore_name, "${var.cluster.name}-vsan")
    esa_enabled          = var.vsan.esa_enabled
    vsan_dedup           = var.vsan.dedup_enabled
    failures_to_tolerate = var.vsan.failures_to_tolerate
  }

  dvs {
    dvs_name = var.dvs.name
    mtu      = var.dvs.mtu
    networks = keys(var.networks)

    dynamic "vmnic_mapping" {
      for_each = var.dvs.uplinks

      content {
        uplink = vmnic_mapping.value
        vmnic  = var.dvs.vmnic_mapping[vmnic_mapping.value]
      }
    }

    dynamic "nioc" {
      for_each = var.dvs.nioc_shares

      content {
        traffic_type = nioc.key
        value        = nioc.value
      }
    }

    nsxt_switch_config {
      host_switch_operational_mode = var.dvs.nsx_switch_mode
      ip_assignment_type           = "STATIC"

      transport_zones {
        name           = "${var.instance_name}-overlay-tz"
        transport_type = "OVERLAY"
      }
    }

    nsx_teaming {
      policy         = var.nsx.teaming_policy
      active_uplinks = var.dvs.uplinks
    }
  }

  dynamic "host" {
    for_each = var.hosts

    content {
      hostname = host.value

      credentials {
        username = "root"
        password = var.credentials.esxi_root_password
      }
    }
  }

  # Bring-up is a multi-hour operation; expose the create timeout so callers
  # can extend it beyond the provider default for large or slow fabrics.
  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []

    content {
      create = var.timeouts.create
    }
  }
}
