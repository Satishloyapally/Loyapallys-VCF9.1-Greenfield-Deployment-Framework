# ------------------------------------------------------------------------- #
# Stage 10 - Management Domain Bring-up
#
# Reads the site definition and drives the VCF Installer through the full
# greenfield bring-up. Expect this stage to run for 2-4 hours; progress is
# visible in the VCF Installer UI while Terraform waits.
# ------------------------------------------------------------------------- #

locals {
  site = yamldecode(file(var.site_config))
  md   = local.site.management_domain
}

module "management_domain" {
  source = "../../modules/management-domain"

  instance_name = local.site.site.name
  vcf_version   = local.site.vcf.version

  dns_domain   = local.site.site.dns_domain
  dns_servers  = local.site.site.dns_servers
  ntp_servers  = local.site.site.ntp_servers
  ceip_enabled = try(local.site.site.ceip_enabled, false)
  fips_enabled = try(local.site.site.fips_enabled, false)

  skip_host_thumbprint_validation = var.skip_host_thumbprint_validation

  cluster = {
    name       = local.md.cluster
    datacenter = local.md.datacenter
  }

  hosts    = local.md.hosts
  networks = local.md.networks
  dvs      = local.md.dvs
  vsan     = try(local.md.vsan, {})

  sddc_manager = local.md.sddc_manager
  vcenter      = local.md.vcenter
  nsx          = local.md.nsx

  operations           = try(local.md.operations, null)
  operations_collector = try(local.md.operations_collector, null)
  fleet_management     = try(local.md.fleet_management, null)
  automation           = try(local.md.automation, null)

  timeouts = try(local.md.timeouts, null)

  credentials = var.credentials
}
