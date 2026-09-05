# Lab 08 — Name & tag with the flagship modules (S08) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the repository root; the tracked workdir is `examples/naming-labels-demo/`,
reached with `tofu -chdir=examples/naming-labels-demo` (or an explicit `cd` where a
step says so).

### Step 1 — Read the contract

Open the two modules and the demo root and answer: **how does a bad name get
stopped before it reaches a provider?**

```bash
cd examples/naming-labels-demo
sed -n '1,40p' ../../modules/naming/outputs.tf
```

**Task:** Name the two mechanisms that guard the composed name.

---

<details><summary>Solution</summary>

1. **`variable "..." { validation { ... } }`** in `modules/naming/variables.tf` —
   rejects a bad input (e.g. a too-short `project`) *before the module runs*.
2. **`output "name" { precondition { ... } }`** in `modules/naming/outputs.tf` —
   the last line of defence: an unknown `resource_type` or an over-long name can
   never *leave* the module, even if a caller swaps in an odd profile.

</details>

---

### Step 2 — Plan with a mocked provider (no cloud)

The demo root's unit test uses an **aliased** `mock_provider "aws"`, so it plans
anywhere — including CI with no Docker:

```bash
tofu -chdir=examples/naming-labels-demo init -backend=false
tofu -chdir=examples/naming-labels-demo test -filter=tests/unit.tftest.hcl
```

> Run this from the repo root. Or run the whole unit gate at once with
> `task verify` — it validates and `tofu test`s every module and example.

**Task:** Why does the unit test assert on the **label map** but not on the full
composed bucket name?

---

<details><summary>Solution / expected output</summary>

```console
$ tofu -chdir=examples/naming-labels-demo test -filter=tests/unit.tftest.hcl
  tests/unit.tftest.hcl... in progress
    run "unit_plan_with_mock"... pass
  tests/unit.tftest.hcl... tearing down
  tests/unit.tftest.hcl... pass

Success! 1 passed, 0 failed.
```

The composed `name` embeds `random_id.suffix`, which is **unknown at plan time**.
The unit lane therefore asserts the *known* parts — the label map — and leaves the
full-name assertion to the LocalStack `apply` test (Step 4), where the suffix is
resolved.

</details>

---

### Step 3 — Break a naming validation, then fix it

The demo root passes `project` straight into `module.naming`. Feed it a project
slug that is too short and plan:

```bash
tofu -chdir=examples/naming-labels-demo plan -var 'project=ab'
```

**Task:** What error do you get, and which guard fired?

**Fix:** use a valid project slug and confirm it plans clean:

```bash
tofu -chdir=examples/naming-labels-demo plan -var 'project=crmapp'
```

---

<details><summary>Solution / expected output</summary>

```console
│ Error: Invalid value for variable
│
│   on main.tf line 14, in module "bucket_name":
│   14:   project       = var.project
│
│ project must be 4-10 chars, lowercase letters/digits, starting with a letter.
```

The **variable validation** on the `naming` module's `project` input (regex
`^[a-z][a-z0-9]{3,9}$`) rejected `ab` before the module composed anything —
exactly the `bad_project_length_fails` case the module's own `tofu test` suite
covers. You get one error per call site: both `module "bucket_name"` and
`module "table_name"` pass `project` through, so both fail.

</details>

<details><summary>Expected output</summary>

The plan now proceeds — `module.bucket_name.name` composes to
`s3-crmapp-d-web-<hex>` and the plan shows the S3 bucket and DynamoDB table with
the shared tag map. (The `<hex>` suffix stays unknown until apply.)

</details>

---

### Step 4 — Apply on LocalStack and see the names land

Bring up LocalStack and apply the demo root against it — no real AWS, no cost:

```bash
task lab:up                                   # start LocalStack on :4566
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'   # S05: >= 16 chars
task lab:apply DIR=examples/naming-labels-demo
```

**Task:** Show the concrete bucket name and its `owner` + `cost-center` tags.

Run the integration test to assert the full naming pattern and the tags on the
real (LocalStack) resource:

```bash
task verify:integration
```

## Expected observations

- The demo root plans with an **aliased `mock_provider`** — no cloud, no Docker.
- A too-short `project` is rejected by **variable validation** before compose.
- On apply, `module.naming` produces `s3-crmapp-d-web-<hex>` and
  `ddb-crmapp-d-sessions-<hex>`; `module.labels` applies one shared tag map.
- State is **encrypted at rest** (S05) — the passphrase is supplied out-of-band.

## Cleanup / panic reset

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/naming-labels-demo destroy -auto-approve
rm -f examples/naming-labels-demo/*.tfstate*   # destroy empties state, it does not delete it
task lab:down          # stop LocalStack and remove its volumes
```

Nothing is created on real AWS, so there is nothing to bill or leak.

## Stretch (optional)

- Trigger the **output precondition** instead of the variable validation: plan
  with `-var 'environment=preprod'`. It passes the regex but is not a key in the
  environment profile, so `output.name`'s precondition rejects it by name.
- Swap the naming profile: pass a `resource_short_names` map override (as the
  `profile_swap_override` test does) to prove the module takes a GCP profile
  without a fork.
- Flip `enforced = true` in `examples/naming-labels-demo/providers.tf`, drop the
  passphrase, and watch the encrypted-state guard refuse to read plaintext.

<details><summary>Solution / expected output</summary>

```console
$ tofu -chdir=examples/naming-labels-demo output bucket_name
"s3-crmapp-d-web-a1f3"

$ tofu -chdir=examples/naming-labels-demo output -json labels | jq '{owner, "cost-center"}'
{
  "owner": "platform-team@example.com",
  "cost-center": "CC-1234"
}
```

Both resources carry the **same** tag map — that is the point of one `labels`
module. The bucket name matches the `s3-crmapp-d-web-<hex>` pattern the
integration test asserts.

</details>

<details><summary>Expected output</summary>

```console
  run "localstack_apply"... pass

Success! 1 passed, 0 failed.
```

The apply-lane test resolves the random suffix, so it can assert the full
`^s3-crmapp-d-web-[a-z0-9]{4}$` pattern and that every required label landed as a
tag.

</details>

---

## Expected state / output

- The demo root plans with an **aliased `mock_provider`** — no cloud, no Docker.
- A too-short `project` is rejected by **variable validation** before compose.
- On apply, `module.naming` produces `s3-crmapp-d-web-<hex>` and
  `ddb-crmapp-d-sessions-<hex>`; `module.labels` applies one shared tag map.
- State is **encrypted at rest** (S05) — the passphrase is supplied out-of-band.

Representative console output from the inline spoilers above applies when your
toolchain versions match the lab pin.

## Explanation

OpenTofu reconciles declared configuration against stored state on every plan and
apply, so the commands above succeed only when the tracked HCL, provider plugins,
and backend settings match what the lab authored. Each step therefore wires inputs
(outputs, variables, modules, or data sources) before the resources that consume
them, because the graph must be acyclic at evaluation time.

When a step reads remote or emulated cloud APIs (LocalStack or mock providers), the
provider block binds credentials and endpoints first; resources then call those APIs
and persist returned attributes into state. That is why init/plan/apply ordering
matters and why re-running apply without changes reports zero additions.

## Troubleshooting and recovery

If a step fails mid-lab, return to a clean tree before retrying:

```bash
export TF_VAR_state_passphrase='a-long-demo-passphrase-1234'
tofu -chdir=examples/naming-labels-demo destroy -auto-approve
rm -f examples/naming-labels-demo/*.tfstate*   # destroy empties state, it does not delete it
task lab:down          # stop LocalStack and remove its volumes
```

Nothing is created on real AWS, so there is nothing to bill or leak.

Replay from the failing step (every command runs from the repo root). To fully reset generated state, run `tofu -chdir=examples/naming-labels-demo destroy -auto-approve` when the lab created resources, then `tofu -chdir=examples/naming-labels-demo init` and retry the plan.

## Stretch solution

### Commands / manifest

- Trigger the **output precondition** instead of the variable validation: plan
- Swap the naming profile: pass a `resource_short_names` map override (as the
- Flip `enforced = true` in `examples/naming-labels-demo/providers.tf`, drop the

Example verification from the repo root:

```bash
tofu -chdir=examples/naming-labels-demo plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
