# Bootstrap — solution

## Guided solutions

Prerequisites: an OVHcloud account with a saved payment method, a first PCI
project, and an IAM service account with OAuth2 client credentials scoped to
that project. Export them (see [`../setup/ovh-project.md`](../setup/ovh-project.md)):

```bash
export OVH_ENDPOINT=ovh-eu
export OVH_CLIENT_ID="<client id>"
export OVH_CLIENT_SECRET="<client secret>"
export OVH_CLOUD_PROJECT_SERVICE="<project id>"
export TF_VAR_alert_email="you@example.com"
```

Then apply:

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/bootstrap init
tofu -chdir=variant/ovh/bootstrap plan
tofu -chdir=variant/ovh/bootstrap apply
```

## Expected state / output

- `plan` reports **3 to add**: `ovh_cloud_project_user.s3`,
  `ovh_cloud_project_user_s3_credential.s3`, `ovh_cloud_project_alerting.budget`.
- `apply` reports **3 added**. The outputs are `s3_access_key_id`,
  `s3_secret_access_key` (both sensitive), `project_user_username`, `alert_id`.
- `tofu output -raw s3_access_key_id` prints the access key; the secret is
  redacted in normal output and needs `-raw` deliberately.

## Explanation

The `ovh` provider authenticates with the OAuth2 service account
(`client_id`/`client_secret`), which the IAM policy scopes to your single PCI
project. `ovh_cloud_project_user` creates an OpenStack user with the
`objectstore_operator` role; `ovh_cloud_project_user_s3_credential` mints its
S3 key pair; `ovh_cloud_project_alerting` creates the budget backstop
declaratively. This is the OVH-native replacement for what LocalStack
bootstraps for free.

## Troubleshooting and recovery

| Symptom | Cause and fix |
| --- | --- |
| `missing authentication information` | The OAuth2 env vars are not exported; re-export them and retry |
| `No value for required variable` for `alert_email` | Set `TF_VAR_alert_email` to an address you read |
| HTTP 403 from the OVH API | The IAM policy does not grant the project-user/alerting verbs, or is scoped to the wrong project URN |
| Endpoint hits `ovh-eu` unexpectedly | `TF_VAR_ovh_endpoint` is set; unset it so `OVH_ENDPOINT` applies |

Destroy the root when you are done (twins first if you want their S3
credentials to stay valid for their own destroys):

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/bootstrap destroy -auto-approve
```

## Stretch solution

### Commands / manifest

The shipped root has **no** `state_passphrase` variable and **no**
`encryption {}` block, so exporting `TF_VAR_state_passphrase` alone changes
nothing: the state stays plaintext. The stretch is to add both. Create
`variant/ovh/bootstrap/encryption.tf`. It holds no secret, only the wiring;
the passphrase comes from the environment:

```hcl
variable "state_passphrase" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must be at least 16 characters (PBKDF2 requirement)."
  }
}

terraform {
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "encrypted" {
      keys = key_provider.pbkdf2.passphrase
    }

    # One-time migration: lets OpenTofu read the existing PLAINTEXT state.
    method "unencrypted" "migrate" {}

    state {
      method = method.aes_gcm.encrypted

      fallback {
        method = method.unencrypted.migrate
      }
    }
  }
}
```

Then apply once with a passphrase of your own (16+ characters):

```bash
export TF_VAR_state_passphrase="<your passphrase, 16+ chars>"
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/bootstrap apply
```

After that apply, delete the `method "unencrypted" "migrate"` block and the
`fallback` block, so a plaintext state can never be read again silently.

### Expected state / output

`apply` reports no resource changes, but rewrites the state:
`variant/ovh/bootstrap/terraform.tfstate` now starts with `"serial"` /
`"meta"` / `"encrypted_data"` instead of readable resources, and the S3 secret
no longer appears in it. `tofu plan` still reads it with the passphrase
exported; without it, `plan` fails on the missing variable.

### Explanation

This root generates a durable secret, so it is exactly the case S05's
state-encryption lesson protects. The OVH-native per-bucket least-privilege
answer (`ovh_cloud_project_user_s3_policy`) is a documented v1 stretch and is
not shipped here.
