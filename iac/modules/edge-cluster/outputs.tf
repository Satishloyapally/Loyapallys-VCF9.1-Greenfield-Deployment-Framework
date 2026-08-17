output "edge_cluster_id" {
  description = "SDDC Manager identifier of the edge cluster."
  value       = vcf_edge_cluster.edge_cluster.id
}

output "edge_cluster_name" {
  description = "Edge cluster name, consumed by the supervisor stage."
  value       = vcf_edge_cluster.edge_cluster.name
}
