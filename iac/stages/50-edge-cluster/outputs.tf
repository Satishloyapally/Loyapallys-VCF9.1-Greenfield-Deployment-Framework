output "edge_clusters" {
  description = "Created edge clusters: name to SDDC Manager identifier."
  value       = { for name, ec in module.edge_cluster : name => ec.edge_cluster_id }
}
