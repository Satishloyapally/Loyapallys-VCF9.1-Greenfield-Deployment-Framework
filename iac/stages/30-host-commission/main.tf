# ------------------------------------------------------------------------- #
# Stage 30 - Host Commissioning
#
# Commissions the workload-capacity ESXi hosts listed in site.yaml into the
# SDDC Manager free-host inventory. The resulting host UUIDs are exported
# for the workload-domain stage, so UUIDs never need to be copied by hand.
# ------------------------------------------------------------------------- #

locals {
  site = yamldecode(file(var.site_config))
}

module "hosts" {
  source = "../../modules/host-commission"

  hosts              = local.site.commission_hosts
  esxi_root_password = var.esxi_root_password
}
