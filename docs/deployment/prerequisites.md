# Prerequisites

Work through this checklist completely before touching Terraform. Nearly
every failed bring-up traces back to a line on this page.

## 1. Hardware

| Item | Requirement |
|------|-------------|
| Seed hosts (management domain) | 4x ESXi hosts, vSAN ReadyNodes (ESA preferred) |
| Workload hosts | 3+ per planned cluster (4 recommended) |
| NICs | 2x 10 GbE minimum per host (25 GbE recommended) |
| Boot device | 128 GB+ persistent boot device per host |
| Physical fabric | 802.1Q trunks to all hosts, MTU 9000 end-to-end on storage/overlay VLANs |

## 2. Software downloads (Broadcom Support Portal)

- ESXi 9.1 installer ISO (version matching the VCF 9.1 BOM)
- VCF 9.1 Installer appliance OVA
- VCF 9.1 binary bundle (online depot credentials, or the offline bundle)

## 3. ESXi host preparation

Every host, before it appears in `site.yaml`:

- [ ] Fresh ESXi install of the exact BOM version (no upgrades, no leftovers)
- [ ] Management IP, VLAN, gateway configured on vmk0
- [ ] FQDN set (matching DNS below), not `localhost.localdomain`
- [ ] NTP configured and running (`ntpd`/`chronyd` synced)
- [ ] SSH enabled
- [ ] All non-boot disks empty (no stale vSAN or VMFS partitions)
- [ ] Same root password on all hosts in a stage (per stage secrets file)

## 4. DNS

Forward **and reverse** records for every name in `site.yaml`:

| Component | Example |
|-----------|---------|
| VCF Installer | `vcf-installer.vcf.example.com` |
| Every ESXi host | `m01-esx01..04`, `w01-esx01..04` |
| SDDC Manager | `sddc-manager` |
| Management vCenter | `vc-mgmt-01` |
| Management NSX VIP + nodes | `nsx-mgmt-01`, `nsx-mgmt-01a..c` |
| Fleet components (if used) | `ops-01a`, `ops-collector-01`, `fleet-01`, `auto-01` |
| WLD vCenter | `vc-wld-01` |
| WLD NSX VIP + nodes | `nsx-wld-01`, `nsx-wld-01a..c` |
| Edge nodes | `en01`, `en02` |

Verify everything at once:

```bash
make preflight
```

## 5. NTP

One or two reachable NTP servers, and **the same source everywhere**: DNS
server, physical hosts, your workstation. Clock skew between components is
one of the most common silent bring-up killers.

## 6. Network fabric

- [ ] All VLANs from `site.yaml` trunked to all relevant hosts
- [ ] Gateways exist for management, vMotion, vSAN, TEP and uplink VLANs
- [ ] MTU 9000 configured on switch ports for vSAN / vMotion / TEP VLANs
- [ ] Host TEP VLAN routable to edge TEP VLAN
- [ ] Fabric routers configured for eBGP on the two edge uplink VLANs
      (peer ASN and addresses matching `edge_clusters` in `site.yaml`)

## 7. Workstation / runner

- Terraform >= 1.7
- `ovftool` (stage 00)
- `python3` with PyYAML (`pip3 install pyyaml`) for the helper scripts
- `make`, `openssl`, `ssh-keyscan` (thumbprint collection)
- Network reachability to the management VLANs (or run from a jump host)

## 8. Passwords

Prepare passwords that satisfy VCF policy (12+ chars for appliances, 15+
for NSX edge accounts; upper/lower/digit/special). Fill them into each
stage's `secrets.auto.tfvars` (copied from the `.example` files). Consider
sourcing them from a secrets manager as `TF_VAR_*` environment variables
instead of files.
