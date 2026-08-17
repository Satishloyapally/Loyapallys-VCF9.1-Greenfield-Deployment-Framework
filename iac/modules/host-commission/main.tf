# ------------------------------------------------------------------------- #
# Host Commission Module
#
# Commissions ESXi hosts into the SDDC Manager free-host inventory so they
# can later be consumed by workload domains and clusters. Hosts are keyed
# by FQDN and mapped to the network pool that serves their rack.
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

resource "vcf_host" "host" {
  for_each = var.hosts

  fqdn              = each.key
  username          = "root"
  password          = var.esxi_root_password
  storage_type      = each.value.storage_type
  network_pool_name = each.value.network_pool
}
