# ------------------------------------------------------------------------- #
# Stage 40 - Workload Domains
#
# Creates every workload domain declared in site.yaml. Cluster host lists
# are written as FQDNs in the site definition; this stage resolves them to
# SDDC Manager UUIDs through the stage 30 state so nothing is copied by
# hand between stages.
# ------------------------------------------------------------------------- #

locals {
  site = yamldecode(file(var.site_config))

  commissioned_host_ids = data.terraform_remote_state.host_commission.outputs.host_ids
}

data "terraform_remote_state" "host_commission" {
  backend = "local"

  config = {
    path = "${path.module}/../30-host-commission/terraform.tfstate"
  }
}

module "workload_domain" {
  source   = "../../modules/workload-domain"
  for_each = local.site.workload_domains

  name    = each.key
  vcenter = each.value.vcenter
  sso     = try(each.value.sso, null)
  nsx     = each.value.nsx

  clusters = {
    for cluster_name, cluster in each.value.clusters : cluster_name => {
      host_ids   = [for fqdn in cluster.hosts : local.commissioned_host_ids[fqdn]]
      ha_enabled = try(cluster.ha_enabled, true)
      evc_mode   = try(cluster.evc_mode, "")
      vsan       = try(cluster.vsan, {})
      vds        = try(cluster.vds, {})
      host_tep   = cluster.host_tep
    }
  }

  timeouts = try(each.value.timeouts, null)

  credentials = var.credentials[each.key]
}
