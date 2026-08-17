output "instance_id" {
  description = "Identifier of the deployed VCF instance."
  value       = vcf_instance.management_domain.instance_id
}

output "sddc_manager_fqdn" {
  description = "FQDN of the deployed SDDC Manager. All later stages talk to this endpoint."
  value       = var.sddc_manager.hostname
}

output "vcenter_fqdn" {
  description = "FQDN of the management vCenter."
  value       = var.vcenter.hostname
}

output "nsx_vip_fqdn" {
  description = "FQDN of the management NSX Manager cluster VIP."
  value       = var.nsx.vip_fqdn
}

output "status" {
  description = "Bring-up status reported by the VCF Installer."
  value       = vcf_instance.management_domain.status
}
