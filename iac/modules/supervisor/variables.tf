variable "datacenter" {
  description = "Datacenter containing the target cluster (in the workload domain vCenter)."
  type        = string
}

variable "cluster" {
  description = "vSphere cluster to enable the Supervisor on."
  type        = string
}

variable "vds_name" {
  description = "Distributed switch backing the cluster."
  type        = string
}

variable "edge_cluster_name" {
  description = "NSX edge cluster providing Tier-0 connectivity for Supervisor ingress/egress."
  type        = string
}

variable "storage_policy" {
  description = "Storage policy for control plane VMs, ephemeral disks and the image cache."
  type        = string
  default     = "vSAN Default Storage Policy"
}

variable "control_plane_size" {
  description = "Control plane sizing hint: SMALL, MEDIUM or LARGE."
  type        = string
  default     = "SMALL"
}

variable "dns_domain" {
  description = "Search domain pushed to control plane nodes."
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for control plane and workers."
  type        = list(string)
}

variable "ntp_servers" {
  description = "NTP servers for control plane nodes."
  type        = list(string)
}

variable "management_network" {
  description = "Management addressing for the Supervisor control plane. Five consecutive addresses starting at starting_address are consumed."

  type = object({
    portgroup        = string
    starting_address = string
    subnet_mask      = string
    gateway          = string
    address_count    = optional(number, 5)
  })
}

variable "networks" {
  description = "Kubernetes networking (all CIDR notation). ingress/egress are carved from routable space behind the Tier-0; pod/service are private."

  type = object({
    ingress_cidr = string
    egress_cidr  = string
    pod_cidr     = optional(string, "10.244.0.0/20")
    service_cidr = optional(string, "10.96.0.0/22")
  })
}

variable "content_library" {
  description = "Subscribed content library that delivers Kubernetes release images."

  type = object({
    name             = optional(string, "kubernetes-releases")
    datastore        = string
    subscription_url = optional(string, "https://wp-content.vmware.com/v2/latest/lib.json")
  })
}

variable "namespaces" {
  description = "Initial vSphere namespaces to create on the Supervisor, keyed by name."
  type        = map(object({}))
  default     = {}
}
