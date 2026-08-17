variable "hosts" {
  description = "Hosts to commission, keyed by FQDN."

  type = map(object({
    network_pool = string
    storage_type = optional(string, "VSAN_ESA") # VSAN | VSAN_ESA | VSAN_REMOTE | NFS | VMFS_FC | VVOL
  }))
}

variable "esxi_root_password" {
  description = "Root password shared by the hosts being commissioned."
  type        = string
  sensitive   = true
}
