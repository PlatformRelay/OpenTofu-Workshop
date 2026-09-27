# OVH twin — Lab 10: provider `for_each`, `-exclude` & `import`

<!-- variant-solution: base -->

This is the OVH twin of
[`labs/day-1/10-differentiators.md`](../../../../../labs/day-1/10-differentiators.md).
The OpenTofu-first lessons are identical; the regions and endpoints are OVH's.
The base lab's solution applies unchanged to Part A's commands.

## What changes from the base lab

- **Regions** are `gra` (Gravelines) and `sbg` (Strasbourg) instead of
  `us-east-1` / `eu-west-1`.
- **Endpoints** point at `https://s3.<region>.io.cloud.ovh.net`.
- **Bucket names** are composed by `modules/naming` (random suffix) because OVH
  bucket names are unique across all customers.
- **Part B** adopts a bucket you create **in the OVH Manager**, not with
  `awslocal`.

## Part A — provider `for_each` and `-exclude`

```bash
cd "$(git rev-parse --show-toplevel)/variant/ovh/labs/day-1/10-differentiators"
tofu init
tofu plan
tofu apply
```

One provider block, two regional instances, two buckets, two marker objects.
Now repeat the base lab's `-exclude` beats — drop a leaf, then drop a
dependency and watch its dependents go with it.

## Part B — adopt existing infrastructure with `import`

1. In the OVH Manager, create a bucket (Object Storage → Create bucket). Give
   it a name unique to you, and add the tag `owner = ops` (bucket → Tags) so
   the importing plan is exactly "1 to import" — the config expects that tag,
   and without it you get "1 to import, 1 to update in-place" instead.
2. Export its name and your credentials — you must set this, the root has no
   default bucket name:

   ```bash
   export TF_VAR_adopted_bucket_name="<your bucket name>"
   ```

3. From the `import/` directory:

   ```bash
   cd "$(git rev-parse --show-toplevel)/variant/ovh/labs/day-1/10-differentiators/import"
   tofu init
   tofu plan     # expect: 1 to import
   tofu apply    # expect: 1 imported
   tofu plan     # expect: no changes
   ```

The same wrong-`id` and config-mismatch break→fix beats as the base lab apply.

## Cleanup

Part B's bucket is **yours**: you created it in the Manager, and the import only
made OpenTofu track it. So Part B ends the way it began — out-of-band. Release
the bucket from state (the Lab 04 verb that forgets without destroying), then
destroy Part A:

```bash
cd "$(git rev-parse --show-toplevel)/variant/ovh/labs/day-1/10-differentiators/import"
tofu state rm aws_s3_bucket.adopted
cd "$(git rev-parse --show-toplevel)/variant/ovh/labs/day-1/10-differentiators"
tofu destroy -auto-approve
```

Then delete the adopted bucket in the OVH Manager if it was a throwaway you
made for this exercise. (A declarative alternative to `state rm` is a
`removed { from = aws_s3_bucket.adopted }` block with
`lifecycle { destroy = false }`, applied once.)

This differs from the base lab on purpose: there the adopted bucket lives in
LocalStack, so `tofu destroy` deleting it costs nothing. Here `tofu destroy` in
`import/` would delete a real bucket that may not be a throwaway, which is why
`task ovh:teardown` also skips `import/` roots unless you pass
`--include-imported`.
