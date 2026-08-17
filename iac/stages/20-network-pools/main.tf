# ------------------------------------------------------------------------- #
# Stage 20 - Network Pools
#
# Creates the SDDC Manager network pools that hand out vMotion / vSAN / NFS
# addresses to hosts as they are commissioned. One pool per rack or per
# workload cluster boundary; add pools in site.yaml, never here.
# ------------------------------------------------------------------------- #

locals {
  site = yamldecode(file(var.site_config))
}

module "network_pool" {
  source   = "../../modules/network-pool"
  for_each = local.site.network_pools

  name     = each.key
  networks = each.value
}
