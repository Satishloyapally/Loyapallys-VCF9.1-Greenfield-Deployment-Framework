# ------------------------------------------------------------------------- #
# Workload Domain Module
#
# Creates a VI workload domain through SDDC Manager:
#
#   * Dedicated vCenter appliance
#   * NSX Manager cluster (one node for labs, three for production)
#   * One or more vSAN clusters built from commissioned hosts
#
# Hosts are referenced by their SDDC Manager UUIDs, which the
# host-commission stage exports; callers never copy UUIDs by hand.
# ------------------------------------------------------------------------- #

terraform {
  required_version = ">= 1.7"

  required_providers {
    vcf = {
      source  = "vmware/vcf"
      version = ">= 0.18.0"
    }
  }
}

resource "vcf_domain" "domain" {
  name = var.name

  vcenter_configuration {
    name            = split(".", var.vcenter.fqdn)[0]
    fqdn            = var.vcenter.fqdn
    ip_address      = var.vcenter.ip_address
    subnet_mask     = var.vcenter.subnet_mask
    gateway         = var.vcenter.gateway
    datacenter_name = var.vcenter.datacenter
    vm_size         = var.vcenter.size
    storage_size    = var.vcenter.storage_size
    root_password   = var.credentials.vcenter_root_password
  }

  dynamic "sso" {
    for_each = var.sso != null ? [var.sso] : []

    content {
      domain_name     = sso.value.domain_name
      domain_password = var.credentials.sso_admin_password
    }
  }

  nsx_configuration {
    vip                        = var.nsx.vip_ip
    vip_fqdn                   = var.nsx.vip_fqdn
    form_factor                = var.nsx.form_factor
    nsx_manager_admin_password = var.credentials.nsx_admin_password
    nsx_manager_audit_password = var.credentials.nsx_audit_password

    dynamic "nsx_manager_node" {
      for_each = var.nsx.managers

      content {
        name        = split(".", nsx_manager_node.value.fqdn)[0]
        fqdn        = nsx_manager_node.value.fqdn
        ip_address  = nsx_manager_node.value.ip_address
        subnet_mask = var.nsx.subnet_mask
        gateway     = var.nsx.gateway
      }
    }
  }

  dynamic "cluster" {
    for_each = var.clusters

    content {
      name                      = cluster.key
      high_availability_enabled = cluster.value.ha_enabled
      evc_mode                  = cluster.value.evc_mode
      geneve_vlan_id            = cluster.value.host_tep.vlan_id

      vsan_datastore {
        datastore_name                = coalesce(cluster.value.vsan.datastore_name, "${cluster.key}-vsan")
        esa_enabled                   = cluster.value.vsan.esa_enabled
        dedup_and_compression_enabled = cluster.value.vsan.dedup_enabled
        failures_to_tolerate          = cluster.value.vsan.failures_to_tolerate
      }

      dynamic "host" {
        for_each = cluster.value.host_ids

        content {
          id = host.value

          dynamic "vmnic" {
            for_each = cluster.value.vds.vmnics

            content {
              id       = vmnic.value
              vds_name = "${cluster.key}-vds"
              uplink   = "uplink${index(cluster.value.vds.vmnics, vmnic.value) + 1}"
            }
          }
        }
      }

      vds {
        name           = "${cluster.key}-vds"
        is_used_by_nsx = true

        portgroup {
          name           = "${cluster.key}-pg-mgmt"
          transport_type = "MANAGEMENT"
        }

        portgroup {
          name           = "${cluster.key}-pg-vmotion"
          transport_type = "VMOTION"
        }

        portgroup {
          name           = "${cluster.key}-pg-vsan"
          transport_type = "VSAN"
        }
      }

      ip_address_pool {
        name                           = "${cluster.key}-host-tep-pool"
        description                    = "Host TEP addresses for cluster ${cluster.key}"
        ignore_unavailable_nsx_cluster = true

        subnet {
          cidr    = cluster.value.host_tep.cidr
          gateway = cluster.value.host_tep.gateway

          ip_address_pool_range {
            start = cluster.value.host_tep.range.start
            end   = cluster.value.host_tep.range.end
          }
        }
      }
    }
  }

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []

    content {
      create = var.timeouts.create
      update = var.timeouts.update
      delete = var.timeouts.delete
      read   = var.timeouts.read
    }
  }
}
