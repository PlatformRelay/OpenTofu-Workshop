terraform {
  required_version = ">= 1.9"

  required_providers {
    ovh = {
      source = "ovh/ovh"
      # Restates OVH_PROVIDER_VERSION from versions.env; drift-checked by
      # variant/ovh/scripts/verify.sh.
      version = "~> 2.21.0"
    }
  }
}

# OAuth2 service account (client_id/client_secret), scoped by an IAM policy to
# the single PCI project. Values come from the environment
# (OVH_ENDPOINT / OVH_CLIENT_ID / OVH_CLIENT_SECRET); never commit them.
provider "ovh" {
  endpoint      = var.ovh_endpoint
  client_id     = var.ovh_client_id
  client_secret = var.ovh_client_secret
}
