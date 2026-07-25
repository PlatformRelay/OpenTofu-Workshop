generate_hcl "_providers.tf" {
  content {
    terraform {
      required_version = global.terraform_version

      required_providers {
        local = {
          source  = "hashicorp/local"
          version = global.local_provider_version
        }
      }
    }

    provider "local" {}
  }
}
