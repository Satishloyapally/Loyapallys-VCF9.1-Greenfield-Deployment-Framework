variable "site_config" {
  description = "Path to the site definition YAML."
  type        = string
  default     = "../../config/site.yaml"
}

variable "allow_unverified_tls" {
  description = "Accept the installer's self-signed certificate."
  type        = bool
  default     = true
}

variable "skip_host_thumbprint_validation" {
  description = "Skip ESXi SSL thumbprint validation during bring-up."
  type        = bool
  default     = true
}

variable "installer_admin_password" {
  description = "Password of admin@local on the VCF Installer appliance."
  type        = string
  sensitive   = true
}

variable "credentials" {
  description = "Passwords assigned to every appliance during bring-up. See secrets.auto.tfvars.example."
  sensitive   = true

  type = object({
    esxi_root_password              = string
    sddc_manager_root_password      = string
    sddc_manager_ssh_password       = string
    sddc_manager_admin_password     = string
    vcenter_root_password           = string
    nsx_root_password               = string
    nsx_admin_password              = string
    nsx_audit_password              = string
    appliance_root_password         = optional(string)
    operations_admin_password       = optional(string)
    fleet_management_admin_password = optional(string)
    automation_admin_password       = optional(string)
  })
}
