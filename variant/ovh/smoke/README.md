# Smoke root — prove the aws-vs-OVH-S3 surface (maintainer, ~5 min)

The variant's biggest unproven assumption is that the `aws` provider's request
shapes for **versioning, lifecycle, tagging and versioned-bucket destroy** are
accepted by OVH Object Storage. OVH documents the API actions as supported; that
is not the same as proving the provider's requests work end to end.

This root is the cheapest decisive proof. It applies **the exact shapes the
twins use** — one bucket with versioning, a lifecycle rule and a tagged object —
against real OVH, then destroys the versioned bucket. Run it **once** before the
Day-1/2 twins are trusted, and again whenever the provider pin moves.

## What it proves

- `aws_s3_bucket` + `modules/naming` produce a valid, unique OVH bucket name.
- `aws_s3_bucket_versioning` and `aws_s3_bucket_lifecycle_configuration` are
  accepted.
- `aws_s3_object` with tags works.
- Destroying a **versioned** bucket succeeds with `force_destroy = true`.
- The `skip_region_validation = true` provider flag makes `region = "gra"` pass
  provider configuration (without it, plan fails `invalid AWS Region: gra`).

Backend locking (`use_lockfile`) is **not covered** by this root: it uses local
state, so S3-backend locking remains unverified.

## Run it

You need S3 credentials from [`../setup/ovh-project.md`](../setup/ovh-project.md)
(the Manager fast path is enough):

```bash
export AWS_ACCESS_KEY_ID="<access key>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
export AWS_DEFAULT_REGION="gra"

cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/smoke init
tofu -chdir=variant/ovh/smoke apply -auto-approve
tofu -chdir=variant/ovh/smoke output
tofu -chdir=variant/ovh/smoke destroy -auto-approve
```

## Expected result

`apply` reports 5 resources added (the `random_id.suffix` from
`modules/naming` plus the bucket, versioning, lifecycle and object);
`output.bucket_name` matches `s3-smoke-d-versioned-<4 hex>`; `destroy` reports
5 destroyed with no `BucketNotEmpty`. If versioning or lifecycle is rejected, the error names the
failing API call — that is the signal the twins must not be built on that shape
yet.

The run also settles the S3 checksum question: do it once **with** the
`AWS_REQUEST_CHECKSUM_CALCULATION` / `AWS_RESPONSE_CHECKSUM_VALIDATION=
when_required` exports from the setup guide, and, if you want to know whether
they are needed, once without them. Record which way `destroy` of the
versioned bucket behaves.

## Record the result

This is a manual maintainer step in v1 (an automated real-OVH lane is not
wired: it needs a funded project and CI secrets). Record the outcome in the variant README's limitations section
when it changes: a passing run is what promotes the aws-vs-OVH-S3 surface from
"unverified" to "proven".
