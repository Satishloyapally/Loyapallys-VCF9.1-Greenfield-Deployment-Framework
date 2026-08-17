output "supervisor_id" {
  description = "Identifier of the enabled Supervisor."
  value       = vsphere_supervisor.supervisor.id
}

output "content_library_id" {
  description = "Identifier of the Kubernetes release content library."
  value       = vsphere_content_library.kubernetes_releases.id
}
