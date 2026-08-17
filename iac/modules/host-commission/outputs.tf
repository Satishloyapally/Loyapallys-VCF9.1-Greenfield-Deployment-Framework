output "host_ids" {
  description = "Map of host FQDN to SDDC Manager host UUID. Workload domain and cluster stages consume these."
  value       = { for fqdn, host in vcf_host.host : fqdn => host.id }
}
