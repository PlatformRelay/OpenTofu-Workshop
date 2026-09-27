# Snippet — Lab 04's S3-backend stretch on OVH

[`backend-s3.tf.off`](./backend-s3.tf.off) is the OVH-track version of the S3
backend stretch in
[`labs/day-1/04-state.md`](../../../../labs/day-1/04-state.md). The base stretch
points the backend at LocalStack; this one points it at OVH Object Storage with
OpenTofu's native S3 locking.

## Use it

1. Create a state bucket in the OVH Manager (unique to you) and export your S3
   credentials:

   ```bash
   export AWS_ACCESS_KEY_ID="<access key>"
   export AWS_SECRET_ACCESS_KEY="<secret key>"
   export AWS_DEFAULT_REGION="gra"
   # Checksum compatibility, to be confirmed by the smoke run — see
   # ../../setup/ovh-project.md section 4:
   export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
   export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
   ```

2. Work in a copy of the lab so the base tree is untouched:

   ```bash
   REPO="$(git rev-parse --show-toplevel)"
   cp -r "$REPO/labs/day-1/04-state" /tmp/ovh-state-lab
   cd /tmp/ovh-state-lab
   mv backend.tf backend.tf.off
   cp "$REPO/variant/ovh/snippets/s3-backend/backend-s3.tf.off" backend-s3.tf
   # edit the bucket name in backend-s3.tf
   tofu init -migrate-state
   ```

## What it keeps and what it changes

- **Keeps** the lesson: OpenTofu-native S3 locking (`use_lockfile`, >= 1.10) —
  no DynamoDB table.
- **Changes** the endpoint to `https://s3.<region>.io.cloud.ovh.net` (not the
  legacy `perf.cloud.ovh.net` some older guides cite) and adds the OVH guide's
  skip flags (`skip_s3_checksum`, `skip_region_validation`, …).

## Honest limitation

The lockfile flow against OVH is **unproven** in v1. OVH documents conditional
writes (which the lockfile needs), but the smoke root uses local state and does
not exercise the S3 backend either, so this remains unverified until someone
runs this snippet against a real OVH state bucket.
