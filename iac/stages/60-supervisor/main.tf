# ------------------------------------------------------------------------- #
# Stage 60 - Supervisor (vSphere Kubernetes)
#
# Enables Workload Management on one workload cluster. Because the vSphere
# and NSX providers must each point at a single endpoint, this stage
# handles one Supervisor per apply; select which one with -var or let it
# default to the first entry in site.yaml.
#
#   terraform apply -var supervisor_name=dc01-wld-01-sup01
# ------------------------------------------------------------------------- #

locals {
  site = yamldecode(file(var.site_config))

  supervisor_name = coalesce(var.supervisor_name, keys(local.site.supervisors)[0])
  supervisor      = local.site.supervisors[local.supervisor_name]

  # The workload domain reference resolves the vCenter and NSX endpoints.
  workload_domain = local.site.workload_domains[local.supervisor.workload_domain]
}

module "supervisor" {
  source = "../../modules/supervisor"

  datacenter        = local.supervisor.datacenter
  cluster           = local.supervisor.cluster
  vds_name          = local.supervisor.vds_name
  edge_cluster_name = local.supervisor.edge_cluster

  storage_policy     = try(local.supervisor.storage_policy, "vSAN Default Storage Policy")
  control_plane_size = try(local.supervisor.control_plane_size, "SMALL")

  dns_domain  = local.site.site.dns_domain
  dns_servers = local.site.site.dns_servers
  ntp_servers = local.site.site.ntp_servers

  management_network = local.supervisor.management_network
  networks           = local.supervisor.networks
  content_library    = local.supervisor.content_library
  namespaces         = try(local.supervisor.namespaces, {})
}
