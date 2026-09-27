# OVHcloud Public Cloud (PCI) variant

The OVH variant lets a learner run the **cloud-shaped moments** of the workshop
on **OVHcloud Public Cloud free credits** — no AWS account, no Docker, no
LocalStack. OVH Object Storage speaks the S3 API, so the base resource layer
(`aws_s3_bucket`, `aws_s3_object`) survives the provider swap; the same
`modules/naming` and `modules/labels` compose the names and tags.

This is a **variant track**, not a fork. The base labs' `.tf` files and
solutions are untouched; eleven base lab pages gain only a short, additive
"OVH track" pointer box (listed as **box** below). This tree lives outside the
base discovery globs (`labs/`, `modules/`, `examples/`), and the base workshop
stays cloud-neutral.

## Who this is for

- You have an OVHcloud account (or can create one) and a **saved payment
  method** — both are required before the free trial voucher activates.
- You have **no** AWS account and prefer not to run Docker/LocalStack.
- You want the Day-1/2/3 cloud beats (provider wiring, naming/labels, `tofu
  test`, Terratest, the capstone composition) on real Object Storage.

If you are happy with LocalStack, stay on the base track; the variant teaches
the same OpenTofu, not OVH parity.

## Before you start

1. Read the setup guide: [`setup/ovh-project.md`](./setup/ovh-project.md). It
   walks account → payment method → first PCI project → voucher activation →
   consumption alert → S3 credentials.
2. Copy the environment template, fill it in, and load it so every name is
   **exported** (a plain `source` sets shell variables `tofu` never sees):
   `cp variant/ovh/setup/ovh-env.example .env.ovh`, then
   `set -a; . ./.env.ovh; set +a`. **Never commit real credentials** — the
   repo's dummy-cred pattern applies unchanged.
3. Verify the toolchain: `task preflight`, then `task ovh:verify`.

> **Verify before delivery.** The free-trial voucher's value, validity and
> eligibility are OVHcloud campaign policy, not workshop fact. This track
> restates **mechanics**, never amounts, and the setup guide tells you to
> confirm the current terms in the OVHcloud Manager before you rely on them.

## Cost envelope

The variant's resource universe is **Object Storage only** — no instances, no
MKS, no registry. Workshop buckets hold KB–MB, so the whole arc costs
**pennies**, independent of the voucher's exact value. The setup guide sets a
consumption alert as the backstop; the bootstrap lab can also create it
declaratively.

## Scope

Legend: **unchanged** = the base lab runs as-is on this track (its page is not
edited); **box** = the base lab page carries an additive OVH pointer box and
nothing else changes; **twin** = a variant root under this tree.

| Base lab | Disposition | Variant artefact |
| --- | --- | --- |
| 00-setup | box + twin | [`labs/day-1/00-setup/`](./labs/day-1/00-setup/README.md) |
| 01-iac-fork … 03-core-workflow | unchanged | — |
| 04-state | box + snippet | [`snippets/s3-backend/`](./snippets/s3-backend/README.md) |
| 05-state-encryption | box | KMS stretch skipped in v1 |
| 06-variables, 07-modules | unchanged | — |
| 08-naming-labels | box + example twin | [`examples/naming-labels-ovh/`](./examples/naming-labels-ovh/README.md) |
| 09-best-practices | unchanged | — |
| 10-differentiators | box + twin | [`labs/day-1/10-differentiators/`](./labs/day-1/10-differentiators/README.md) |
| 11-taco-landscape … 13-static-analysis | unchanged | — |
| 14-security-scanners | box | runs as-is |
| 15-conditions-checks | unchanged | — |
| 16-tofu-test | box + twin | [`labs/day-2/16-tofu-test/`](./labs/day-2/16-tofu-test/README.md) |
| 17-mocking | box | runs as-is |
| 18-terratest-cost | box + twin | [`labs/day-2/18-terratest-cost/`](./labs/day-2/18-terratest-cost/README.md) |
| 19-testing-cicd, 20-why-terramate | unchanged | — |
| 21-stacks | box | runs as-is |
| 22-codegen … 25-terramate-ci-cloud | unchanged | — |
| 26-capstone | box + twin example | [`examples/capstone-ovh/`](./examples/capstone-ovh/README.md) |
| 27-terragrunt-comparison, 28-ecosystem-tooling | unchanged | — |
| — | OVH-native lab | [`bootstrap/`](./bootstrap/README.md) |

DynamoDB/SQS/SNS teaching is **rewritten, not dropped**: the capstone's table
and queue become bucket **versioning + lifecycle** on the same bucket.

## The roots

- [`bootstrap/`](./bootstrap/README.md) — the OVH-native lab. Creates the S3
  user + credentials and the budget alert with the `ovh` provider, teaching
  IAM-scoped service accounts. Run this after your first bucket.
- [`smoke/`](./smoke/README.md) — the real-OVH smoke root. Applies one bucket
  with versioning, a lifecycle rule and an object tag (the exact shapes the
  twins use), then destroys it. This is the de-risking step, run once by a
  maintainer before the twins are trusted.
- [`labs/`](./labs/) — the Day-1/2 twins (00, 10, 16, 18).
- [`examples/`](./examples/) — the Day-3 example twins (`capstone-ovh`,
  `naming-labels-ovh`).
- [`snippets/s3-backend/`](./snippets/s3-backend/README.md) — the Lab 04 S3
  backend stretch, pointed at OVH.

## Running the track

```bash
task ovh:verify                                   # unit lane: fmt + validate + mock test
task ovh:plan  DIR=variant/ovh/labs/day-1/00-setup
task ovh:apply DIR=variant/ovh/labs/day-1/00-setup
task ovh:teardown                                 # destroy every variant root with state
```

Set the credentials the setup guide produced before any real plan/apply:

```bash
export AWS_ACCESS_KEY_ID="<ovh s3 access key>"
export AWS_SECRET_ACCESS_KEY="<ovh s3 secret key>"
export AWS_DEFAULT_REGION="gra"
```

## Honest limitations

- The unit lane proves the twins' configs are valid and their contracts hold
  under mock. It does **not** prove OVH connectivity — that is the smoke root's
  job, and it is a manual, maintainer-run step in v1.
- `aws`-provider-against-OVH-S3 parity for versioning, lifecycle and tagging
  is to be proven by the smoke root, not assumed. Backend locking (`use_lockfile`)
  **remains unverified**: the smoke root uses local state and does not exercise
  the S3 backend, so its real-OVH proof needs a separate run against an OVH
  state bucket and is an open follow-up.
- `aws_s3_bucket_policy`, public access blocks and SSE-KMS are **not available**
  on OVH standard regions, so the variant ships **no bucket policy** in v1.
  Least-privilege bucket access via the OVH-native
  `ovh_cloud_project_user_s3_policy` is a documented stretch/follow-up that is
  not implemented yet.
- The `skip_*` flags in the twin provider blocks are an **S3-compatibility
  idiom, not a habit**: against real AWS, `skip_credentials_validation = true`
  masks authentication problems at init time.
- CI integration against real OVH is **not wired**: it needs a funded OVH
  project and CI secrets, which is a maintainer decision still open. v1 ships
  the offline unit lane only.
- S3 checksum behaviour: the env template sets
  `AWS_REQUEST_CHECKSUM_CALCULATION` / `AWS_RESPONSE_CHECKSUM_VALIDATION` to
  `when_required` as a precaution (see the setup guide, section 4). Whether OVH
  needs it is **to be confirmed by the smoke run**.

## Cleanup

Every twin README ends with its own cleanup step. To sweep the whole track in
one command, run `task ovh:teardown`, which walks the variant roots in
dependency order and destroys the state it finds, with three safety rules:

- `import/` roots (Lab 10 Part B) are **skipped**: they adopted a bucket you
  created, and destroying them deletes that real bucket. Release it with
  `tofu state rm` instead, or pass `-- --include-imported` to destroy it anyway.
- If any root fails to destroy, the bootstrap root is **kept** — it holds the
  budget alert and the credentials the failed roots need — and the task exits
  non-zero with a list of what failed.
- Destroy runs with `-input=false`, so a root that needs a variable
  (`TF_VAR_state_passphrase`, `TF_VAR_alert_email`) fails loudly instead of
  waiting on a prompt. Export it and re-run.

## Design

The decisions that shape this tree, kept here so they travel with the code:

- **Same branch, separate tree.** The variant lives in `variant/ovh/` on the
  main branch, not in a fork or a long-lived branch, so it cannot silently fall
  behind the base labs. The base gates do not discover it; its own unit lane
  (`task ovh:verify`, CI job `verify-ovh-unit`) does.
- **Twins, not overrides.** A lab whose cloud wiring changes gets a small twin
  root that reuses the base modules (`modules/naming`, `modules/labels`) and
  restates only the provider wiring. The variant verify checks the files a twin
  copies verbatim (and its `go.mod`) against the base, so drift reds instead of
  waiting for a manual re-diff.
- **S3-only cost envelope.** Every twin uses Object Storage and nothing else,
  so the cost is pennies whatever the voucher is worth. DynamoDB/SQS teaching is
  rewritten onto bucket versioning and lifecycle rather than dropped.
- **What is not proven yet.** The `aws` provider's versioning, lifecycle,
  tagging and versioned-bucket destroy against real OVH (the smoke root decides),
  the checksum settings above, the IAM policy's project-scoped resource URN
  (the bootstrap root), and S3 backend locking on OVH. Until the smoke run
  passes, treat the twins as validated offline only.
