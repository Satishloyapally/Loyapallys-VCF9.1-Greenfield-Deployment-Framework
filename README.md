# Loyapally's VCF 9.1 Greenfield Deployment Framework

Deploy a complete VMware Cloud Foundation 9.1 private cloud — from four empty
ESXi hosts to a running Kubernetes Supervisor — from **one YAML file**. This
framework targets **VCF 9.1 only**.

```text
iac/config/site.yaml  ──►  numbered Terraform stages  ──►  running VCF 9.1 fleet
(the whole site,           (isolated state, explicit       (management + workload
 described once)            hand-offs, no copy-paste)       domains, NSX, K8s)
```

## Repository layout

The repo is organized into three clearly separated areas — **code**,
**design**, and **deployment/operations docs**:

```text
.
├── iac/                     # ── INFRASTRUCTURE-AS-CODE (everything Terraform) ──
│   ├── config/              #   site.example.yaml — the single source of truth (+ schema)
│   ├── modules/             #   typed, reusable building blocks
│   │   ├── management-domain/   vcf_instance bring-up (+ optional fleet components)
│   │   ├── network-pool/        SDDC Manager address pools
│   │   ├── host-commission/     free-host inventory
│   │   ├── workload-domain/     vcf_domain with multi-cluster support
│   │   ├── edge-cluster/        NSX edges, Tier-0, eBGP
│   │   └── supervisor/          Workload Management + K8s content library
│   ├── stages/              #   00..60 — one dir per lifecycle phase, isolated state
│   └── scripts/             #   preflight.sh, deploy-installer.sh, thumbprints.sh
│
├── docs/
│   ├── design/              # ── DESIGN — Broadcom-aligned VCF 9.1 design guide ──
│   ├── deployment/          # ── DEPLOYMENT — how to build it ──
│   │   ├── prerequisites.md, architecture.md
│   │   ├── deployment-runbook.md      (automated / Terraform)
│   │   └── manual-deployment-guide.md (manual / UI)
│   └── operations/          # ── OPERATIONS — day-2 ──
│       ├── day2-operations.md, troubleshooting.md
│
├── Makefile                 # stage driver (fmt, validate, preflight, plan/apply)
└── README.md
```

> Where to start: **build it** → [docs/deployment/](docs/deployment/) ·
> **design it** → [docs/design/](docs/design/) ·
> **the code** → [iac/](iac/).

## Why this exists

Most VCF automation falls into one of two traps: a **monolith** (one giant
root module where a typo in an edge uplink can taint the management domain
state) or a **copy-paste pipeline** (per-stage tfvars files that repeat the
same hostnames and subnets five times and drift apart). This framework
takes a third path:

- **Single source of truth** — `iac/config/site.yaml` describes the entire
  site once: addressing, hostnames, VLANs, cluster layout, optional
  components. Every stage reads it; no value is ever written twice.
- **Isolated stages, explicit hand-offs** — each lifecycle phase owns its
  own Terraform state. Where data must flow between phases (host UUIDs
  from commissioning → workload domain), stages read each other's state;
  operators never copy IDs by hand.
- **Secrets never touch the config** — the site definition is reviewable
  and committable; passwords are typed `sensitive` variables in
  git-ignored files or environment variables.
- **Fail in seconds, not hours** — `make preflight` verifies DNS
  (forward *and* reverse), NTP and host reachability against `site.yaml`
  before you start a multi-hour bring-up.

## What gets deployed

| Stage (`iac/stages/`) | Deploys | Tool / Provider |
|-----------------------|---------|-----------------|
| `00-installer` | VCF Installer appliance onto a seed ESXi host | `ovftool` script |
| `10-management-domain` | Full bring-up: management vCenter, NSX, SDDC Manager, vSAN — plus optional VCF Operations, Collector, Fleet Management and Automation | `vmware/vcf` |
| `20-network-pools` | vMotion/vSAN address pools for workload capacity | `vmware/vcf` |
| `30-host-commission` | Workload hosts into the SDDC Manager inventory | `vmware/vcf` |
| `40-workload-domain` | VI domains: dedicated vCenter + NSX + vSAN clusters | `vmware/vcf` |
| `50-edge-cluster` | NSX edge clusters with Tier-0 + eBGP to the fabric | `vmware/vcf` |
| `60-supervisor` | vSphere Kubernetes (Workload Management) with NSX networking and a subscribed K8s release library | `vmware/vsphere` + `vmware/nsxt` |

## Deployment sequence (aligned with Broadcom VCF 9.1)

The stages follow the official Broadcom VMware Cloud Foundation 9.1 deployment
flow exactly. Two steps are performed once in the VCF Installer / VCF
Operations UI (they are not `vmware/vcf` resources); they are called out as
**manual gates** so the end-to-end order is complete and unambiguous.

| # | Broadcom VCF 9.1 step | This framework | Automated |
|---|---------------------|----------------|-----------|
| 1 | Prerequisites: DNS (A + PTR), NTP, VLANs, host prep, passwords | `make preflight` + [prerequisites](docs/deployment/prerequisites.md) | ✅ preflight |
| 2 | Deploy the **VCF Installer** appliance | `iac/stages/00-installer` (`iac/scripts/deploy-installer.sh`) | ✅ |
| 3 | Configure **depot**, download binaries, apply the activation code | **manual gate** in the Installer UI (see runbook §1) | ⛔ UI/API |
| 4 | **Management domain bring-up** — vCenter → vSAN → NSX → SDDC Manager → VCF Operations → VCF Automation | `iac/stages/10-management-domain` (`vcf_instance`) | ✅ |
| 5 | **License & register** the fleet in VCF Operations | **manual gate** in VCF Operations (see runbook §3) | ⛔ UI/API |
| 6 | Create **network pool** for workload capacity | `iac/stages/20-network-pools` (`vcf_network_pool`) | ✅ |
| 7 | **Commission ESX hosts** into the pool | `iac/stages/30-host-commission` (`vcf_host`) | ✅ |
| 8 | Create **VI workload domain** (dedicated vCenter + NSX) | `iac/stages/40-workload-domain` (`vcf_domain`) | ✅ |
| 9 | Deploy **NSX Edge cluster** (Tier-0 + BGP / VPC + Transit Gateway) | `iac/stages/50-edge-cluster` (`vcf_edge_cluster`) | ✅ |
| 10 | Activate **Supervisor** (needs domain + networking + storage) | `iac/stages/60-supervisor` (`vmware/vsphere` + `vmware/nsxt`) | ✅ |

Order that is easy to get wrong and is enforced here: the **network pool
(step 6) is created before hosts are commissioned (step 7)**, because a host
is commissioned *into* an existing pool; and the **edge cluster (step 9) is
deployed before the Supervisor (step 10)**, because Supervisor ingress/egress
rides the Tier-0.

Sources: Broadcom TechDocs (VCF 9.1) —
[Paths to Building 9.1 Environments](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/overview-of-deploy--converge--and-upgrade.html),
[Deploy a New VCF Fleet or Instance](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/deploying-a-new-vmware-cloud-foundation-or-vmware-vsphere-foundation-private-cloud-/deploy-a-new-vcf-fleet-or-a-new-vcf-instance.html),
[VCF Fleet Minimal-Footprint blueprint](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/blueprints/vcf-fleet-basic-management-design/implementation-of.html),
[Network Pool Management](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/host-management/about-network-pools.html).

## Quick start

```bash
# 1. Describe your site (the only file you have to think about)
cp iac/config/site.example.yaml iac/config/site.yaml
vi iac/config/site.yaml

# 2. Prove the environment is ready (DNS, NTP, host reachability)
make preflight

# 3. Deploy the installer appliance (greenfield: no vCenter needed)
export ESXI_PASSWORD='...' INSTALLER_ADMIN_PASSWORD='...' INSTALLER_ROOT_PASSWORD='...'
./iac/scripts/deploy-installer.sh /path/to/VCF-SDDC-Manager-Appliance-9.1.0.0.ova

# 4. Walk the stages (each has a secrets.auto.tfvars.example to copy first)
make apply STAGE=10-management-domain     # 2-4 h : the entire management domain
make apply STAGE=20-network-pools
make apply STAGE=30-host-commission
make apply STAGE=40-workload-domain      # 1-2 h : per workload domain
make apply STAGE=50-edge-cluster         # ~1 h  : T0 + BGP
make apply STAGE=60-supervisor           # 30-60m: Kubernetes on the cluster
```

Prefer clicking through the UI? See the
[manual deployment guide](docs/deployment/manual-deployment-guide.md). Full
automated instructions: [deployment runbook](docs/deployment/deployment-runbook.md).

## Documentation

### Design — how to design the fleet ([docs/design/](docs/design/))

A Broadcom-aligned VCF 9.1 greenfield design guide — Architectural Options,
Design Blueprints, and per-component design decisions (with `VCF-*` decision
IDs) mapped to what this framework deploys.

| Doc | Covers |
|-----|--------|
| [00 Methodology](docs/design/00-design-methodology.md) | 9-phase / 31-decision design flow → `site.yaml` |
| [01 Architecture models](docs/design/01-architecture-models.md) | Fleet/Instance/Domain, deployment models, blueprint catalog |
| [02 Network](docs/design/02-network-design.md) | VLAN/subnet model, MTU rules, teaming, consumption model |
| [03 NSX & edge](docs/design/03-nsx-edge-design.md) | NSX Manager, Tier-0/edge, eBGP/ECMP, connectivity models |
| [04 Storage](docs/design/04-storage-design.md) | vSAN ESA, Auto-RAID, FTT/host-count sizing |
| [05 Compute & availability](docs/design/05-compute-availability-design.md) | Cluster models, vLCM, HA/DRS/EVC, AZs |
| [06 Supervisor](docs/design/06-supervisor-design.md) | Control plane, zones, networking, storage, backup |
| [07 Security & identity](docs/design/07-security-identity-design.md) | SSO, certificates, FIPS, vDefend |
| [08 Lifecycle & operations](docs/design/08-lifecycle-operations-design.md) | VCF Operations, depot, upgrades, backup/restore |
| [09 Sizing & BOM](docs/design/09-sizing-and-bom.md) | Appliance sizes, host minimums, sizing tools |
| [10 Design decisions register](docs/design/10-design-decisions-register.md) | The defaults this framework makes, in Broadcom register form |

### Deployment — how to build it ([docs/deployment/](docs/deployment/))

| Doc | Contents |
|-----|----------|
| [prerequisites.md](docs/deployment/prerequisites.md) | Hardware, DNS/NTP, fabric and host-prep checklist |
| [architecture.md](docs/deployment/architecture.md) | Framework pipeline, isolated state, network reference model |
| [deployment-runbook.md](docs/deployment/deployment-runbook.md) | End-to-end **automated** deployment, stage by stage |
| [manual-deployment-guide.md](docs/deployment/manual-deployment-guide.md) | End-to-end **manual (UI-driven)** deployment, mirroring the stages |
| [iac/config/README.md](iac/config/README.md) | Site definition (`site.yaml`) schema reference |

### Operations — day-2 ([docs/operations/](docs/operations/))

| Doc | Contents |
|-----|----------|
| [day2-operations.md](docs/operations/day2-operations.md) | Expansion, drift, rotation, upgrades |
| [troubleshooting.md](docs/operations/troubleshooting.md) | Failure catalog organized by stage |

## Requirements

- Terraform >= 1.7 with the official providers pinned to their VCF 9.1
  releases — `vmware/vcf` >= 0.18, `vmware/vsphere` >= 2.16, `vmware/nsxt`
  >= 3.12 (no custom binaries)
- `ovftool`, `python3` + PyYAML, `make`
- VCF 9.1 entitlement (VCF 9.1 Installer OVA + 9.1 binary bundle from the
  Broadcom Support Portal)
- 4+ vSAN-capable ESXi hosts for the management domain, 3+ per workload
  cluster

## Design notes

Lab-friendly defaults are honest, not hidden: thumbprint validation is
skipped by default (pin it for production via `iac/scripts/thumbprints.sh` and
`skip_host_thumbprint_validation = false`), self-signed TLS is accepted
until you replace certificates, and single-node NSX is allowed for labs
while three-node is the documented production shape.

Every stage runs `terraform validate` in CI against the real provider
schemas, and the shell scripts are shellcheck-clean. Provider dependency
lock files (`.terraform.lock.hcl`) are committed per stage so provider
versions and hashes are reproducible across machines and CI.

The long-running resources (management bring-up, workload domains, edge
clusters) expose an optional `timeouts:` block in `site.yaml`, so multi-hour
operations can be bounded explicitly instead of relying on provider defaults.

## License

[MIT](LICENSE)
