# Infrastructure-as-Code

All Terraform for the VCF 9.1 Greenfield Deployment Framework lives here. It is
driven from the **repository-root `Makefile`** and reads a single site
definition, [`config/site.yaml`](config/README.md).

```text
iac/
├── config/     site.example.yaml — the single source of truth (copy to site.yaml)
├── modules/    reusable building blocks:
│   ├── management-domain/   vcf_instance bring-up (+ optional fleet components)
│   ├── network-pool/        SDDC Manager address pools
│   ├── host-commission/     free-host inventory
│   ├── workload-domain/     vcf_domain with multi-cluster support
│   ├── edge-cluster/        NSX edges, Tier-0, eBGP
│   └── supervisor/          Workload Management + K8s content library
├── stages/     one root module per lifecycle phase, each with its own state:
│   ├── 00-installer/        (script + README; not Terraform)
│   ├── 10-management-domain/  20-network-pools/  30-host-commission/
│   └── 40-workload-domain/    50-edge-cluster/   60-supervisor/
└── scripts/    preflight.sh, deploy-installer.sh, thumbprints.sh
```

## Running it

From the **repository root**:

```bash
cp iac/config/site.example.yaml iac/config/site.yaml   # then edit
make preflight
make validate                       # terraform validate every stage
make apply STAGE=10-management-domain
```

Or drive a single stage directly with Terraform:

```bash
terraform -chdir=iac/stages/10-management-domain init
terraform -chdir=iac/stages/10-management-domain apply
```

Each stage has a `secrets.auto.tfvars.example` — copy it to
`secrets.auto.tfvars` (git-ignored) and fill in passwords, or export
`TF_VAR_*` environment variables. Never put secrets in `site.yaml`.

## Conventions

- **Provider versions** are pinned to their VCF 9.1 releases and locked in each
  stage's committed `.terraform.lock.hcl` (`vmware/vcf` >= 0.18,
  `vmware/vsphere` >= 2.16, `vmware/nsxt` >= 3.12).
- **Cross-stage data** flows via `terraform_remote_state` (for example host
  UUIDs from `30-host-commission` into `40-workload-domain`) — never copied by
  hand.
- **Design rationale** for every choice is in [`../docs/design/`](../docs/design/);
  step-by-step deployment is in [`../docs/deployment/`](../docs/deployment/).
