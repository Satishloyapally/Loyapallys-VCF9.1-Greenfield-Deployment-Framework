# 08 — Lifecycle & Operations Design

In VCF 9.x, most day-1/day-2 operations move to **VCF Operations** (SDDC
Manager is de-emphasized and its workflows are surfaced through VCF
Operations). Design the operational model alongside the infrastructure.

## VCF Operations fleet components

Deployed in the management domain of the first VCF Instance:

| Component | Role |
|-----------|------|
| **VCF Operations** | Fleet build/manage/scale, lifecycle, monitoring, capacity |
| **VCF Operations Collector** | Remote data collection |
| **VCF Operations Fleet Management** | Cross-instance fleet management |
| **VCF Automation** | Self-service / catalog-driven provisioning (optional) |
| **License Server** | Solution licensing for the fleet |
| **VCF Operations for Networks** | Network monitoring/analytics (optional) |
| **Log Management** | Centralized logging (optional) |

This framework deploys the core set during bring-up via the `automation`,
`operations`, `operations_collector`, and `fleet_management` blocks in
`site.yaml` (any block can be omitted to skip that component). Monitoring/
alerting and VCF Operations for Networks follow the corresponding blueprints.

## Depot & binary bundles

- The **VCF Installer** and **VCF Operations** connect to the **Broadcom online
  depot** (support credentials + activation code) or use **offline bundles**
  for air-gapped sites.
- Bundles feed bring-up and every subsequent upgrade. Confirm the depot is
  reachable from VCF Operations after bring-up (manual gate — see runbook §3).

## Lifecycle (upgrades)

- Lifecycle is **image-based (vLCM images)** and orchestrated centrally.
  Baselines are not supported.
- Upgrade order matters: SDDC Manager/VCF Operations first, then vCenter, then
  ESX; transition any remaining baseline clusters to images before ESX 9.x.
- Record the target **BOM build** and set `vcf.version` in `site.yaml` to
  match reality after an upgrade.

## Backup & restore (design per component)

| Component | Mechanism |
|-----------|-----------|
| **SDDC Manager** | Scheduled configuration backup (SFTP target) |
| **vCenter** | File-based backup (with the **Supervisor** option when WCP is enabled) |
| **NSX Manager** | NSX backup to an SFTP server |
| **VKS workloads / data** | **Velero Plugin for vSphere** (separate from Supervisor backup) |

Follow the **Component Backup and Restore** / **Instance Backup and Restore**
blueprints; for DR and cyber-resilience use the **Fleet Disaster Recovery** and
**Cyber Recovery** blueprints.

## Monitoring & alerting

Use the **Monitoring & Alerting** blueprint: real-time metrics + log
management + VCF Operations for Networks. Establish alerts for capacity
(vSAN Effective Capacity), certificate expiry, BGP session state, and cluster
health before go-live.

## Preflight & validation (this framework)

- `iac/scripts/preflight.sh` validates DNS (forward + reverse), NTP, and host
  reachability against `site.yaml` **before** a multi-hour bring-up.
- CI runs `terraform fmt`/`validate` on every stage and shellcheck on scripts.

## Sources

- [VCF 9.1 Lifecycle Management](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1.html)
- [Design Library — VCF Operations / Log Management / Operations for Networks](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library.html)
- [Design Blueprints — Monitoring, Backup, DR, Cyber Recovery](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-blueprints-for/infrastructure-modernization.html)
