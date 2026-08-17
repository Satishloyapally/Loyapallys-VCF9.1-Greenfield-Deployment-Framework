variable "name" {
  description = "Network pool name as shown in SDDC Manager."
  type        = string
}

variable "networks" {
  description = "Pool networks keyed by traffic type (VMOTION, VSAN, NFS, ISCSI)."

  type = map(object({
    vlan_id = number
    mtu     = optional(number, 9000)
    subnet  = string # network address, e.g. 172.16.12.0
    mask    = string # dotted netmask, e.g. 255.255.255.0
    gateway = string
    range = object({
      start = string
      end   = string
    })
  }))

  validation {
    condition     = alltrue([for k in keys(var.networks) : contains(["VMOTION", "VSAN", "NFS", "ISCSI"], k)])
    error_message = "Network keys must be one of VMOTION, VSAN, NFS, ISCSI."
  }
}
