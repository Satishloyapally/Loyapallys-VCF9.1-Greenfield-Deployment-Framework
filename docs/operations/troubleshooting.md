# Troubleshooting

Organized by stage. First response to any failure: **re-run
`make preflight`** — environment drift (DNS, NTP, reachability) causes the
majority of mid-deployment failures.

## General

| Symptom | Likely cause / fix |
|---------|--------------------|
| Terraform hangs then times out on apply | The VCF task is still running server-side. Check the installer / SDDC Manager task view before retrying; never `apply` twice concurrently. |
| `x509: certificate signed by unknown authority` | Self-signed certs. Stages default `allow_unverified_tls = true`; if you disabled it, install proper certs first. |
| Provider auth failures after bring-up | Stages 20+ authenticate as `administrator@vsphere.local` against SDDC Manager, not `admin@local`. |

Useful logs:

```bash
export TF_LOG=DEBUG TF_LOG_PATH=./terraform-debug.log   # provider API traffic
```

- VCF Installer: `/var/log/vmware/vcf/` on the appliance, plus the UI task view
- SDDC Manager: UI → Tasks, or `/var/log/vmware/vcf/domainmanager/` on the appliance
- Supervisor: `/var/log/vmware/wcp/wcpsvc.log` on the workload domain vCenter

## Stage 00 — Installer

| Symptom | Fix |
|---------|-----|
| `ovftool` fails to connect to ESXi | Host not reachable on 443, or root password wrong. `curl -k https://<host>` to confirm. |
| Appliance boots but UI never answers | Wrong netmask/gateway in `site.yaml`, or the port group VLAN doesn't match the appliance IP subnet. Check the VM console. |
| UI up but bundle download fails | Depot credentials, or the appliance can't reach the internet — use the offline bundle transfer utility. |

## Stage 10 — Bring-up

| Symptom | Fix |
|---------|-----|
| Validation fails immediately | Read the installer UI validation report — it names the exact host/record/VLAN at fault. Fix, then `terraform apply` again (the resource retries). |
| Host validation: "disk not eligible" | Stale partitions on the seed hosts. Wipe non-boot disks and retry. |
| NSX manager deployment stalls at ~60% | Almost always NTP skew or missing reverse DNS for the NSX nodes. |
| vSAN datastore creation fails | ESA enabled on non-ESA hardware — set `management_domain.vsan.esa_enabled: false`. |
| Bring-up failed halfway; what now? | Fix the cause, re-apply — the installer resumes its task. If the environment is irrecoverable, reimage the seed hosts and start stage 10 clean (delete its state). Do not hand-edit half-deployed appliances. |

## Stages 20/30 — Pools and commissioning

| Symptom | Fix |
|---------|-----|
| Commission fails: "network pool not found" | The pool name in `commission_hosts` must exactly match a key under `network_pools` (stage 20 applied first). |
| Commission fails on storage validation | `storage_type` mismatch: `VSAN_ESA` on hosts without ESA-capable disks (or vice versa). |
| Host stuck `COMMISSIONING` | Check the SDDC Manager task; usually SSH disabled or wrong root password. |

## Stage 40 — Workload domain

| Symptom | Fix |
|---------|-----|
| `host_ids` lookup error on plan | The cluster's `hosts` list contains an FQDN that stage 30 never commissioned. Names must match `commission_hosts` exactly. |
| "insufficient hosts" | Hosts still assigned to another domain, or in `UNASSIGNED_ERROR`. Decommission/recommission the affected host. |
| NSX manager IPs unreachable after deploy | The WLD NSX managers deploy onto the **VM management** network — confirm `nsx.gateway`/`subnet_mask` match that VLAN, not the workload VLANs. |

## Stage 50 — Edge cluster

| Symptom | Fix |
|---------|-----|
| TEP routability validation fails | Host TEP and edge TEP VLANs are not routed to each other. For collapsed lab designs set `skip_tep_routability_check: true` for that edge cluster in `site.yaml`. |
| BGP sessions never establish | Fabric side: peer IP/ASN mismatch or the uplink VLANs are not trunked to the hosts running the edge nodes. Verify from NSX: Tier-0 → BGP → session state. |
| Edge VM deploy fails with password error | Edge accounts require 15+ character passwords. |

## Stage 60 — Supervisor

| Symptom | Fix |
|---------|-----|
| Enable stuck at `CONFIGURING` | Watch `wcpsvc.log` on the WLD vCenter. Most common: control-plane management IPs (5 consecutive from `starting_address`) collide with something, or DNS/NTP unreachable from that subnet. |
| Content library sync fails | vCenter cannot reach `wp-content.vmware.com` — provide an internal mirror via `content_library.subscription_url`. |
| Ingress VIP unreachable from outside | `ingress_cidr` is not being advertised: check Tier-0 route advertisement and fabric BGP (stage 50). |
| `storage policy not found` | The example uses `vSAN Default Storage Policy`, which exists on every vSAN cluster. If you renamed it, update `supervisors.<name>.storage_policy`. |

## Destroying

Destroy in strict reverse order (60 → 50 → 40 → 30 → 20). Stage 10 has no
meaningful destroy: decommissioning a management domain means reimaging
the hosts. Delete stage 10's local state afterwards if you are rebuilding.
