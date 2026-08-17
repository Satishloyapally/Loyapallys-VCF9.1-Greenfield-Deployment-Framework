# ------------------------------------------------------------------------- #
# Network Pool Module
#
# Creates an SDDC Manager network pool. Pools hand out vMotion / vSAN / NFS
# addresses to hosts as they are commissioned, so define one pool per
# rack or per workload cluster boundary.
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

resource "vcf_network_pool" "pool" {
  name = var.name

  dynamic "network" {
    for_each = var.networks

    content {
      type    = network.key
      vlan_id = network.value.vlan_id
      mtu     = network.value.mtu
      subnet  = network.value.subnet
      mask    = network.value.mask
      gateway = network.value.gateway

      ip_pools {
        start = network.value.range.start
        end   = network.value.range.end
      }
    }
  }
}
