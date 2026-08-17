# 00 — Design Methodology

Designing a greenfield VCF 9.1 fleet is a sequence of **decisions**, not a
pile of settings. Broadcom frames the process as **9 phases covering ~31
decisions**; the VCF Designer tool uses the same schema. This document walks
that flow and shows where each decision is expressed in this framework
(`iac/config/site.yaml` and the Terraform stages).

## The design flow (9 phases)

| Phase | Decisions (examples) | Expressed here |
|-------|----------------------|----------------|
| 1. **Blueprint / profile** | Which design blueprint (minimal footprint, single site, multi-site, multi-region) | choice of stages you run; sizing in `site.yaml` |
| 2. **Capabilities** | IaaS, Kubernetes (Supervisor), Private AI, vDefend, Edge, DR | which optional stages/blocks you enable |
| 3. **VCF Automation model** | Deploy VCF Automation? topology? | `management_domain.automation` block |
| 4. **Network consumption model** | VLAN / NSX Overlay Segments / VPC / Transit Gateway | edge + workload connectivity design (doc 03) |
| 5. **Management services model** | Standard vs Highly Available (SDDC Mgr, vCenter, NSX) | Simple vs HA appliance/NSX choices (doc 01, 09) |
| 6. **Domain model** | Management + workload domain topology; single vs multi-AZ | which workload domains/clusters in `site.yaml` |
| 7. **Storage model** | vSAN ESA / OSA / NFS / VMFS-FC / vVol; FTT | `*.vsan` blocks (doc 04) |
| 8. **Network / fabric** | VLANs, subnets, MTU, TEP pools, BGP/ASN | `management_domain.networks`, `edge_clusters` (doc 02, 03) |
| 9. **Security & operations** | SSO, certificates, FIPS, backup, monitoring | design docs 07, 08 |

> The single most consequential decision is **Phase 4, the Network Consumption
> Model** — it drives edge clusters, load balancers, and how workloads
> connect. Changing it mid-project means re-architecting the network. Decide
> it before you deploy stage 50.

## Design element types

Every statement in the Broadcom Design Library (and in these docs) is one of:

- **Requirement** — mandatory; deviation breaks support/operation.
- **Recommendation** — best practice; deviation is allowed if you record the
  justification and implication.
- **Choice** — select one supported model from a set.

Decision IDs follow the pattern `VCF-<AREA>-<REQD|RCMD>-<TYPE>-<NNN>`, e.g.
`VCF-CLS-RCMD-CFG-001` (a cluster recommendation). Cite them in your own
design record so reviews are traceable.

## Turning decisions into this framework

1. **Pick a blueprint** (doc 01) → determines how many domains/clusters and
   whether management services are HA.
2. **Fill `iac/config/site.yaml`** → the single source of truth; every stage
   reads it. Each design decision becomes a value or a block here.
3. **Walk the stages in order** (see the root runbook) → `00`→`10`→(license)
   →`20`→`30`→`40`→`50`→`60`. Ordering encodes hard dependencies (network
   pool before host commission; edge before Supervisor).
4. **Record deviations** → use the register in [doc 10](10-design-decisions-register.md).

## What a greenfield build minimally decides

For a first fleet, you must at least decide: blueprint profile; whether
management services are Simple or HA; storage (almost always vSAN ESA); the
network consumption model and BGP/ASN plan; management VLAN/subnet layout; and
whether you enable Supervisor. Everything else has a sensible Broadcom default
that this framework carries.

## Source

- [Designing VCF 9.1 — the decision flow](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design.html)
- [Architectural Options in VCF](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/vmware-cloud-foundation-concepts.html)
