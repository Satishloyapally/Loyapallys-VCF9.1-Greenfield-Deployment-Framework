terraform {
  required_version = ">= 1.7"

  required_providers {
    vcf = {
      source  = "vmware/vcf"
      version = "~> 0.18"
    }
  }
}

provider "vcf" {
  sddc_manager_host     = local.site.management_domain.sddc_manager.hostname
  sddc_manager_username = var.sddc_manager_username
  sddc_manager_password = var.sddc_manager_password
  allow_unverified_tls  = var.allow_unverified_tls
}
