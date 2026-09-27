# OVHcloud setup for the variant track

This guide is the OVH counterpart of [`setup/localstack.md`](../../../setup/localstack.md):
it gets you from "no OVH account" to "a first bucket, created with `tofu`, on
OVH Object Storage". It is Manager-first — the fastest path needs no API
credentials, only the S3 keys you copy out of the Manager.

> **Verify before delivery.** Voucher value, validity and eligibility are
> OVHcloud campaign policy and change over time. Confirm the current terms in
> the Manager before you rely on them; this guide restates mechanics only.

## 1. Account and payment method

1. Create an OVHcloud account (or sign in).
2. Save a **payment method** under *My account → Payment methods*. Both the
   free-trial voucher and switching a project out of *discovery mode* require
   one. A project without a payment method cannot create resources.

## 2. First Public Cloud project

1. In the Manager, open *Public Cloud* and create your **first PCI project**.
   Project creation is free.
2. Pick a region close to you; the variant defaults to `gra` (Gravelines).
3. Activate the **free-trial voucher** if it is offered on your account. It is
   a one-time voucher for the first PCI project only, valid for a limited
   period from activation. Confirm the current value and conditions in the
   Manager.

## 3. Consumption alert (budget backstop)

Do this before your first bucket, in the Manager — it needs no API access:

1. Open your project → *Billing → Current usage* (or *Consumption*).
2. Set a **monthly consumption alert** (the variant suggests €10) with an email
   address you read. You will get a warning when forecast usage crosses it.

The bootstrap lab can also create this alert declaratively with
`ovh_cloud_project_alerting`; the Manager step is what protects the fast path
before any `ovh` provider credentials exist.

## 4. S3 credentials (the fast path)

OVH Object Storage credentials are project-scoped and are created as an
"Object Storage user" (an OpenStack user with the `objectstore_operator` role).

1. In the Manager, open your project → *Object Storage → Object Storage users*.
2. **Create user**, choose the `objectstore_operator` role.
3. Copy the **access key** and **secret key** immediately — the secret is shown
   once.

Export them for `tofu`:

```bash
export AWS_ACCESS_KEY_ID="<access key>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
export AWS_DEFAULT_REGION="gra"
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
```

The two checksum settings are a compatibility precaution, **to be confirmed by
the smoke run**. The `aws` provider pinned here (5.x, built on AWS SDK for Go
v2) adds CRC32 checksums to every upload by default. OVH's Object Storage FAQ
recommends the older SDK behaviour, and OVH's Multi-Object Delete expects a
`Content-MD5` header instead, which can make `force_destroy` on a versioned
bucket fail. `when_required` sends checksums only where the API demands them.

The `aws` provider in the twin roots reads these standard variables when its
own `access_key`/`secret_key` variables are left null. See
[`ovh-env.example`](./ovh-env.example) for the full template.

## 5. The Terraform path (the bootstrap lab)

Once you have a working bucket, the OVH-native lab at
[`../bootstrap/`](../bootstrap/README.md) creates the same S3 user *and* the
budget alert with the `ovh` provider. That root needs an **IAM service
account** with OAuth2 client credentials:

1. In the Manager, open *Identity and Access Management (IAM) → Service
   accounts* and create one.
2. Grant it a policy scoped to **your single PCI project** (resource type
   `publicCloudProject`) and the verbs the bootstrap root needs (project user
   and alerting management).
3. Export the credentials it issues:

```bash
export OVH_ENDPOINT="ovh-eu"
export OVH_CLIENT_ID="<service account client id>"
export OVH_CLIENT_SECRET="<service account client secret>"
export OVH_CLOUD_PROJECT_SERVICE="<your PCI project id>"
```

Then run the bootstrap lab as its README describes.

## 6. Verify

```bash
task ovh:verify                                   # offline unit lane
task ovh:plan  DIR=variant/ovh/labs/day-1/00-setup
task ovh:apply DIR=variant/ovh/labs/day-1/00-setup
task ovh:teardown                                 # destroy what you applied
```

If `plan` fails with `invalid AWS Region: gra`, the provider block lost its
`skip_region_validation = true` flag — OVH region codes are not AWS-shaped and
the `aws` provider rejects them unless that check is skipped.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `invalid AWS Region: gra` | `skip_region_validation = true` is missing from the provider block |
| `InvalidAccessKeyId` / `SignatureDoesNotMatch` | Wrong or stale S3 keys; recreate the Object Storage user in the Manager |
| `BucketAlreadyExists` | OVH bucket names are unique across **all** OVHcloud customers; use a name with a random suffix (`modules/naming` does this) |
| `BucketNotEmpty` on destroy | A versioned bucket keeps delete markers; the capstone twin sets `force_destroy = true` |
| Checksum / `Content-MD5` errors on upload or on destroy of a versioned bucket | Export `AWS_REQUEST_CHECKSUM_CALCULATION=when_required` and `AWS_RESPONSE_CHECKSUM_VALIDATION=when_required` (section 4) |
| Project stuck in *discovery mode* | No payment method saved on the account |

## Where to go next

- [`../README.md`](../README.md) — the variant entry and scope table.
- [`../bootstrap/README.md`](../bootstrap/README.md) — the OVH-native lab.
- [`../smoke/README.md`](../smoke/README.md) — the real-OVH smoke root.
