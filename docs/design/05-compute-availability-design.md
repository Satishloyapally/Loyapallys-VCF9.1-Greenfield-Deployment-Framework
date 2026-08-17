# 05 — Compute & Availability Design

Covers vSphere cluster models, lifecycle management, and the availability
settings VCF applies to every cluster.

## Cluster models (Choice)

| Model | Description | Availability |
|-------|-------------|--------------|
| **vSphere Single-Rack Cluster** | Hosts in one rack, single availability zone | vSphere HA protects against host failure |
| **Stretched vSphere Cluster** | Hosts split across two availability zones + witness | Survives an AZ outage (metro HA) |

Host minimums: management domain **≥ 4**; workload vSAN cluster **≥ 3** (4
recommended); stretched **≥ 3 per AZ** plus a witness; a vSphere cluster
maximum of 32 hosts for a vSAN storage cluster.

## Lifecycle: vLCM images are required

- **vSphere Lifecycle Manager (vLCM) *images* are mandatory** for all clusters
  in VCF 9.x (`VCF-CLS-REQD-CFG-003`). vLCM **baselines are not supported** —
  any baseline-managed cluster must be transitioned to images before upgrading
  to ESX 9.x.
- Images give you a single, declarative desired-state per cluster (ESX version
  + vendor add-ons + firmware), which is what SDDC Manager / VCF Operations
  drives during lifecycle operations.

## Availability settings VCF applies

These are applied per cluster; the recommendations carry Broadcom decision
IDs:

| Setting | Design point | ID |
|---------|--------------|----|
| **vSphere HA** | Enable to protect all VMs against host failure | `VCF-CLS-REQD-CFG-004` |
| **Admission control** | 1 host failure, **percentage-based** failover capacity (auto-calculated) | `VCF-CLS-RCMD-CFG-001` |
| **Admission control (stretched)** | Increase reservation to **half the hosts** so an AZ loss is survivable | `VCF-CLS-RCMD-CFG-008` |
| **DRS** | Fully automated, **medium** migration threshold | `VCF-CLS-RCMD-CFG-003` |
| **EVC** | Enable on management clusters; set to the **highest baseline common to all host CPUs** (same CPU vendor required) | `VCF-CLS-RCMD-CFG-004/005` |
| **VM Monitoring** | Enable per cluster | recommendation |
| **HA isolation address** | Set to the vSAN network gateway (and a second AZ gateway for stretched) | recommendation |
| **NSX Manager placement** | VM-VM **anti-affinity** so the 3 NSX managers sit on different hosts (needs ≥ 4 hosts) | `VCF-NSX-LM-RCMD-CFG-002` |

Consequences to plan for:
- Admission control for 1 host failure means a **4-host cluster only offers 3
  hosts' worth** of usable capacity; a **stretched 8-host cluster offers 4**.
  Size capacity accordingly.
- EVC requires a single CPU vendor per cluster and must be set on the default
  management cluster **during bring-up** (API + JSON spec).

## Availability zones & fault domains

- A **single AZ** (single-rack) is the greenfield default.
- **Stretched clusters** span two AZs with a **witness** in a third
  location/zone; used for metro HA and required for some multi-site
  blueprints.
- vSAN **fault domains** align to racks; one network pool per rack keeps
  addressing honest as you scale out.

## vSphere Cluster Services (vCLS)

VCF manages vCLS agent VMs automatically to keep DRS/HA control-plane services
available; do not manually delete them.

## How this framework expresses it

- Cluster availability defaults (HA/DRS/EVC/admission control) are applied by
  VCF during `vcf_instance` / `vcf_domain` creation — you generally do not
  override them.
- Cluster shape (host counts, EVC mode, HA toggle, geneve VLAN) comes from
  `management_domain` and `workload_domains.*.clusters.*` in `site.yaml`.
- For stretched designs, extend the storage design (doc 04) and increase
  admission-control reservation.

## Sources

- [vSphere Single-Rack Cluster Model](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/cluster-models/single-instance-single-availability-zone.html)
- [Stretched vSphere Cluster Model](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/cluster-models/single-instance-multiple-availability-zones.html)
- [Transition vLCM baselines to images](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/upgrading-cloud-foundation/upgrade-the-management-domain-to-vmware-cloud-foundation-5-2/vlcm-baseline-to-vlcm-image-cluster-transition-.html)
