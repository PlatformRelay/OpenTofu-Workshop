# OVH twin — capstone: settled colony on OVH Object Storage

This is the OVH twin of [`examples/capstone/`](../../../../examples/capstone/)
used by the Day-3 capstone
([`labs/day-3/26-capstone.md`](../../../../labs/day-3/26-capstone.md)). It
composes `modules/naming` + `modules/labels` into a small estate on real OVH
Object Storage.

## What changes from the base capstone

The base capstone's three resources — S3 bucket, DynamoDB table, SQS queue —
become **one versioned bucket plus a lifecycle rule** (the table/queue
replacement) and a **second named+tagged bucket** for the Part B analogue.
DynamoDB and SQS teaching is rewritten onto OVH primitives, not dropped:

| Base primitive | OVH twin |
| --- | --- |
| S3 artifact bucket | `aws_s3_bucket.artifacts` (named + tagged) |
| DynamoDB metadata index | `aws_s3_bucket_versioning` + `aws_s3_bucket_lifecycle_configuration` on the same bucket |
| SQS work queue | `aws_s3_bucket.archive` (the Part B second bucket) |

The bucket names are composed by `modules/naming` with a random suffix (OVH
bucket names are globally unique). The artifacts bucket sets
`force_destroy = true` because a versioned bucket keeps noncurrent versions and
delete markers, which would otherwise fail `tofu destroy` with
`BucketNotEmpty`.

## Run it

```bash
export AWS_ACCESS_KEY_ID="<access key>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
export AWS_DEFAULT_REGION="gra"
export TF_VAR_state_passphrase="<your passphrase, 16+ chars>"   # required, no default

cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/examples/capstone-ovh init
tofu -chdir=variant/ovh/examples/capstone-ovh plan
tofu -chdir=variant/ovh/examples/capstone-ovh apply
tofu -chdir=variant/ovh/examples/capstone-ovh output
```

## Unit lane

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/examples/capstone-ovh test -filter=tests/unit.tftest.hcl
```

## Destroy

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/examples/capstone-ovh destroy -auto-approve
```

`force_destroy` sweeps the versioned objects first, so this succeeds.

## Honest limitations

- The base capstone's `examples/capstone-build/` SNS analogue is not
  reproduced; the Part B analogue here is a second bucket.
- `aws_s3_bucket_policy` and SSE-KMS are not available on OVH standard regions.
