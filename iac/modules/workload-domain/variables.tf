variable "name" {
  description = "Workload domain name."
  type        = string
}

variable "vcenter" {
  description = "Dedicated vCenter appliance for this workload domain."

  type = object({
    fqdn         = string
    ip_address   = string
    subnet_mask  = string
    gateway      = string
    datacenter   = string
    size         = optional(string, "medium")
    storage_size = optional(string, "lstorage")
  })
}

variable "sso" {
  description = "Isolated SSO domain. Leave null to join the management SSO domain."

  type = object({
    domain_name = string
  })

  default = null
}

variable "nsx" {
  description = "NSX Manager cluster for this workload domain."

  type = object({
    vip_ip      = string
    vip_fqdn    = string
    form_factor = optional(string, "medium")
    subnet_mask = string
    gateway     = string
    managers = list(object({
      fqdn       = string
      ip_address = string
    }))
  })

  validation {
    condition     = contains([1, 3], length(var.nsx.managers))
    error_message = "Deploy one (lab) or three (production) NSX Managers."
  }
}

variable "clusters" {
  description = "vSAN clusters in the domain, keyed by cluster name. host_ids come from the host-commission stage output."

  type = map(object({
    host_ids   = list(string)
    ha_enabled = optional(bool, true)
    evc_mode   = optional(string, "")

    vsan = optional(object({
      datastore_name       = optional(string)
      esa_enabled          = optional(bool, true)
      dedup_enabled        = optional(bool, false)
      failures_to_tolerate = optional(number, 1)
    }), {})

    vds = optional(object({
      vmnics = optional(list(string), ["vmnic0", "vmnic1"])
    }), {})

    host_tep = object({
      vlan_id = number
      cidr    = string
      gateway = string
      range = object({
        start = string
        end   = string
      })
    })
  }))

  validation {
    condition     = alltrue([for c in values(var.clusters) : length(c.host_ids) >= 3])
    error_message = "Each vSAN cluster requires at least three hosts (four recommended)."
  }
}

variable "timeouts" {
  description = "Optional operation timeouts for the workload domain (e.g. create = \"2h\"). Leave null to use provider defaults."
  type = object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
    read   = optional(string)
  })
  default = null
}

variable "credentials" {
  description = "Passwords for the workload domain appliances."
  sensitive   = true

  type = object({
    vcenter_root_password = string
    nsx_admin_password    = string
    nsx_audit_password    = string
    sso_admin_password    = optional(string)
  })
}
