# Documentation

Documentation for the VCF 9.1 Greenfield Deployment Framework, split by intent:

| Area | Directory | Use it to… |
|------|-----------|-----------|
| **Design** | [design/](design/) | Decide the architecture — Broadcom-aligned VCF 9.1 design guidance (Architectural Options, Blueprints, Design Library) mapped to this framework |
| **Deployment** | [deployment/](deployment/) | Build the fleet — prerequisites, framework architecture, and both the automated (Terraform) and manual (UI) deployment guides |
| **Operations** | [operations/](operations/) | Run it day-2 — expansion, drift, rotation, upgrades, and troubleshooting |

The Infrastructure-as-Code itself lives under [`../iac/`](../iac/).

## Design ([design/](design/))

Start at [design/README.md](design/README.md). Covers methodology, architecture
models & blueprints, network, NSX/edge, storage, compute/availability,
Supervisor, security/identity, lifecycle/operations, sizing, and a design
decisions register.

## Deployment ([deployment/](deployment/))

| Doc | Contents |
|-----|----------|
| [prerequisites.md](deployment/prerequisites.md) | Hardware, DNS/NTP, fabric and host-prep checklist |
| [architecture.md](deployment/architecture.md) | Framework pipeline, isolated state, network reference model |
| [deployment-runbook.md](deployment/deployment-runbook.md) | End-to-end **automated** deployment (Terraform), stage by stage |
| [manual-deployment-guide.md](deployment/manual-deployment-guide.md) | End-to-end **manual (UI-driven)** deployment, mirroring the stages |

Site definition schema: [../iac/config/README.md](../iac/config/README.md).

## Operations ([operations/](operations/))

| Doc | Contents |
|-----|----------|
| [day2-operations.md](operations/day2-operations.md) | Expansion, drift, rotation, upgrades |
| [troubleshooting.md](operations/troubleshooting.md) | Failure catalog organized by stage |
