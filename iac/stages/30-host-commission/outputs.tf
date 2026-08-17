output "host_ids" {
  description = "Commissioned hosts: FQDN to SDDC Manager UUID. Consumed by stage 40 via remote state."
  value       = module.hosts.host_ids
}
