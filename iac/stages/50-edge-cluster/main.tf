# ------------------------------------------------------------------------- #
# Stage 50 - NSX Edge Clusters
#
# Deploys the NSX edge clusters declared in site.yaml, one per workload
# domain that needs north-south routing. Each edge cluster brings up a
# Tier-0 gateway with eBGP peering to the physical fabric.
# ------------------------------------------------------------------------- #

locals {
  site = yamldecode(file(var.site_config))
}

module "edge_cluster" {
  source   = "../../modules/edge-cluster"
  for_each = local.site.edge_clusters

  name              = each.key
  compute_cluster   = each.value.compute_cluster
  form_factor       = try(each.value.form_factor, "MEDIUM")
  high_availability = try(each.value.high_availability, "ACTIVE_ACTIVE")
  mtu               = try(each.value.mtu, 9000)

  routing            = try(each.value.routing, {})
  management_network = each.value.management_network
  edge_tep           = each.value.edge_tep
  nodes              = each.value.nodes

  skip_tep_routability_check = try(each.value.skip_tep_routability_check, false)

  timeouts = try(each.value.timeouts, null)

  credentials = var.credentials[each.key]
}
