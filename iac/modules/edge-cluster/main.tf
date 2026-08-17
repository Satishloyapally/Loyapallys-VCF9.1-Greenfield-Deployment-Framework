# ------------------------------------------------------------------------- #
# NSX Edge Cluster Module
#
# Deploys an NSX edge cluster through SDDC Manager, including the Tier-0
# gateway with eBGP peering to the physical fabric. Two edge nodes with
# active/active ECMP is the default; scale out by adding nodes to the map.
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

resource "vcf_edge_cluster" "edge_cluster" {
  name              = var.name
  form_factor       = var.form_factor
  profile_type      = "DEFAULT"
  routing_type      = var.routing.type
  high_availability = var.high_availability
  mtu               = var.mtu
  asn               = var.routing.local_asn
  tier0_name        = coalesce(var.tier0_name, "${var.name}-t0")
  tier1_name        = coalesce(var.tier1_name, "${var.name}-t1")
  tier1_unhosted    = var.tier1_unhosted

  root_password  = var.credentials.root_password
  admin_password = var.credentials.admin_password
  audit_password = var.credentials.audit_password

  skip_tep_routability_check = var.skip_tep_routability_check

  dynamic "edge_node" {
    for_each = var.nodes

    content {
      name                 = edge_node.key
      compute_cluster_name = var.compute_cluster

      root_password  = var.credentials.root_password
      admin_password = var.credentials.admin_password
      audit_password = var.credentials.audit_password

      management_ip      = edge_node.value.management_ip
      management_gateway = var.management_network.gateway

      management_network {
        portgroup_name = var.management_network.portgroup
        vlan_id        = var.management_network.vlan_id
      }

      tep_vlan           = var.edge_tep.vlan_id
      tep_gateway        = var.edge_tep.gateway
      tep1_ip            = edge_node.value.tep_ips[0]
      tep2_ip            = edge_node.value.tep_ips[1]
      inter_rack_cluster = false

      dynamic "uplink" {
        for_each = edge_node.value.uplinks

        content {
          interface_ip = uplink.value.interface_ip
          vlan         = uplink.value.vlan_id

          dynamic "bgp_peer" {
            for_each = var.routing.type == "EBGP" ? [uplink.value] : []

            content {
              ip       = bgp_peer.value.peer_ip
              asn      = var.routing.peer_asn
              password = var.credentials.bgp_password
            }
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
    }
  }
}
