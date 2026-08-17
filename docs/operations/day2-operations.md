# Day-2 Operations

The site definition remains the source of truth after deployment. Day-2
changes follow the same loop as day-0: edit `site.yaml`, plan, apply.

## Routine changes

| Change | Edit in `site.yaml` | Re-apply |
|--------|---------------------|----------|
| Add workload capacity (hosts) | `commission_hosts` | stage 30 |
| Add a cluster to a domain | `workload_domains.<d>.clusters` | stage 40 |
| Add a workload domain | `network_pools`, `commission_hosts`, `workload_domains` | 20 → 30 → 40 |
| Scale an edge cluster | `edge_clusters.<e>.nodes` | stage 50 |
| Add a supervisor namespace | `supervisors.<s>.namespaces` | stage 60 |

Always run `terraform plan` first and read it — the plan is the change
review.

## State hygiene

- Each stage keeps local state by default. For team use, move state to a
  remote backend (S3/GCS/Consul/Terraform Cloud) by adding a `backend`
  block per stage; the stage isolation model is unchanged.
- Never share one backend key across stages — one state per stage is the
  contract that keeps blast radius small.
- Back up `iac/stages/30-host-commission/terraform.tfstate` with particular
  care: stage 40 resolves host UUIDs through it.

## Drift

VCF objects are also manageable from the SDDC Manager UI, which means
drift is possible. Detect it:

```bash
terraform -chdir=iac/stages/40-workload-domain plan -detailed-exitcode
```

Policy recommendation: **UI for read-only, Terraform for changes** on
everything this repo manages.

## Credential rotation

Passwords are provider inputs, not resources: rotate them in the platform
(SDDC Manager password management handles most appliance accounts), then
update the matching `secrets.auto.tfvars` so future applies authenticate.

## Upgrades

VCF upgrades (new BOM versions) are lifecycle operations driven by SDDC
Manager / VCF Operations, not by this repo. After an upgrade completes,
update `vcf.version` in `site.yaml` so the definition matches reality and
future plans stay clean.

## Certificate replacement

Replace self-signed certs via SDDC Manager's certificate management. Once
CA-signed certs are in place, set `allow_unverified_tls = false` in each
stage's tfvars for strict verification.

## Backups

Configure SDDC Manager and NSX backups (SFTP target) immediately after
stage 10 — before workload domains carry production traffic. This is a
platform setting, deliberately outside Terraform's blast radius.
