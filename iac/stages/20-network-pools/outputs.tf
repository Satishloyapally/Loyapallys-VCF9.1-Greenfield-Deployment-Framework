output "network_pools" {
  description = "Created network pools: name to SDDC Manager identifier."
  value       = { for name, pool in module.network_pool : name => pool.id }
}
