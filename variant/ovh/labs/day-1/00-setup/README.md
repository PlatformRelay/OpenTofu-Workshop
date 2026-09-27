# OVH twin — Lab 00: setup and first bucket

This is the OVH twin of [`labs/day-1/00-setup.md`](../../../../../labs/day-1/00-setup.md).
It teaches the same first steps — a provider block, a first resource, a first
bucket — against **real OVH Object Storage** instead of LocalStack. The bucket
resource is the same `aws_s3_bucket`; only the provider's values change.

## Before you start

Work through [`../../../setup/ovh-project.md`](../../../setup/ovh-project.md)
first. You need an OVHcloud account with a saved payment method, a first PCI
project, and the S3 access/secret keys from an Object Storage user. Export them:

```bash
export AWS_ACCESS_KEY_ID="<access key>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
export AWS_DEFAULT_REGION="gra"
```

## Files used

- [`versions.tf`](./versions.tf) — required OpenTofu version and providers.
- [`hello.tf`](./hello.tf) — the first resource, a local file (no cloud).
- [`bucket.tf`](./bucket.tf) — the OVH provider block and the opt-in bucket.
- [`stretch.tf`](./stretch.tf) — the optional `random_pet` stretch.

## Step 1 — The local-only first apply

`enable_ovh` defaults to `false`, so your first plan touches nothing cloud-side
— but the provider still resolves its credential chain when it configures, so
Step 1 needs the S3 keys exported too. Any values work here; nothing
cloud-side is touched while `enable_ovh` is false:

```bash
cd "$(git rev-parse --show-toplevel)/variant/ovh/labs/day-1/00-setup"
# Step 1 configures the provider, so pass throwaway keys inline. They apply to
# that one command only, leaving the real keys you exported above in place for
# Step 2:
tofu init
AWS_ACCESS_KEY_ID="test" AWS_SECRET_ACCESS_KEY="test" tofu plan
AWS_ACCESS_KEY_ID="test" AWS_SECRET_ACCESS_KEY="test" tofu apply
```

Read `hello.txt`. This is the same "first resource" beat as the base lab.

## Step 2 — Your first OVH bucket

```bash
TF_VAR_enable_ovh=true tofu plan
TF_VAR_enable_ovh=true tofu apply
```

Notice the bucket name: it is composed by `modules/naming`, not hardcoded.
OVH bucket names are **unique across all OVHcloud customers**, so a fixed name
would collide with another learner's. The random 4-hex suffix keeps yours
unique.

## Step 3 — Verify and destroy

```bash
tofu output                       # (no output defined here — read the apply log)
tofu destroy -auto-approve
```

`tofu destroy` removes whatever is in state, regardless of `enable_ovh`: the
`count = 0` in the config does not protect a bucket that Step 2 already
tracked, so this command deletes the bucket too.

## Next

- [`../../../bootstrap/README.md`](../../../bootstrap/README.md) — the OVH-native
  lab that creates the S3 user and budget alert with the `ovh` provider.
- [`../10-differentiators/README.md`](../10-differentiators/README.md) — the
  provider `for_each` and `import` twin.

## Honest limitation

The unit lane (`task ovh:verify`) proves this config is valid and its naming
contract holds under mock. It does not prove OVH connectivity — that is the
smoke root's job.
