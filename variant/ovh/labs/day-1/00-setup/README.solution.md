# OVH twin — Lab 00: solution

## Guided solutions

```bash
cd "$(git rev-parse --show-toplevel)/variant/ovh/labs/day-1/00-setup"
tofu init
tofu apply                              # local file only (enable_ovh defaults false)
TF_VAR_enable_ovh=true tofu apply       # adds the uniquely-named OVH bucket
```

## Expected state / output

- The first apply adds `local_file.hello` and writes `hello.txt`.
- The second apply adds `aws_s3_bucket.first[0]` with a name matching
  `s3-first-d-hello-<4 hex>`, and `tofu state list` shows the bucket address.
- `tofu output` prints nothing: this twin defines no outputs.

## Explanation

`enable_ovh` gates the bucket with `count`, exactly as the base lab gates its
LocalStack bucket. The bucket name comes from `modules/naming`, which appends a
random 4-hex suffix — OVH bucket names are unique across all customers, so a
hardcoded name would collide. The provider block pairs `skip_region_validation`
with the S3-compatible endpoint because OVH region codes (`gra`, `sbg`) are not
AWS-shaped; without that flag the provider rejects the region at configure time.

## Troubleshooting and recovery

| Symptom | Fix |
| --- | --- |
| `invalid AWS Region: gra` | `skip_region_validation = true` is missing from `bucket.tf` |
| `BucketAlreadyExists` | Another learner used the name; set `bucket_suffix` to a different value, or force a new suffix with `TF_VAR_enable_ovh=true tofu apply -replace='module.bucket_name[0].random_id.suffix[0]'` |
| `InvalidAccessKeyId` | Re-export the S3 keys from the Manager |

```bash
TF_VAR_enable_ovh=true tofu destroy -auto-approve
rm -f hello.txt
```

## Stretch solution

### Commands / manifest

```bash
TF_VAR_enable_ovh=true TF_VAR_enable_random_pet=true tofu apply
```

### Expected state / output

`random_pet.stretch[0]` is added to state alongside the bucket.

### Explanation

The stretch resource is unchanged from the base lab — it demonstrates that a
provider-agnostic resource needs no OVH-specific edit at all.
