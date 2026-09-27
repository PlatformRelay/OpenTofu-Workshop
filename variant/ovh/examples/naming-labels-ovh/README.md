# OVH twin — naming & labels example (Lab 08 Step 4)

This is the OVH twin of
[`examples/naming-labels-demo/`](../../../../examples/naming-labels-demo/) used
by Lab 08 Step 4. The lesson is identical: `modules/naming` composes the bucket
name, `modules/labels` emits the taxonomy tags, and the same PBKDF2 state
encryption is wired in.

## What changes from the base example

- The provider points at OVH (`skip_region_validation`, OVH endpoint).
- The DynamoDB table is dropped: the composition lesson needs one named+tagged
  resource, and the variant's universe is S3-only.
- The bucket name is composed with a random suffix (OVH bucket names are
  globally unique).

## Run it

```bash
export AWS_ACCESS_KEY_ID="<access key>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
export AWS_DEFAULT_REGION="gra"
export TF_VAR_state_passphrase="<your passphrase, 16+ chars>"   # required, no default

cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/examples/naming-labels-ovh init
tofu -chdir=variant/ovh/examples/naming-labels-ovh plan
tofu -chdir=variant/ovh/examples/naming-labels-ovh apply
```

Read the outputs: `bucket_name` and the full `labels` map. Every required
taxonomy key should be present as a real bucket tag.

## Unit lane

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/examples/naming-labels-ovh test -filter=tests/unit.tftest.hcl
```

## Destroy

```bash
cd "$(git rev-parse --show-toplevel)"
tofu -chdir=variant/ovh/examples/naming-labels-ovh destroy -auto-approve
```

## Honest limitation

`aws_s3_bucket_policy` is **not available** on OVH standard regions, so this
example tags the bucket but does not attach a bucket policy. Least-privilege
bucket access via the OVH-native `ovh_cloud_project_user_s3_policy` is a
documented stretch/follow-up that is **not shipped** in v1.
