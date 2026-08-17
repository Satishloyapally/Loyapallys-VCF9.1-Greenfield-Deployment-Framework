output "sddc_manager_fqdn" {
  description = "SDDC Manager endpoint used by all later stages."
  value       = module.management_domain.sddc_manager_fqdn
}

output "vcenter_fqdn" {
  description = "Management vCenter endpoint."
  value       = module.management_domain.vcenter_fqdn
}

output "nsx_vip_fqdn" {
  description = "Management NSX Manager cluster VIP."
  value       = module.management_domain.nsx_vip_fqdn
}
