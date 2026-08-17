# 07 — Security & Identity Design

Security is a first-class part of the VCF 9.1 design library (Information
Security, Single Sign-On, Identity Broker, and vDefend detailed designs).
This document summarizes the greenfield-relevant decisions.

## Single Sign-On (SSO) model (Choice)

Each workload domain either **joins the management SSO domain** or uses an
**isolated SSO domain**:

| Model | When |
|-------|------|
| **Shared / management SSO** | Default; simplest operations; single identity boundary |
| **Isolated SSO** per workload domain | Regulatory/tenant isolation, independent identity lifecycle |

In this framework, `workload_domains.*.sso` chooses: omit it to join the
management SSO, or set `domain_name` for an isolated SSO domain. VCF 9.1 also
provides an **Identity Broker** and identity federation to external providers
(e.g. AD/LDAP, OIDC) for VCF Operations/Automation — plan your identity source
before onboarding tenants.

## Certificates

- VCF appliances start with **VMCA-signed / self-signed** certificates;
  `allow_unverified_tls` in this framework accepts them for lab/bring-up.
- For production, replace with **CA-signed certificates** managed through SDDC
  Manager / VCF Operations. Choose ESXi certificate mode (**VMCA** or
  **Custom**) deliberately — the `vcf_instance` bring-up exposes an
  `esxi_certs_mode`.
- Track certificate expiry and rotation as a day-2 operation (doc 08).

## Password policy

VCF 9.1 enforces strong passwords for appliances and hosts. Practical rules:

- 15+ characters; upper/lower/digit; only the special characters VCF permits
  (e.g. `! @ # $ % ^ & *`); avoid characters VCF rejects and avoid dictionary
  words/palindromes for NSX.
- Never store passwords in `iac/config/site.yaml`. This framework keeps them in
  git-ignored `secrets.auto.tfvars` or `TF_VAR_*` environment variables, typed
  as `sensitive` variables.

## FIPS mode

- **FIPS-validated mode is chosen at bring-up and cannot be changed
  afterward** — decide before deploying stage 10. This framework exposes
  `fips_enabled` (default `false`).

## Lateral security (vDefend)

For east-west protection, the **vDefend** design (distributed firewall + IDS/
IPS, and optionally Advanced Threat Prevention) is a separate blueprint layer.
Design segmentation (zones, groups, policies) alongside the network
consumption model (doc 02/03). It is not deployed by this framework's core
stages but the network design here is compatible with it.

## Isolation & least privilege

- Separate management and workload domains for blast-radius isolation
  (standard architecture).
- Supervisor CP VMs are a **management-plane only** deployment isolated from
  workloads; use vSphere Zones/Namespaces for tenant isolation.
- Scope service accounts (SDDC Manager API, vCenter SSO) to least privilege;
  rotate the break-glass `admin@local` local account credentials.

## Sources

- [Design Library — Information Security / SSO / Identity Broker](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library.html)
- [VCF 9.1 Design](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design.html)
