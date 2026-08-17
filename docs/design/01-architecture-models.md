# 01 — Architecture Models & Blueprints

## VCF taxonomy: Fleet → Instance → Domain

VCF 9.x introduced fleet-level management. Understand these three scopes
before choosing a topology:

| Scope | Definition |
|-------|-----------|
| **VCF Fleet** | The management envelope for one or more VCF Instances (and optionally standalone vCenters). The **fleet-level components — VCF Operations, VCF Operations fleet management, VCF Automation, License Server — run in the management domain of the *first* VCF Instance**. Broadcom recommends **one fleet with multiple instances** to minimize operational overhead. |
| **VCF Instance** | A management domain plus optional workload domains — compute, storage, and networking that runs business workloads. |
| **Domain** | A policy container combining vSphere (compute), vSAN/NFS/VMFS/vVol (storage), and NSX (networking). A **management domain** is created first by the VCF Installer; **workload domains** are created afterward in VCF Operations. |

Key implications for greenfield:

- The **management domain** hosts SDDC Manager, the management vCenter, the
  NSX Manager cluster, and (in the first instance) VCF Operations, VCF
  Operations Collector/Fleet Management, VCF Automation, and the License
  Server.
- The **first workload domain** triggers deployment of a workload vCenter and
  (typically) a workload NSX Manager cluster in the management domain.
  Subsequent domains can share or create their own NSX.

## Deployment models (management services availability)

This is Phase 5 of the design flow — a **Choice**:

| Model | Appliances | When |
|-------|-----------|------|
| **Simple / Standard** | ~7 management appliances; **single NSX Manager**; single-node management services | Labs, PoCs, minimal footprint, non-critical |
| **Highly Available (HA)** | ~13 management appliances; **3-node NSX Manager cluster**; HA management services | Production — the default answer |

The cost of an HA management plane is small relative to a failed SDDC Manager
during a critical operation. Choose HA for anything production.

This framework expresses the choice through the number of NSX manager
hostnames and the fleet component blocks in `site.yaml`
(see [doc 09 — Sizing](09-sizing-and-bom.md) and
[doc 03 — NSX](03-nsx-edge-design.md)).

## Consolidated vs standard architecture

| Architecture | Description | Blueprint |
|--------------|-------------|-----------|
| **Consolidated / minimal footprint** | Management and workload components share the **first vSphere cluster** of the management domain | *VCF Fleet in a Single Site with Minimal Footprint* |
| **Standard** | Workloads are isolated into **separate workload domains**; management services are HA | *VCF Fleet in a Single Site* and larger |

Minimal footprint is ideal for labs and edge; standard is the production
baseline. This repo's stages support both — minimal footprint simply runs
stages `00`–`10` (+ Supervisor on the management cluster), while standard adds
stages `20`–`60`.

## Design Blueprints

Blueprints are prescriptive, end-to-end topologies for a design profile. Pick
the one that matches your requirements, then substitute individual models from
the Design Library as needed. The VCF 9.1 catalog:

**Infrastructure (pick your foundation profile):**

- **VCF Fleet in a Single Site with Minimal Footprint** — mgmt + workloads in
  one cluster, single AZ. *(lab / edge / smallest production)*
- **VCF Fleet in a Single Site** — HA management, workloads in a separate
  workload domain, one datacenter/AZ. *(most common production start)*
- **VCF Fleet with Multiple Sites in a Single Region** — metro/stretched.
- **VCF Fleet with Multiple Sites Across Multiple Regions** — multi-region.
- **… plus a Single Region + Additional Region(s)** variant.

**Operations & management:** Fleet Management; Monitoring & Alerting;
Troubleshooting.

**Edge:** Single Node with Argo CD; Government & Defense; Manufacturing.

**Consumption:** Self-Service Multi-Tenant Private Cloud; vSphere Kubernetes
Service (VKS); Private AI Services.

**Security & protection:** Lateral Security with vDefend; Component Backup and
Restore; Instance Backup and Restore; Fleet Disaster Recovery; Cyber Recovery.

### Which blueprint for a greenfield build?

| If you want… | Start with |
|--------------|-----------|
| A lab / smallest possible footprint | Single Site with Minimal Footprint |
| A production first fleet in one datacenter | **Single Site** (HA management + workload domain) |
| Metro / dual-AZ resilience | Multiple Sites in a Single Region (stretched) |
| Geographic DR | Multiple Sites Across Multiple Regions |

Layer a **Consumption** blueprint (VKS / Multi-Tenant / Private AI) and a
**Protection** blueprint (Backup / DR / Cyber Recovery) on top of whichever
infrastructure blueprint you choose.

## Sizing models

The **VCF Fleet Sizing Model** governs capacity for fleet components based on
the number of instances/domains/hosts you expect. Use the **VCF Planning and
Preparation Workbook** and the **vSAN Sizer** (see [doc 09](09-sizing-and-bom.md))
to right-size before bring-up.

## Sources

- [Architectural Options in VCF](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/vmware-cloud-foundation-concepts.html)
- [Design Blueprints — Infrastructure Modernization](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-blueprints-for/infrastructure-modernization.html)
- [Workload Domains in VCF (taxonomy)](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/overview-of-vmware-cloud-foundation-9/workload-domains-in-vmware-cloud-foundation.html)
