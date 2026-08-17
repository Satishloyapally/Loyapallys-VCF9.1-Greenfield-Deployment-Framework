# ------------------------------------------------------------------------- #
# Site identity
# ------------------------------------------------------------------------- #
variable "instance_name" {
  description = "Name of the VCF instance (site identifier used inside SDDC Manager)."
  type        = string
}

variable "vcf_version" {
  description = "VCF release to deploy. This framework targets VCF 9.1 only, e.g. 9.1.0.0."
  type        = string

  validation {
    condition     = can(regex("^9\\.1\\.", var.vcf_version))
    error_message = "This framework targets VMware Cloud Foundation 9.1 only. Set vcf_version to a 9.1.x release (for example 9.1.0.0)."
  }
}

variable "dns_domain" {
  description = "DNS zone that all appliance and host FQDNs live in."
  type        = string
}

variable "dns_servers" {
  description = "One or two DNS servers, in preference order."
  type        = list(string)

  validation {
    condition     = length(var.dns_servers) >= 1 && length(var.dns_servers) <= 2
    error_message = "Provide one or two DNS servers."
  }
}

variable "ntp_servers" {
  description = "One or two NTP servers, in preference order."
  type        = list(string)

  validation {
    condition     = length(var.ntp_servers) >= 1 && length(var.ntp_servers) <= 2
    error_message = "Provide one or two NTP servers."
  }
}

variable "ceip_enabled" {
  description = "Join the Customer Experience Improvement Program."
  type        = bool
  default     = false
}

variable "fips_enabled" {
  description = "Deploy the fleet in FIPS validated mode. Cannot be changed after bring-up."
  type        = bool
  default     = false
}

variable "skip_host_thumbprint_validation" {
  description = "Skip ESXi SSL thumbprint validation. Acceptable for lab use; set to false and pin thumbprints for production."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------- #
# Physical networking
# ------------------------------------------------------------------------- #
variable "networks" {
  description = <<-EOT
    Management cluster networks, keyed by VCF network type
    (VM_MANAGEMENT, MANAGEMENT, VMOTION, VSAN). Subnets are CIDR notation.
    ip_range is required for VMOTION and VSAN (host addresses are allocated
    from it) and omitted for the two management networks.
  EOT

  type = map(object({
    portgroup = string
    vlan_id   = number
    subnet    = string
    gateway   = string
    mtu       = optional(number, 9000)
    ip_range = optional(object({
      start = string
      end   = string
    }))
  }))

  validation {
    condition     = alltrue([for k in keys(var.networks) : contains(["VM_MANAGEMENT", "MANAGEMENT", "VMOTION", "VSAN"], k)])
    error_message = "Network keys must be one of VM_MANAGEMENT, MANAGEMENT, VMOTION, VSAN."
  }

  validation {
    condition     = alltrue([for k, v in var.networks : can(cidrhost(v.subnet, 0))])
    error_message = "Every network subnet must be valid CIDR notation, e.g. 172.16.11.0/24."
  }
}

variable "dvs" {
  description = "Distributed switch layout for the management cluster."

  type = object({
    name            = string
    mtu             = optional(number, 9000)
    uplinks         = optional(list(string), ["uplink1", "uplink2"])
    vmnic_mapping   = optional(map(string), { uplink1 = "vmnic0", uplink2 = "vmnic1" })
    nsx_switch_mode = optional(string, "ENS_INTERRUPT")
    nioc_shares = optional(map(string), {
      MANAGEMENT     = "NORMAL"
      VMOTION        = "LOW"
      VSAN           = "HIGH"
      VIRTUALMACHINE = "HIGH"
    })
  })
}

# ------------------------------------------------------------------------- #
# Appliances
# ------------------------------------------------------------------------- #
variable "sddc_manager" {
  description = "SDDC Manager appliance."

  type = object({
    hostname = string
  })
}

variable "vcenter" {
  description = "Management vCenter appliance."

  type = object({
    hostname     = string
    size         = optional(string, "medium")
    storage_size = optional(string, "lstorage")
  })
}

variable "nsx" {
  description = "NSX Manager cluster for the management domain."

  type = object({
    vip_fqdn          = string
    manager_hostnames = list(string)
    manager_size      = optional(string, "medium")
    transport_vlan_id = number
    teaming_policy    = optional(string, "LOADBALANCE_SRCID")
    host_tep_pool = object({
      cidr    = string
      gateway = string
      range = object({
        start = string
        end   = string
      })
    })
  })

  validation {
    condition     = contains([1, 3], length(var.nsx.manager_hostnames))
    error_message = "Deploy one (lab) or three (production) NSX Managers."
  }
}

# ------------------------------------------------------------------------- #
# Optional fleet components
# ------------------------------------------------------------------------- #
variable "operations" {
  description = "VCF Operations cluster. Set to null to skip."

  type = object({
    appliance_size     = optional(string, "small")
    load_balancer_fqdn = optional(string)
    nodes = list(object({
      hostname = string
      type     = string # master | replica | data
    }))
  })

  default = null
}

variable "operations_collector" {
  description = "VCF Operations Collector appliance. Set to null to skip."

  type = object({
    hostname       = string
    appliance_size = optional(string, "small")
  })

  default = null
}

variable "fleet_management" {
  description = "VCF Operations Fleet Management appliance. Set to null to skip."

  type = object({
    hostname = string
  })

  default = null
}

variable "automation" {
  description = "VCF Automation cluster. Set to null to skip."

  type = object({
    hostname              = string
    node_prefix           = optional(string, "auto")
    ip_pool               = list(string)
    internal_cluster_cidr = optional(string, "198.18.0.0/15")
  })

  default = null
}

# ------------------------------------------------------------------------- #
# Cluster, storage and hosts
# ------------------------------------------------------------------------- #
variable "cluster" {
  description = "Management cluster and datacenter names created in the management vCenter."

  type = object({
    name       = string
    datacenter = string
  })
}

variable "vsan" {
  description = "vSAN datastore layout for the management cluster."

  type = object({
    datastore_name       = optional(string)
    esa_enabled          = optional(bool, true)
    dedup_enabled        = optional(bool, false)
    failures_to_tolerate = optional(number, 1)
  })

  default = {}
}

variable "hosts" {
  description = "FQDNs of the seed ESXi hosts for the management cluster (minimum four)."
  type        = list(string)

  validation {
    condition     = length(var.hosts) >= 4
    error_message = "A VCF management cluster requires at least four ESXi hosts."
  }
}

# ------------------------------------------------------------------------- #
# Operation timeouts
# ------------------------------------------------------------------------- #
variable "timeouts" {
  description = "Optional operation timeouts. `create` bounds the multi-hour bring-up, e.g. \"6h\". Leave null to use the provider default."
  type = object({
    create = optional(string)
  })
  default = null
}

# ------------------------------------------------------------------------- #
# Secrets
# ------------------------------------------------------------------------- #
variable "credentials" {
  description = "All passwords used during bring-up. Supply via a git-ignored tfvars file or environment variables, never in source control."
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
