# Bootstrap — the OVH-native lab (~20 min)

This is the variant's answer to a question the base workshop never has to ask:
**who creates the cloud account, the credentials and the spend guardrail?**
LocalStack bootstraps all three for free. On OVH you create them once, and this
lab does it with the `ovh` provider — teaching IAM-scoped service-account auth
along the way.

Run it **after** your first bucket. It is recommended, not required, for the
fast path in [`../setup/ovh-project.md`](../setup/ovh-project.md).

## What it creates

- `ovh_cloud_project_user` — an Object Storage user with the
  `objectstore_operator` role.
- `ovh_cloud_project_user_s3_credential` — the S3 access/secret pair for that
  user (exported sensitive).
- `ovh_cloud_project_alerting` — the budget alert (default €10/month, emailed).

## Prerequisites

- An OVHcloud account with a saved payment method and a first PCI project
  (see [`../setup/ovh-project.md`](../setup/ovh-project.md)).
- An **IAM service account** with OAuth2 client credentials, scoped by a policy
  to your single PCI project. Export:

  ```bash
  export OVH_ENDPOINT=ovh-eu
  export OVH_CLIENT_ID="<client id>"
  export OVH_CLIENT_SECRET="<client secret>"
  export OVH_CLOUD_PROJECT_SERVICE="<project id>"
  export TF_VAR_alert_email="<you@example.com>"
  ```

## Run it

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/bootstrap init
tofu -chdir=variant/ovh/bootstrap plan
tofu -chdir=variant/ovh/bootstrap apply
```

Read the outputs. Export the two S3 values for the twins:

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/bootstrap output -raw s3_access_key_id
tofu -chdir=variant/ovh/bootstrap output -raw s3_secret_access_key
```

The secret is `sensitive`, so it is redacted in normal output — use
`-raw` deliberately, and never paste it into a tracked file.

## Why the alert matters

`ovh_cloud_project_alerting` is declarative, so the alert is state-tracked
alongside the credentials it watches. It is created **here**, in Terraform,
rather than only in the Manager — which means the guardrail travels with the
infrastructure. The Manager step in the setup guide still covers the fast path,
before any `ovh` provider credentials exist.

## State-encryption tie-in (Day-1 S05)

This root's state contains the generated S3 secret. That is exactly the class
of secret Day-1's state-encryption lab (`labs/day-1/05-state-encryption.md`)
teaches you to protect. The shipped root stores it in **plaintext**: it
defines no `encryption {}` block. Encrypting it is this lab's stretch — add a
`state_passphrase` variable and a PBKDF2 `encryption {}` block with a one-time
`unencrypted` fallback to migrate the existing state (the solution file shows
the exact HCL).

## Destroy

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/bootstrap destroy
```

Destroy the twins **before** this root if you want their S3 credentials to stay
valid for their own destroys. `task ovh:teardown` already orders them that way.

## Honest limitations

- The IAM policy's exact resource URN shape for project-scoping is proven by a
  real-OVH run of this bootstrap root plus the `GET /iam/resource` check, not
  assumed here.
- This root does not create the PCI project itself: a fresh account's first
  project is created in the Manager.
