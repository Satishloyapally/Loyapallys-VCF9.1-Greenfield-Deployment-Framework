# 02 — Network Design

Network design is the foundation everything else depends on. Get the VLANs,
subnets, MTU, and teaming right *before* bring-up — most failed deployments
trace back to DNS or network mistakes.

## VLAN / subnet reference model (single-rack)

A single-rack greenfield site needs at least the following networks. The
example addresses mirror `iac/config/site.example.yaml` (`172.16.x.0/24`):

| Purpose | Example VLAN | Example subnet | MTU | Notes |
|---------|--------------|----------------|-----|-------|
| ESX management (vmk0) | 1610 | 172.16.10.0/24 | 1500 | Host management; static on vmk0 |
| VCF / VM management | 1611 | 172.16.11.0/24 | 1500 | vCenter, NSX, SDDC Manager, VCF Operations/Automation appliances |
| vMotion | 1612 | 172.16.12.0/24 | 9000 | IP range assigned from pool |
| vSAN | 1613 | 172.16.13.0/24 | 9000 | IP range assigned from pool |
| Host TEP (overlay) | 1614 | 172.16.14.0/24 | 1700+ (9000 rec.) | NSX host tunnel endpoints |
| Edge TEP | 1635 | 172.16.35.0/24 | 1700+ (9000 rec.) | Must be routable to Host TEP (or shared in collapsed labs) |
| Edge uplink 1 | 1620 | 172.16.20.0/24 | 9000 rec. | eBGP peering to fabric router 1 |
| Edge uplink 2 | 1621 | 172.16.21.0/24 | 9000 rec. | eBGP peering to fabric router 2 |

Workload domains add their own vMotion / vSAN / host-TEP VLANs (the example
uses 1632–1634). Broadcom's minimal management-domain deployment needs
**≥ 7 VLANs**.

## MTU — the rules that bite

MTU mistakes are a top cause of overlay and BGP failures. The requirements
(with Broadcom decision IDs):

- **Overlay segment MTU = Host/Edge TEP MTU − 200 bytes** (`VCF-NET-REQD-OVL-001`).
  Geneve packets are flagged *do-not-fragment*; the 200 bytes cover the Geneve
  header. If TEP MTU is 9000, the max overlay segment MTU is **8800**.
- **Edge uplink / BGP peering VLAN**: 1500 minimum (`VCF-NET-REQD-MTU-007`),
  **9000 recommended** (`VCF-NET-RCMD-MTU-006`) for BGP-update throughput.
- **Jumbo frames must be end-to-end** — every intermediate switch, port group,
  and gateway on storage/overlay/uplink paths. A single 1500-byte hop breaks
  9000-byte traffic silently.
- Set the **Edge cluster / Global Fabric MTU** consistently with the host
  overlay Transport Zone MTU.

## Distributed switch & teaming

- One or more **vSphere Distributed Switches (VDS)** per cluster; at least one
  VDS is marked **used by NSX** to carry overlay traffic.
- Map physical uplinks (`vmnic0`, `vmnic1`) to VDS uplinks (`uplink1`,
  `uplink2`); 2× 10 GbE minimum, 25 GbE recommended.
- **Peering VLANs are carried on trunk port groups** connected to the edge
  `fp-eth0`/`fp-eth1` interfaces so peering + TEP VLANs share the edge vNIC.
- The **TEP VLAN must fail over between uplinks**, so the port group teaming
  policy must be **active/standby** to satisfy the TEP requirement (peering
  VLANs themselves do not need to fail over). Physical switches should prune
  peering VLANs where not required.
- Storage/vMotion teaming commonly uses `loadbalance_loadbased`.

## Host TEP addressing

Host tunnel endpoints get addresses from an **NSX IP address pool** (defined
during bring-up for the management cluster, and per workload cluster
thereafter) or from DHCP. Static pools are preferred for determinism — this
framework configures a host TEP pool (CIDR + gateway + range) in the
management-domain and workload-domain modules.

## Network consumption model (the pivotal choice)

How workloads attach to the network is Phase 4 of the design flow and drives
the entire edge/routing design (see [doc 03](03-nsx-edge-design.md)):

| Model | Use when | Edge implication |
|-------|----------|------------------|
| **VLAN** | Traditional, no overlay | No NSX edge needed for those workloads |
| **NSX Overlay Segments** | Classic NSX logical networking, Tier-1/Tier-0 | Edge cluster + Tier-0 with BGP |
| **NSX VPC** | Self-service, multi-tenant isolation | Edge cluster + Transit Gateway; Avi load balancing |
| **Transit Gateway** | Centralized connectivity across VPCs | Edge cluster; centralized connectivity model |

Decide this early — it cannot be changed cheaply once workloads are attached.

## Prerequisites checklist (network)

- Forward **and reverse** DNS for every appliance and host FQDN (a standard
  deployment needs 17+ records).
- NTP reachable and in sync on all hosts and appliances.
- All VLANs trunked to every host; gateways live; jumbo frames end-to-end on
  storage/overlay/uplink VLANs.
- `make preflight` validates DNS/NTP/reachability against `site.yaml` before
  bring-up.

## Sources

- [Network Fabric Detailed Design](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/datacenter-network-requirements/network-fabric-design.html)
- [Workload Connectivity Designs](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/workload-connectivity-designs/nsx-segment-network-connectivity-model.html)
