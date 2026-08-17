terraform {
  required_version = ">= 1.7"

  required_providers {
    vcf = {
      source  = "vmware/vcf"
      version = "~> 0.18"
    }
  }
}

# Stage 10 talks to the VCF Installer appliance deployed in stage 00.
provider "vcf" {
  installer_host       = "${local.site.installer.hostname}.${local.site.site.dns_domain}"
  installer_username   = "admin@local"
  installer_password   = var.installer_admin_password
  allow_unverified_tls = var.allow_unverified_tls
}
