# Deployment Runbook

End-to-end greenfield deployment, in the official Broadcom VMware Cloud
Foundation 9.1 order. Times assume a healthy environment; all long stages are
driven by VCF and progress is visible in its UIs while Terraform waits.

Two steps (depot/binaries and fleet licensing) are performed in the VCF
Installer / VCF Operations UI — they are **manual gates**, not `vmware/vcf`
resources — and are called out below so the sequence is complete.

> Prefer to deploy entirely through the UI (no Terraform)? See the
> [manual deployment guide](manual-deployment-guide.md), which mirrors this
> same Broadcom sequence click-by-click.

| Phase | Broadcom step | What | How | Duration |
|-------|---------------|------|-----|----------|
| Prereqs | 1 | DNS/NTP/VLAN/host prep | `make preflight` | minutes |
| 00 | 2–3 | VCF Installer + depot + binaries | `iac/scripts/deploy-installer.sh` + UI | ~30 min |
| 10 | 4 | Management domain bring-up | `iac/stages/10-management-domain` | 2–4 h |
| gate | 5 | License & register the fleet | VCF Operations UI | ~10 min |
| 20 | 6 | Network pools | `iac/stages/20-network-pools` | ~1 min |
| 30 | 7 | Host commissioning | `iac/stages/30-host-commission` | ~20 min |
| 40 | 8 | Workload domain | `iac/stages/40-workload-domain` | 1–2 h |
| 50 | 9 | Edge cluster | `iac/stages/50-edge-cluster` | ~1 h |
| 60 | 10 | Supervisor | `iac/stages/60-supervisor` | 30–60 min |

## Prerequisites — describe the site (Broadcom step 1)

```bash
cp iac/config/site.example.yaml iac/config/site.yaml
vi iac/config/site.yaml                  # your addressing plan, hostnames, VLANs
make preflight                       # DNS (A + PTR), NTP, host reachability
```

`make preflight` must be all green before continuing. See
[prerequisites.md](prerequisites.md) for the DNS/NTP/VLAN worksheet.

## 1. Stage 00 — VCF Installer, depot and binaries (Broadcom steps 2–3)

Deploy the VCF Installer appliance onto a seed ESXi host:

```bash
export ESXI_PASSWORD='...'
export INSTALLER_ADMIN_PASSWORD='...'
export INSTALLER_ROOT_PASSWORD='...'
./iac/scripts/deploy-installer.sh ~/Downloads/VCF-SDDC-Manager-Appliance-9.1.0.0.ova
```

Then log in at `https://<installer-fqdn>` as `admin@local` and complete the
**depot gate** (Broadcom step 3) before running any Terraform:

1. **Configure the depot** — connect to the Broadcom online depot with your
   support credentials, or upload the offline binary bundle for air-gapped
   sites.
2. **Apply the activation code** generated from `vcf.broadcom.com`.
3. **Download all binaries** and wait until every component reports
   **Success**.

Terraform stage 10 cannot proceed until the bundle is available.

## 2. Stage 10 — Management domain bring-up (Broadcom step 4)

```bash
cd iac/stages/10-management-domain
cp secrets.auto.tfvars.example secrets.auto.tfvars && vi secrets.auto.tfvars
terraform init
terraform plan            # review: this is your entire management domain
terraform apply           # 2-4 hours
```

The Installer provisions in order: vCenter → vSAN → NSX → SDDC Manager →
VCF Operations → VCF Automation. Monitor in the Installer UI. When it
finishes:

```bash
terraform output          # sddc_manager_fqdn, vcenter_fqdn, nsx_vip_fqdn
```

## 3. Gate — License & register the fleet (Broadcom step 5)

Before consuming capacity, do this once in **VCF Operations** (no Terraform):

1. Open VCF Operations from the link in the Installer summary.
2. Register VCF Operations with Broadcom Business Services.
3. Add/assign the VCF fleet license (and vSphere/vSAN keys if you use
   key-based licensing) with sufficient feature scope.
4. Confirm the depot is reachable from VCF Operations for later bundle
   downloads.

## 4. Stage 20 — Network pools (Broadcom step 6)

A network pool must exist **before** hosts are commissioned — hosts are
commissioned *into* a pool.

```bash
cd ../20-network-pools
cp secrets.auto.tfvars.example secrets.auto.tfvars && vi secrets.auto.tfvars
terraform init && terraform apply
```

## 5. Stage 30 — Host commissioning (Broadcom step 7)

```bash
cd ../30-host-commission
cp secrets.auto.tfvars.example secrets.auto.tfvars && vi secrets.auto.tfvars
terraform init && terraform apply
```

Hosts appear as free capacity. Their UUIDs are exported in this stage's
state — stage 40 picks them up automatically (no hand-copying).

## 6. Stage 40 — Workload domain (Broadcom step 8)

```bash
cd ../40-workload-domain
cp secrets.auto.tfvars.example secrets.auto.tfvars && vi secrets.auto.tfvars
terraform init && terraform apply    # 1-2 hours per domain
```

## 7. Stage 50 — Edge cluster (Broadcom step 9)

Confirm the fabric routers are ready for eBGP first (peer IPs/ASN from
`site.yaml`), then:

```bash
cd ../50-edge-cluster
cp secrets.auto.tfvars.example secrets.auto.tfvars && vi secrets.auto.tfvars
terraform init && terraform apply    # ~1 hour
```

Verify BGP sessions in NSX Manager (Networking → Tier-0 → BGP) before
continuing — the Supervisor's ingress/egress depends on them.

## 8. Stage 60 — Supervisor (Broadcom step 10)

```bash
cd ../60-supervisor
cp secrets.auto.tfvars.example secrets.auto.tfvars && vi secrets.auto.tfvars
terraform init && terraform apply    # 30-60 min
```

When it finishes, Workload Management is running:

```bash
kubectl vsphere login --server=<ingress VIP> -u administrator@vsphere.local
kubectl get ns
```

## Alternative: Makefile driver

The Terraform stages can be driven from the repo root (the manual gates in
§1 depot and §3 licensing still happen in the UI):

```bash
make preflight
make apply STAGE=10-management-domain
make apply STAGE=20-network-pools
# ... or walk every Terraform stage in order:
make up
```

## Expanding later

- New workload domain: edit `site.yaml` (pool + hosts + domain), re-apply
  stages 20 → 30 → 40.
- New cluster in an existing domain: extend that domain's `clusters` map,
  re-apply stage 40.
- Second edge cluster or supervisor: extend `edge_clusters` /
  `supervisors`, re-apply stages 50 / 60.
