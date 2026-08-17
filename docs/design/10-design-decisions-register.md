# 10 — Design Decisions Register

A design decisions register records **what was decided, why, and the
implication** — the format Broadcom uses throughout the Design Library. The
table below captures the decisions this framework makes **by default** for a
greenfield VCF 9.1 build (aligned to the *Single Site* / *Minimal Footprint*
blueprints). Use it as the starting point for your own design record: change a
value in `iac/config/site.yaml`, update the row, and note the justification.

Legend: **R** = Requirement, **C** = Recommendation/Choice (deviation allowed).

## Platform & architecture

| ID | Type | Decision | Rationale | Implication | site.yaml |
|----|------|----------|-----------|-------------|-----------|
| D-ARCH-01 | C | Deploy VCF **9.1** only | Target release; providers pinned to 9.1 line | Non-9.1 versions are rejected by a validation guard | `vcf.version: 9.1.0.0` |
| D-ARCH-02 | C | **Single Site** blueprint (HA management + separate workload domain) | Production baseline in one datacenter | More appliances than minimal footprint | stages 00–60 |
| D-ARCH-03 | C | Management services **HA** for production (Simple for labs) | Protects SDDC Mgr/vCenter/NSX | ~13 appliances; ≥ 4 hosts | NSX manager count + fleet blocks |
| D-ARCH-04 | R | Management domain created first by the VCF Installer | VCF bring-up order | SDDC Manager/vCenter/NSX/Operations/Automation in mgmt domain | stage 10 |

## Compute & availability

| ID | Type | Decision | Rationale | Implication | Ref |
|----|------|----------|-----------|-------------|-----|
| D-CLS-01 | R | **vLCM images** for all clusters | Baselines unsupported in 9.x | Must transition any baseline cluster before ESX 9.x | `VCF-CLS-REQD-CFG-003` |
| D-CLS-02 | R | **vSphere HA** protects all VMs | Host-failure resilience | Reserve failover capacity | `VCF-CLS-REQD-CFG-004` |
| D-CLS-03 | C | Admission control = **1 host, percentage-based** | Auto-calculated reservation | 4-host cluster → 3 hosts usable | `VCF-CLS-RCMD-CFG-001` |
| D-CLS-04 | C | **DRS** fully automated, medium | Balanced placement | — | `VCF-CLS-RCMD-CFG-003` |
| D-CLS-05 | C | **EVC** = highest common baseline | Non-disruptive upgrades | Single CPU vendor per cluster; set at bring-up | `VCF-CLS-RCMD-CFG-004/005` |
| D-CLS-06 | C | Management domain **4 hosts** | N+1 for FTT=1 RAID-5 | Grow to 7 for FTT=2 | doc 04 |

## Storage

| ID | Type | Decision | Rationale | Implication | Ref |
|----|------|----------|-----------|-------------|-----|
| D-STG-01 | C | **vSAN ESA** as principal storage | Default; Auto-RAID in 9.1 | Principal type immutable per cluster | `*.vsan.esa_enabled: true` |
| D-STG-02 | C | **FTT=1 (RAID-5, 2+1)**, 4-node | N+1 re-protect | Use 7 nodes for FTT=2 RAID-6 | `failures_to_tolerate: 1` |
| D-STG-03 | C | **Auto-RAID + Effective Capacity** | Removes reserved-capacity tuning | Do not enable legacy Host Rebuild Reserve on 4-node | doc 04 |
| D-STG-04 | C | NVMe TLC, Class F, ≥ 3 DWPD | Performance/durability balance | Size with vSAN Sizer | doc 09 |

## Network, NSX & routing

| ID | Type | Decision | Rationale | Implication | Ref |
|----|------|----------|-----------|-------------|-----|
| D-NET-01 | C | **Network consumption model** decided up front | Drives edge/LB/tenancy | Costly to change later | doc 02/03 |
| D-NET-02 | R | Overlay MTU = **TEP − 200** | Geneve DF | Jumbo end-to-end | `VCF-NET-REQD-OVL-001` |
| D-NET-03 | C | Uplink/BGP VLAN MTU **9000** | BGP throughput | End-to-end jumbo | `VCF-NET-RCMD-MTU-006` |
| D-NET-04 | C | TEP port group teaming **active/standby** | TEP failover requirement | Peering VLANs share trunk | doc 02 |
| D-NSX-01 | C | NSX Manager **HA (3-node)** for prod (Simple for lab) | Availability | ≥ 4 hosts; VM anti-affinity | Simple/HA model |
| D-EDG-01 | C | Tier-0 **Active/Active (ECMP)** | Max north-south, up to 8 edges | No stateful services on T0 | `VCF-WLDCON-CTGW-RCMD-CFG-001` |
| D-EDG-02 | C | **eBGP**, unique private ASN | Scalable fabric interconnect | Physical switches must support eBGP | `VCF-WLDCON-NSXSEG-RCMD-CFG-002` |
| D-EDG-03 | C | Tier-1 **DR-only** | ECMP distribution across edges | Attach to edge only for centralized services | `VCF-WLDCON-NSXSEG-RCMD-CFG-021` |
| D-EDG-04 | C | **2 edge nodes** minimum | HA | Scale to 8 for A/A | doc 03 |

## Supervisor (optional)

| ID | Type | Decision | Rationale | Implication | Ref |
|----|------|----------|-----------|-------------|-----|
| D-SUP-01 | C | **3 CP VMs** (three-zone for cluster HA) | Rolling upgrades + node/AZ failure | Extra resources; 3 zones for zonal HA | `VCF-SUP-CP-RCMD-CFG-001` |
| D-SUP-02 | R | **5 consecutive routable mgmt IPs** | CP IPs + floating + patch | Reserve range | `VCF-SUP-CP-REQD-CFG-001` |
| D-SUP-03 | C | Ingress/egress CIDRs **advertised by Tier-0** | External reachability | Edge cluster must be healthy first | doc 06 |
| D-SUP-04 | C | Subscribed **content library** to Software Depot | K8s release feed | Depot reachable | doc 06 |

## Security & identity

| ID | Type | Decision | Rationale | Implication | Ref |
|----|------|----------|-----------|-------------|-----|
| D-SEC-01 | C | SSO: **join management SSO** (isolated per tenant) | Simpler ops | Set `sso.domain_name` for isolation | doc 07 |
| D-SEC-02 | C | **FIPS** decided at bring-up | Immutable afterward | `fips_enabled: false` default | doc 07 |
| D-SEC-03 | R | No secrets in `site.yaml` | Reviewable config | Passwords in git-ignored tfvars / `TF_VAR_*` | doc 07 |
| D-SEC-04 | C | Replace self-signed certs for production | Trust | Choose ESXi cert mode (VMCA/Custom) | doc 07 |

## Lifecycle & operations

| ID | Type | Decision | Rationale | Implication | Ref |
|----|------|----------|-----------|-------------|-----|
| D-OPS-01 | R | Depot + activation before bring-up | Bundles required | Manual gate (Installer UI) | runbook §1 |
| D-OPS-02 | R | License + register fleet in VCF Operations | Consumption gate | Manual gate | runbook §3 |
| D-OPS-03 | C | Backups: SDDC Mgr + vCenter (file-based, Supervisor option) + NSX; Velero for VKS data | Recoverability | Design targets/schedules | doc 08 |
| D-OPS-04 | C | Preflight DNS/NTP/reachability | Fail fast | `make preflight` before stage 10 | doc 08 |

---

### How to use this register

1. Copy this table into your project's design record.
2. For each deviation from the default, change the `site.yaml` value, flip the
   row, and write the **rationale** and **implication** — that is exactly the
   discipline Broadcom's Design Library enforces.
3. Cross-check every **R** (requirement) row is satisfied before bring-up.

### Sources

- [Design Library (all component detailed designs)](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library.html)
- Component docs 01–09 in this directory.
