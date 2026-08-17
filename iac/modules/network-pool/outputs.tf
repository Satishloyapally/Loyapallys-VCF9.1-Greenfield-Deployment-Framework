output "id" {
  description = "SDDC Manager identifier of the network pool."
  value       = vcf_network_pool.pool.id
}

output "name" {
  description = "Name of the network pool, consumed by host commissioning."
  value       = vcf_network_pool.pool.name
}
