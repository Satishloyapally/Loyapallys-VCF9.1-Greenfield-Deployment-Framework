# VCF 9.1 Greenfield Design Documentation

This directory is a **design companion** to the Terraform automation in this
repository. The Terraform stages *build* a VMware Cloud Foundation 9.1 fleet;
these documents explain **how to design it well** for a greenfield
deployment, distilled from the official Broadcom VCF 9.1 design guidance and
mapped to what this framework actually deploys.

> Scope: greenfield (net-new) VCF 9.1 fleets — a management domain plus one or
> more VI workload domains, NSX edge/routing, and (optionally) vSphere
> Supervisor. Convergence of existing vSphere/vCenter estates is out of scope.

## How Broadcom structures VCF design (and how these docs mirror it)

Broadcom's [VCF 9.1 Design guide](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design.html)
is organized into three layers. These docs follow the same model:

| Broadcom layer | What it is | Where it lives here |
|----------------|-----------|---------------------|
| **Architectural Options** | High-level component models and their trade-offs | [01-architecture-models.md](01-architecture-models.md) |
| **Design Blueprints** | Prescriptive end-to-end topologies for a design profile | [01-architecture-models.md](01-architecture-models.md#design-blueprints) |
| **Design Library** | Detailed requirements/recommendations per component | the component docs below |

Every Broadcom design statement is one of three **design element types**, and
these docs preserve that vocabulary:

| Element | Meaning |
|---------|---------|
| **Requirement** (`REQD`) | Mandatory for VCF to operate — no deviation. |
| **Recommendation** (`RCMD`) | Best practice — deviation allowed with justification. |
| **Choice** | Pick one of several supported models. |

Where a decision maps to a specific Broadcom decision ID (for example
`VCF-CLS-RCMD-CFG-001`), it is cited so you can trace it back to the source.

## The design set

| # | Document | Covers |
|---|----------|--------|
| 0 | [00-design-methodology.md](00-design-methodology.md) | The 9-phase / 31-decision design flow; how decisions map to `iac/config/site.yaml` |
| 1 | [01-architecture-models.md](01-architecture-models.md) | Fleet / Instance / Domain taxonomy; deployment & sizing models; blueprint catalog + which greenfield blueprint to pick |
| 2 | [02-network-design.md](02-network-design.md) | VLAN/subnet reference model, MTU rules, teaming, DVS, network consumption model |
| 3 | [03-nsx-edge-design.md](03-nsx-edge-design.md) | NSX Manager models, Edge cluster & Tier-0 design, eBGP/ECMP, connectivity models |
| 4 | [04-storage-design.md](04-storage-design.md) | vSAN ESA, Auto-RAID, FTT/host-count sizing, principal storage, alternatives |
| 5 | [05-compute-availability-design.md](05-compute-availability-design.md) | Cluster models, vLCM images, HA/DRS/EVC/admission control, AZs/fault domains |
| 6 | [06-supervisor-design.md](06-supervisor-design.md) | vSphere Supervisor control plane, zones, networking, storage, content library, backup |
| 7 | [07-security-identity-design.md](07-security-identity-design.md) | SSO/identity, certificates, password policy, FIPS, vDefend lateral security |
| 8 | [08-lifecycle-operations-design.md](08-lifecycle-operations-design.md) | VCF Operations, depot/bundles, upgrades, backup/restore, monitoring |
| 9 | [09-sizing-and-bom.md](09-sizing-and-bom.md) | Appliance sizes, host minimums, sizing tools, worked minimal-footprint example |
| 10 | [10-design-decisions-register.md](10-design-decisions-register.md) | The design decisions this framework makes by default, in Broadcom register form |

## Authoritative sources

These documents synthesize and cite Broadcom Technical Documentation; they do
not replace it. Always confirm against the current source for your exact
build:

- [VCF 9.1 Design](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design.html)
- [Architectural Options](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/vmware-cloud-foundation-concepts.html)
- [Design Blueprints](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-blueprints-for/infrastructure-modernization.html)
- [Design Library](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library.html)
- [VCF 9.1 Release Notes / Configuration Maximums](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1.html)
