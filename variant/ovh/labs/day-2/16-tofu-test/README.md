# OVH twin — Lab 16: native testing with `tofu test`

<!-- variant-solution: base -->

This is the OVH twin of
[`labs/day-2/16-tofu-test.md`](../../../../../labs/day-2/16-tofu-test.md). The
lesson is unchanged: `tofu test` runs the naming module's plan suite, then an
apply test creates and verifies a module-named bucket. Here the apply targets
real OVH Object Storage.

## What changes from the base lab

- The provider points at OVH (`skip_region_validation`, OVH endpoint).
- The bucket name is composed by `modules/naming` with a random suffix — OVH
  bucket names are globally unique.
- The apply suite is [`tests/integration.tftest.hcl`](./tests/integration.tftest.hcl);
  [`tests/unit.tftest.hcl`](./tests/unit.tftest.hcl) is the mock/plan lane.

## Run the unit lane

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=modules/naming init -no-color && tofu -chdir=modules/naming test -no-color
tofu -chdir=variant/ovh/labs/day-2/16-tofu-test init
tofu -chdir=variant/ovh/labs/day-2/16-tofu-test test -filter=tests/unit.tftest.hcl
```

## Run the integration lane (real OVH)

```bash
export AWS_ACCESS_KEY_ID="<access key>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
export AWS_DEFAULT_REGION="gra"
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/labs/day-2/16-tofu-test init
tofu -chdir=variant/ovh/labs/day-2/16-tofu-test test -filter=tests/integration.tftest.hcl
```

The apply test destroys what it creates. The base lab's break→fix beat (edit the
expected project so the assertion fails) works identically here.

## Destroy

The integration test destroys its own bucket. If a run is interrupted:

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/labs/day-2/16-tofu-test destroy -auto-approve
```
