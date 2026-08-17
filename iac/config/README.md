# Site Definition

This directory holds the **single source of truth** for a deployment.

```bash
cp site.example.yaml site.yaml   # site.yaml is git-ignored
```

Every Terraform stage reads `site.yaml` (via `yamldecode`), so the whole
site — addressing, hostnames, VLANs, cluster layout, optional components —
is described exactly once. Changing the design means editing one file.

## Schema at a glance

| Key                 | Consumed by | Purpose |
|---------------------|-------------|---------|
| `site`              | all stages  | Site name, DNS domain/servers, NTP, CEIP/FIPS |
| `vcf`               | stage 10    | VCF release version (9.1.x only) |
| `installer`         | stage 00    | VCF Installer appliance placement and addressing |
| `management_domain` | stage 10    | Seed hosts, networks, DVS, vSAN, appliances, fleet components |
| `network_pools`     | stage 20    | vMotion/vSAN/NFS address pools for workload capacity |
| `commission_hosts`  | stage 30    | Hosts added to the SDDC Manager free-host inventory |
| `workload_domains`  | stage 40    | VI domains: vCenter, NSX, clusters (hosts by FQDN) |
| `edge_clusters`     | stage 50    | NSX edge clusters with Tier-0/BGP design |
| `supervisors`       | stage 60    | vSphere Kubernetes enablement per cluster |

## Rules

- **No passwords in this file, ever.** Secrets live in each stage's
  git-ignored `secrets.auto.tfvars` (see the `.example` files) or in
  `TF_VAR_*` environment variables.
- Hostnames under `management_domain` may be short names or FQDNs;
  everything under `workload_domains` uses FQDNs.
- Optional blocks (`operations`, `automation`, `sso`, ...) are simply
  deleted if not wanted — stages treat missing keys as "do not deploy".
- Cluster host lists in `workload_domains` reference hosts by FQDN; the
  workload-domain stage resolves them to SDDC Manager UUIDs automatically
  through the host-commission stage's state.

Validate the environment against the file at any time:

```bash
make preflight
```
