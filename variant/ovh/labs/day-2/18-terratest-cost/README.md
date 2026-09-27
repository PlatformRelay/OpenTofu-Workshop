# OVH twin — Lab 18: Terratest against OVH Object Storage

<!-- variant-solution: base -->

This is the OVH twin of
[`labs/day-2/18-terratest-cost.md`](../../../../../labs/day-2/18-terratest-cost.md).
The lesson is unchanged: a Terratest suite applies a config, asserts the result
and destroys it. Here it runs against **real OVH Object Storage**, with the S3
credentials read from the environment instead of LocalStack's `test`/`test`.

## What changes from the base lab

- The Go test reads `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` /
  `AWS_DEFAULT_REGION` from the environment (see
  [`bucket_test.go`](./bucket_test.go)).
- The bucket name is composed by `modules/naming` and asserted as a **pattern**
  (`^s3-crmapp-d-web-[a-f0-9]{4}$`), not the base lab's fixed name — OVH bucket
  names are globally unique.
- There is no `aws_endpoint` variable: the endpoint is derived from the region.

## Run it

```bash
export AWS_ACCESS_KEY_ID="<access key>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
export AWS_DEFAULT_REGION="gra"

cd "$(git rev-parse --show-toplevel)/variant/ovh/labs/day-2/18-terratest-cost"
go test ./...        # needs host Go; or use the pinned Terratest container lane
```

The test destroys what it creates. The base lab's break→fix beat (break the
assertion, watch it fail, restore) works identically.

## The optional Infracost stretch

The base lab's `cost/main.tf` fixture is HCL-inferred and never applied, so it is
not reproduced here — the stretch is provider-agnostic and the base file applies
unchanged if you want it.

## Destroy

The test destroys its own bucket. If a run is interrupted:

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/labs/day-2/18-terratest-cost destroy -auto-approve
```
