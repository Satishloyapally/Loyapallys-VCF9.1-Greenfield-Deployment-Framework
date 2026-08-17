output "workload_domains" {
  description = "Created workload domains and their endpoints."

  value = {
    for name, domain in module.workload_domain : name => {
      domain_id    = domain.domain_id
      vcenter_fqdn = domain.vcenter_fqdn
      nsx_vip_fqdn = domain.nsx_vip_fqdn
    }
  }
}
