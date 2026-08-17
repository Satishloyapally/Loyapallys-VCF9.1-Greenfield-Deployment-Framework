# Stage 00 — VCF Installer Appliance

In a true greenfield there is no vCenter yet, so this stage is deliberately
**not** Terraform: the VCF 9.1 Installer OVA is pushed straight to one of the
freshly-installed seed ESXi hosts with `ovftool`, driven by the same
`iac/config/site.yaml` used by every other stage.

## Prerequisites

- The four seed ESXi hosts are installed, reachable by FQDN, and have NTP
  configured (run `iac/scripts/preflight.sh` first).
- [OVF Tool](https://developer.broadcom.com/tools/open-virtualization-format-ovf-tool/latest)
  is installed locally.
- The VCF Installer OVA is downloaded from the Broadcom Support Portal.
- Forward and reverse DNS records exist for the installer FQDN
  (`installer.hostname` + `site.dns_domain` in `site.yaml`).

## Run

```bash
export ESXI_PASSWORD='<root password of the target host>'
export INSTALLER_ADMIN_PASSWORD='<password for admin@local>'
export INSTALLER_ROOT_PASSWORD='<root password for the appliance>'

./iac/scripts/deploy-installer.sh /path/to/VCF-SDDC-Manager-Appliance-9.1.0.0.ova
```

The script reads `installer.*` from `iac/config/site.yaml`, deploys the OVA to
`installer.target_host`, powers it on and waits until the UI answers on
`https://<installer-fqdn>`.

## Verify

Open `https://<installer-fqdn>` and log in as `admin@local`. Once the UI
loads, download/stage the VCF 9.1 binary bundle in the installer (online depot
or offline bundle transfer), then continue with stage 10.
