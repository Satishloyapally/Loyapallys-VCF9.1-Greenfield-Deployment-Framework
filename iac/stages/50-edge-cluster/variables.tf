variable "site_config" {
  description = "Path to the site definition YAML."
  type        = string
  default     = "../../config/site.yaml"
}

variable "allow_unverified_tls" {
  description = "Accept SDDC Manager's self-signed certificate."
  type        = bool
  default     = true
}

variable "sddc_manager_username" {
  description = "SSO account used against the SDDC Manager API."
  type        = string
  default     = "administrator@vsphere.local"
}

variable "sddc_manager_password" {
  description = "Password for the SDDC Manager API account."
  type        = string
  sensitive   = true
}

variable "credentials" {
  description = "Edge node passwords per edge cluster, keyed by edge cluster name from site.yaml."
  sensitive   = true

  type = map(object({
    root_password  = string
    admin_password = string
    audit_password = string
    bgp_password   = optional(string)
  }))
}
