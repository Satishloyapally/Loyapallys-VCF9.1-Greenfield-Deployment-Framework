variable "site_config" {
  description = "Path to the site definition YAML."
  type        = string
  default     = "../../config/site.yaml"
}

variable "supervisor_name" {
  description = "Which supervisors entry from site.yaml to deploy. Defaults to the first one."
  type        = string
  default     = null
}

variable "allow_unverified_tls" {
  description = "Accept self-signed certificates on vCenter and NSX."
  type        = bool
  default     = true
}

variable "vsphere_username" {
  description = "SSO account on the workload domain vCenter."
  type        = string
  default     = "administrator@vsphere.local"
}

variable "vsphere_password" {
  description = "Password for the vCenter SSO account."
  type        = string
  sensitive   = true
}

variable "nsx_username" {
  description = "Admin account on the workload domain NSX Manager."
  type        = string
  default     = "admin"
}

variable "nsx_password" {
  description = "Password for the NSX admin account."
  type        = string
  sensitive   = true
}
