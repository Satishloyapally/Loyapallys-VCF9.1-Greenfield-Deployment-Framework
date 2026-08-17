terraform {
  required_version = ">= 1.7"

  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.16"
    }
    nsxt = {
      source  = "vmware/nsxt"
      version = "~> 3.12"
    }
  }
}

# Both providers point at the workload domain that owns the target cluster.
provider "vsphere" {
  vsphere_server       = local.workload_domain.vcenter.fqdn
  user                 = var.vsphere_username
  password             = var.vsphere_password
  allow_unverified_ssl = var.allow_unverified_tls
}

provider "nsxt" {
  host                 = local.workload_domain.nsx.vip_fqdn
  username             = var.nsx_username
  password             = var.nsx_password
  allow_unverified_ssl = var.allow_unverified_tls
}
