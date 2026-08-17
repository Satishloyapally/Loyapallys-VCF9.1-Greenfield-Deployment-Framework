# 03 — NSX, Edge & Routing Design

This document covers the NSX Manager control plane, the NSX Edge cluster,
Tier-0/Tier-1 routing, and the two workload connectivity models.

## NSX Manager models (Choice)

| Model | Shape | Use | Key requirements |
|-------|-------|-----|------------------|
| **Simple** | Single NSX Manager appliance (internal VIP) | Minimal footprint / lab; lower scale & availability | vSphere HA restart priority **high**; slower recovery |
| **High Availability** | **3-node** NSX Manager cluster, internal VIP | Production; enterprise scale | VM-VM **anti-affinity** so nodes sit on different hosts; **≥ 4 physical hosts** so all three survive a host failure; restart priority high |

Notes:
- The internal VIP provides availability only — it does **not** load-balance
  API requests across the cluster.
- The first workload domain deploys the (shared) NSX Manager cluster in the
  management domain; later domains can share it or deploy their own.

### NSX Manager appliance sizing

| Form factor | vCPU | RAM |
|-------------|------|-----|
| Small | 4 | 16 GB |
| Medium | 6 | 24 GB |
| Large | 12 | 48 GB |
| Extra Large | 24 | 96 GB |

Pick the form factor from **VMware Configuration Maximums** for your scale.
Medium is a common management-domain starting point; Large/XL for large
workload NSX.

## NSX Edge cluster & Tier-0 (Choice: A/A vs A/S)

NSX Edges provide north-south routing (Tier-0) and overlay-to-VLAN handoff.
They are deployed **separately** from the workload domain (this repo's stage
`50`) and require a functional workload domain first.

| Tier-0 HA mode | Scale | Stateful services | When |
|----------------|-------|-------------------|------|
| **Active/Active (ECMP)** | Scale-out up to **8 edge nodes**; max north-south throughput | **Not** supported | Default for routed/overlay and VPC north-south (`VCF-WLDCON-CTGW-RCMD-CFG-001`) |
| **Active/Standby** | Two nodes, one active | Supported (NAT, gateway FW, VPN, LB on T0) | Only when you need stateful services on the Tier-0 |

Design guidance:

- **Two edge nodes minimum** per cluster for HA; scale to 8 for A/A ECMP.
- **eBGP is the recommended routing protocol** between Tier-0 and the physical
  fabric (`VCF-WLDCON-NSXSEG-RCMD-CFG-002`) — no full-mesh, clear
  administrative boundary, auto-advertises new networks.
- Use a **unique private BGP ASN** for the Tier-0 to avoid loop-detection
  drops (`VCF-WLDCON-CTGW-RCMD-CFG-002`).
- **Tier-1 gateways in DR-only mode** so north-south traffic is distributed
  across all edge nodes via ECMP (`VCF-WLDCON-NSXSEG-RCMD-CFG-021`); attach a
  Tier-1 to an edge cluster (making it Active/Standby) **only** when it needs
  centralized services.
- Configure **two uplinks per edge node**, one to each ToR, each with a BGP
  peer; reserve an ASN for the Tier-0 and one for the fabric.

## Route redistribution

- **NSX Segment connectivity model:** redistribute *Tier-1 connected* networks
  and *Tier-1 NAT* routes into BGP (`VCF-WLDCON-NSXSEG-RCMD-CFG-016`) so
  workload segments are reachable.
- **Centralized (VPC/Transit Gateway) model:** redistribute *Transit Gateway*
  and *Static* routes (`VCF-WLDCON-CTGW-RCMD-CFG-015`) so VPC public subnets,
  NAT IPs, and load-balancer VIPs are advertised.
- Use **route filters** if you need to constrain what is advertised.

## Workload connectivity models (Choice)

| Model | Description | Load balancing | Maps to |
|-------|-------------|----------------|---------|
| **NSX Segment connectivity** | Workloads on Tier-1 segments behind a Tier-0; classic overlay | NSX / Avi | `edge_clusters` with routed segments |
| **Centralized connectivity** | VPCs + **Transit Gateway** behind the Tier-0; self-service, multi-tenant | Avi | VPC/TGW consumption blueprint |

The choice ties back to the **network consumption model** (doc 02). For a
first fleet using classic overlay, the NSX Segment model with an A/A Tier-0 +
eBGP is the standard baseline; adopt VPC/Transit Gateway when you need
self-service tenancy.

## Peering VLAN / MTU (recap from doc 02)

- Peering VLANs on **trunk port groups** to edge `fp-eth0/1`.
- Port group teaming **active/standby** (TEP requirement).
- Uplink/BGP VLAN MTU **9000 recommended**; overlay = TEP − 200.

## How this framework builds it

- `iac/modules/management-domain` deploys the management NSX Manager cluster (1 or
  3 nodes) with a host TEP pool.
- `iac/modules/workload-domain` deploys or reuses the workload NSX Manager cluster.
- `iac/modules/edge-cluster` (stage 50) builds the edge nodes, Tier-0 (A/A by
  default), eBGP peers, and MTU — driven by the `edge_clusters` block in
  `site.yaml`.

## Sources

- [NSX Segment Connectivity Model](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/workload-connectivity-designs/nsx-segment-network-connectivity-model.html)
- [Centralized Connectivity Model](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/workload-connectivity-designs/centralized-connectivity-model.html)
- [Simple NSX Manager Model](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/nsx-management-and-control-plane-detailed-design/simple-nsx-manager-model.html)
- [High Availability NSX Manager Model](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/nsx-management-and-control-plane-detailed-design/high-availability-nsx-manager-model.html)
- [Configure Centralized Connectivity with Edge Clusters](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/managing-network-connectivity-in-vcenter/managing-centralized-network-connectivity-with-edge-clusters.html)
