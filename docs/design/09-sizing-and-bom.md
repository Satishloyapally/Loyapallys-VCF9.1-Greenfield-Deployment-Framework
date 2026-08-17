# 09 — Sizing & Bill of Materials

Right-size before bring-up. Use the **VCF Planning & Preparation Workbook**
and the **vSAN Sizer** (https://vcf.broadcom.com/tools/vsansizer/home) for
authoritative capacity figures; the tables here are design starting points.

## Management domain footprint

| Deployment model | Management appliances | NSX Manager | Hosts |
|------------------|-----------------------|-------------|-------|
| **Simple / minimal** | ~7 | 1 node | ≥ 4 |
| **Highly Available** | ~13 | 3-node cluster | ≥ 4 (so 3 NSX managers survive a host loss) |

The management domain always needs **≥ 4 vSAN-capable hosts** (N+1 for FTT=1
RAID-5).

## Appliance sizes

### vCenter Server

| Size | Typical use |
|------|-------------|
| tiny / small | lab, small management domain |
| medium | common management/workload default |
| large / xlarge | large workload domains |

Storage size: `lstorage` / `xlstorage` for larger inventories.

### NSX Manager

| Form factor | vCPU | RAM |
|-------------|------|-----|
| Small | 4 | 16 GB |
| Medium | 6 | 24 GB |
| Large | 12 | 48 GB |
| Extra Large | 24 | 96 GB |

### vSphere Supervisor control plane (per CP VM; deploy 1 or 3)

| Size | vCPU | RAM | Max vSphere Pods |
|------|------|-----|------------------|
| Tiny | 2 | 8 GB | 1000 |
| Small | 4 | 16 GB | 2000 |
| Medium | 8 | 24 GB | 4000 |
| Large | 16 | 32 GB | 8000 |

Scale-up only. Three Small CP VMs = 12 vCPU / 48 GB (up to 2000 pods).

## Host minimums (recap)

| Role | Minimum | Recommended |
|------|---------|-------------|
| Management domain (vSAN) | 4 | 4+ |
| Workload vSAN cluster | 3 | 4 |
| FTT=2 RAID-6 cluster | 6 | **7** |
| Stretched (per AZ) | 3 + witness | 4 + witness |
| 2-node ROBO | 2 + witness | — |
| Max per vSAN cluster | — | 32 |

## Host hardware (vSAN ESA)

- NVMe TLC devices, multiple per node; performance **Class F** (100000+ IOPS),
  endurance **≥ 3 DWPD**; vSAN ESA ReadyNodes.
- 2× 10 GbE minimum per host (25 GbE recommended); 128 GB+ boot device.
- Same CPU vendor per cluster (EVC requirement).

## Network / VLAN count

A minimal management domain needs **≥ 7 VLANs** (ESX mgmt, VM/VCF mgmt,
vMotion, vSAN, host TEP, plus edge TEP + uplinks for routing). See
[doc 02](02-network-design.md).

## Worked example — minimal-footprint lab

Matches `iac/config/site.example.yaml`:

- 4× ESXi hosts, vSAN ESA, FTT=1 (RAID-5, N+1).
- vCenter small; NSX Manager medium (single node for lab, 3 for prod).
- Management VLANs 1610–1614; edge TEP 1635; uplinks 1620/1621.
- Optional VCF Operations (small), Collector, Fleet Management, Automation.
- Optional Supervisor: 3× Small CP VMs on the workload cluster.

## Sizing tools

- **VCF Planning & Preparation Workbook** (Broadcom Support Portal) — the
  authoritative input for bring-up.
- **vSAN Sizer** — https://vcf.broadcom.com/tools/vsansizer/home
- **VMware Configuration Maximums** — pick NSX/vCenter form factors for scale.
- **VCF Fleet Latency Diagram** (ports.broadcom.com) — inter-component latency
  budgets for multi-site designs.

## Sources

- [Architectural Options — sizing models](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/vmware-cloud-foundation-concepts.html)
- [vSAN ESA Storage Model](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/storage-models-9-x/standard-vsan-storage-model/single-rack-storage-models/vsan-storage-cluster-storage-model.html)
