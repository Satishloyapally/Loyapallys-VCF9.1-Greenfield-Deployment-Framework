variable "name" {
  description = "Edge cluster name."
  type        = string
}

variable "compute_cluster" {
  description = "vSphere cluster the edge nodes are placed on."
  type        = string
}

variable "form_factor" {
  description = "Edge node size: SMALL, MEDIUM, LARGE or XLARGE."
  type        = string
  default     = "MEDIUM"
}

variable "high_availability" {
  description = "ACTIVE_ACTIVE (ECMP) or ACTIVE_STANDBY."
  type        = string
  default     = "ACTIVE_ACTIVE"
}

variable "mtu" {
  description = "MTU for edge overlay and uplink traffic. 1700 minimum, 9000 recommended."
  type        = number
  default     = 9000
}

variable "tier0_name" {
  description = "Name of the Tier-0 gateway. Defaults to <name>-t0."
  type        = string
  default     = null
}

variable "tier1_name" {
  description = "Name of the Tier-1 gateway. Defaults to <name>-t1."
  type        = string
  default     = null
}

variable "tier1_unhosted" {
  description = "Create the Tier-1 as distributed-only (no edge cluster placement)."
  type        = bool
  default     = true
}

variable "skip_tep_routability_check" {
  description = "Skip the host-TEP to edge-TEP routability preflight. Required when both live on the same VLAN in collapsed lab designs."
  type        = bool
  default     = false
}

variable "routing" {
  description = "Northbound routing design for the Tier-0 gateway."

  type = object({
    type      = optional(string, "EBGP") # EBGP | STATIC
    local_asn = optional(number, 65100)
    peer_asn  = optional(number, 65000)
  })

  default = {}
}

variable "management_network" {
  description = "Management network the edge node management interfaces attach to."

  type = object({
    portgroup = string
    vlan_id   = number
    gateway   = string
  })
}

variable "edge_tep" {
  description = "Edge TEP VLAN. Must be routable to the host TEP VLAN (or shared in collapsed labs)."

  type = object({
    vlan_id = number
    gateway = string
  })
}

variable "nodes" {
  description = "Edge nodes keyed by node FQDN. Each node carries two TEP IPs and its fabric uplinks."

  type = map(object({
    management_ip = string
    tep_ips       = list(string)
    uplinks = list(object({
      vlan_id      = number
      interface_ip = string # CIDR notation, e.g. 172.16.20.2/24
      peer_ip      = optional(string)
    }))
  }))

  validation {
    condition     = length(var.nodes) >= 2 && length(var.nodes) <= 8
    error_message = "An edge cluster requires between two and eight nodes."
  }

  validation {
    condition     = alltrue([for n in values(var.nodes) : length(n.tep_ips) == 2])
    error_message = "Each edge node requires exactly two TEP IPs."
  }
}

variable "timeouts" {
  description = "Optional operation timeouts for the edge cluster (e.g. create = \"1h\"). Leave null to use provider defaults."
  type = object({
    create = optional(string)
    update = optional(string)
  })
  default = null
}

variable "credentials" {
  description = "Edge node account passwords and optional BGP MD5 secret."
  sensitive   = true

  type = object({
    root_password  = string
    admin_password = string
    audit_password = string
    bgp_password   = optional(string)
  })
}
