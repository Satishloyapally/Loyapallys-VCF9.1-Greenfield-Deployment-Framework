output "domain_id" {
  description = "SDDC Manager identifier of the workload domain."
  value       = vcf_domain.domain.id
}

output "vcenter_fqdn" {
  description = "FQDN of the workload domain vCenter."
  value       = var.vcenter.fqdn
}

output "nsx_vip_fqdn" {
  description = "FQDN of the workload domain NSX Manager VIP."
  value       = var.nsx.vip_fqdn
}
