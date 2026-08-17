output "supervisor_id" {
  description = "Identifier of the enabled Supervisor."
  value       = module.supervisor.supervisor_id
}

output "kubernetes_content_library_id" {
  description = "Content library delivering Kubernetes releases to the Supervisor."
  value       = module.supervisor.content_library_id
}
