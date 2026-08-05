# Lab 17 — Mocking providers (`mock_provider`) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-2/17-mocking/` unless a step says otherwise.

### Step 1 — Prove LocalStack is down

From the repository root:

```bash
test -z "$(docker ps -q --filter name=opentofu-workshop-localstack)" \
  && echo "LocalStack is not running"
```

If the echo does not print, stop the workshop stack first:

```bash
task lab:down
```

Then re-run the `test -z` check until you see `LocalStack is not running`.

<details><summary>Solution / expected output</summary>

When the container is absent the confirmation line is:

```console
LocalStack is not running
```

`task lab:down` is safe when nothing is running — Compose reports that it
removed (or found nothing to remove for) the workshop LocalStack service.
Keep LocalStack down for every remaining step.

</details>

---

### Step 2 — Inspect the apply-style appetite

S16’s LocalStack apply test looked like this (teaching snippet — **not** a
tracked file in this lab):

```hcl
run "localstack_apply" {
  command = apply

  assert {
    condition     = can(regex("^s3-.*", output.bucket_name))
    error_message = "expected a module-named bucket, got ${output.bucket_name}."
  }
}
```

That shape needs a reachable S3 API. This lab’s root still *configures* AWS
toward `localhost:4566`, but the unit suite will **mock** the provider so the
endpoint is never contacted.

Inspect the tracked root:

```bash
sed -n '1,60p' labs/day-2/17-mocking/main.tf
```

<details><summary>Solution / exact tracked file</summary>

<!-- source: labs/day-2/17-mocking/main.tf -->
```hcl
terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}

variable "bucket_name" {
  description = "Deterministic bucket name used by the mocked plan contract."
  type        = string
  default     = "s3-crmapp-d-web-lab"
}

variable "expected_bucket_id" {
  description = "Expected mocked bucket id asserted by the unit test."
  type        = string
  default     = "s3-crmapp-d-web-lab"
}

# Real provider config — only used when a test does NOT mock aws.
# The unit suite replaces this with mock_provider, so LocalStack can be down.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3 = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "web" {
  bucket = var.bucket_name
}

output "bucket_id" {
  description = "Bucket id from the aws_s3_bucket.web resource."
  value       = aws_s3_bucket.web.id
}

output "bucket_arn" {
  description = "Bucket ARN from the aws_s3_bucket.web resource."
  value       = aws_s3_bucket.web.arn
}
```

The provider block is the apply-shaped leftover. The mock will replace it for
the unit run.

</details>

---

### Step 3 — Inspect the mocked plan conversion

```bash
sed -n '1,80p' labs/day-2/17-mocking/tests/unit.tftest.hcl
```

<details><summary>Solution / exact tracked file</summary>

<!-- source: labs/day-2/17-mocking/tests/unit.tftest.hcl -->
```hcl
# Converted from an apply-style LocalStack test: mock the aws provider so a
# plan-only run needs neither credentials nor a live service (Docker can be down).

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      id  = "s3-crmapp-d-web-lab"
      arn = "arn:aws:s3:::s3-crmapp-d-web-lab"
    }
  }
}

run "mocked_bucket_plan" {
  command = plan

  # Run-level override wins over mock_resource defaults for this address.
  override_resource {
    target = aws_s3_bucket.web
    values = {
      id  = "s3-crmapp-d-web-lab"
      arn = "arn:aws:s3:::s3-crmapp-d-web-lab"
    }
  }

  assert {
    condition     = aws_s3_bucket.web.id == var.expected_bucket_id
    error_message = "expected bucket id ${var.expected_bucket_id}, got ${aws_s3_bucket.web.id}"
  }

  assert {
    condition     = aws_s3_bucket.web.arn == "arn:aws:s3:::${var.bucket_name}"
    error_message = "expected ARN for ${var.bucket_name}, got ${aws_s3_bucket.web.arn}"
  }

  assert {
    condition     = output.bucket_id == var.expected_bucket_id
    error_message = "expected output.bucket_id ${var.expected_bucket_id}, got ${output.bucket_id}"
  }
}
```

Conversion checklist:

1. `command = apply` → `command = plan`
2. add `mock_provider "aws"` with `mock_resource` `defaults`
3. pin the address with `override_resource` (run-level wins)
4. assert planned / mocked values — never a live API response

</details>

---

### Step 4 — Init, validate, and run with zero credentials

```bash
cd labs/day-2/17-mocking
tofu init -no-color
tofu validate -no-color
env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN \
  -u AWS_PROFILE \
  tofu test -no-color
```

Re-confirm LocalStack stayed down:

```bash
test -z "$(docker ps -q --filter name=opentofu-workshop-localstack)" \
  && echo "LocalStack still not running"
```

<details><summary>Solution / expected output</summary>

This is the transcript from OpenTofu **1.12.3** with LocalStack stopped. A first
init installs AWS 5.100.0; a cached init says `Using previously-installed`
instead of `Installing` — both are fine.

```console
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching ">= 5.0.0, < 6.0.0"...
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed, key ID 0C0AF313E5FD9F80)

Providers are signed by their developers.
If you'd like to know more about provider signing, you can read about it here:
https://opentofu.org/docs/cli/plugins/signing/

OpenTofu has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that OpenTofu can guarantee to make the same selections by default when
you run "tofu init" in the future.

OpenTofu has been successfully initialized!

You may now begin working with OpenTofu. Try running "tofu plan" to see
any changes that are required for your infrastructure. All OpenTofu commands
should now work.

If you ever set or change modules or backend configuration for OpenTofu,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
Success! The configuration is valid.
tests/unit.tftest.hcl... pass
  run "mocked_bucket_plan"... pass

Success! 1 passed, 0 failed.
```

The credential-stripped `env -u … tofu test` ends with the same
`Success! 1 passed, 0 failed.` line. The LocalStack confirmation prints:

```console
LocalStack still not running
```

</details>

---

### Step 5 — Break a wrong override default

Keep `mock_resource` defaults correct. Poison **only** the run-level
`override_resource` values so `id` and `arn` become `wrong-bucket`:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path("tests/unit.tftest.hcl")
text = p.read_text()
old = """  override_resource {
    target = aws_s3_bucket.web
    values = {
      id  = \"s3-crmapp-d-web-lab\"
      arn = \"arn:aws:s3:::s3-crmapp-d-web-lab\"
    }
  }"""
new = """  override_resource {
    target = aws_s3_bucket.web
    values = {
      id  = \"wrong-bucket\"
      arn = \"arn:aws:s3:::wrong-bucket\"
    }
  }"""
if old not in text:
    raise SystemExit("override_resource block not found — restore the tracked file first")
p.write_text(text.replace(old, new, 1))
print("override_resource poisoned")
PY
tofu test -no-color
```

The command must exit non-zero. Which side is the poisoned override, and which
side is the expected contract?

<details><summary>Solution / captured failure</summary>

This is the verbatim OpenTofu **1.12.3** transcript from the authoring run
(override-only poison; `mock_resource` defaults still correct — the run-level
override wins):

```console
tests/unit.tftest.hcl... fail
  run "mocked_bucket_plan"... fail

Error: Test assertion failed

  on tests/unit.tftest.hcl line 26, in run "mocked_bucket_plan":
  26:     condition     = aws_s3_bucket.web.id == var.expected_bucket_id
    ├────────────────
    │ aws_s3_bucket.web.id is "wrong-bucket"
    │ var.expected_bucket_id is "s3-crmapp-d-web-lab"
    ├────────────────
    │ Diff: 
    │     "wrong-bucket" -> "s3-crmapp-d-web-lab"

expected bucket id s3-crmapp-d-web-lab, got wrong-bucket

Error: Test assertion failed

  on tests/unit.tftest.hcl line 31, in run "mocked_bucket_plan":
  31:     condition     = aws_s3_bucket.web.arn == "arn:aws:s3:::${var.bucket_name}"
    ├────────────────
    │ aws_s3_bucket.web.arn is "arn:aws:s3:::wrong-bucket"
    │ var.bucket_name is "s3-crmapp-d-web-lab"
    ├────────────────
    │ Diff: 
    │     "arn:aws:s3:::wrong-bucket" -> "arn:aws:s3:::s3-crmapp-d-web-lab"

expected ARN for s3-crmapp-d-web-lab, got arn:aws:s3:::wrong-bucket

Error: Test assertion failed

  on tests/unit.tftest.hcl line 36, in run "mocked_bucket_plan":
  36:     condition     = output.bucket_id == var.expected_bucket_id
    ├────────────────
    │ output.bucket_id is "wrong-bucket"
    │ var.expected_bucket_id is "s3-crmapp-d-web-lab"
    ├────────────────
    │ Diff: 
    │     "wrong-bucket" -> "s3-crmapp-d-web-lab"

expected output.bucket_id s3-crmapp-d-web-lab, got wrong-bucket

Failure! 0 passed, 1 failed.
```

`wrong-bucket` is the poisoned override. `s3-crmapp-d-web-lab` is the expected
contract from variables / naming. Exit status is `1`.

</details>

---

### Step 6 — Fix, rerun, and confirm isolation

Restore the tracked test file and re-run:

```bash
git checkout -- tests/unit.tftest.hcl
tofu test -no-color
test -z "$(docker ps -q --filter name=opentofu-workshop-localstack)" \
  && echo "LocalStack still not running"
```

## Expected observations

- A mocked plan run needs neither AWS credentials nor a live S3 endpoint.
- `mock_resource` `defaults` supply computed attributes a bare plan cannot know.
- A run-level `override_resource` wins over those defaults for one address.
- LocalStack can stay down for the entire green path — that is the edge criterion.
- A green mock still cannot prove permissions, quotas, or real destroy behaviour.

## Stretch — Verbose mocked plan

```bash
tofu test -no-color -verbose
```

## Cleanup / panic reset

From `labs/day-2/17-mocking`:

```bash
git checkout -- tests/unit.tftest.hcl
rm -rf .terraform
cd ../../..
test -z "$(docker ps -q --filter name=opentofu-workshop-localstack)" \
  && echo "LocalStack still not running"
```

<details><summary>Solution / expected output</summary>

```console
tests/unit.tftest.hcl... pass
  run "mocked_bucket_plan"... pass

Success! 1 passed, 0 failed.
LocalStack still not running
```

</details>

<details><summary>Solution / what to look for</summary>

This is a trimmed OpenTofu **1.12.3** verbose transcript. Unpinned computed
attributes receive auto-generated mock strings; the overridden `id` / `arn`
stay pinned:

```console
tests/unit.tftest.hcl... pass
  run "mocked_bucket_plan"... pass
# aws_s3_bucket.web will be created
+ resource "aws_s3_bucket" "web" {
    + arn    = "arn:aws:s3:::s3-crmapp-d-web-lab"
    + bucket = "s3-crmapp-d-web-lab"
    + id     = "s3-crmapp-d-web-lab"
    # …other computed attributes show random mock strings…
  }

Changes to Outputs:
  + bucket_arn = "arn:aws:s3:::s3-crmapp-d-web-lab"
  + bucket_id  = "s3-crmapp-d-web-lab"

Success! 1 passed, 0 failed.
```

Your random mock strings will differ. No container and no cloud call appear.

</details>

<details><summary>Solution / expected residue check</summary>

`git checkout` is a no-op when the file is already clean. Removing `.terraform`
leaves the tracked `main.tf`, `tests/unit.tftest.hcl`, and committed
`.terraform.lock.hcl`. The LocalStack confirmation should still print
`LocalStack still not running` — this lab never started it.

If you edited other files, restore them with `git checkout -- labs/day-2/17-mocking`
from the repository root, then re-run the `rm -rf` cleanup above.

</details>

---

## Expected state / output

- A mocked plan run needs neither AWS credentials nor a live S3 endpoint.
- `mock_resource` `defaults` supply computed attributes a bare plan cannot know.
- A run-level `override_resource` wins over those defaults for one address.
- LocalStack can stay down for the entire green path — that is the edge criterion.
- A green mock still cannot prove permissions, quotas, or real destroy behaviour.

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

From `labs/day-2/17-mocking`:

```bash
git checkout -- tests/unit.tftest.hcl
rm -rf .terraform
cd ../../..
test -z "$(docker ps -q --filter name=opentofu-workshop-localstack)" \
  && echo "LocalStack still not running"
```

<details><summary>Solution / expected residue check</summary>

`git checkout` is a no-op when the file is already clean. Removing `.terraform`
leaves the tracked `main.tf`, `tests/unit.tftest.hcl`, and committed
`.terraform.lock.hcl`. The LocalStack confirmation should still print
`LocalStack still not running` — this lab never started it.

If you edited other files, restore them with `git checkout -- labs/day-2/17-mocking`
from the repository root, then re-run the `rm -rf` cleanup above.

</details>

Re-enter `labs/day-2/17-mocking/` and replay from the failing step. To fully reset generated state, run `tofu destroy -auto-approve` when the lab created resources, then `tofu init -upgrade` and retry `tofu plan`.

## Stretch solution

### Commands / manifest

— Verbose mocked plan

```bash
tofu test -no-color -verbose
```

<details><summary>Solution / what to look for</summary>

This is a trimmed OpenTofu **1.12.3** verbose transcript. Unpinned computed
attributes receive auto-generated mock strings; the overridden `id` / `arn`
stay pinned:

```console
tests/unit.tftest.hcl... pass
  run "mocked_bucket_plan"... pass
# aws_s3_bucket.web will be created
+ resource "aws_s3_bucket" "web" {
    + arn    = "arn:aws:s3:::s3-crmapp-d-web-lab"
    + bucket = "s3-crmapp-d-web-lab"
    + id     = "s3-crmapp-d-web-lab"
    # …other computed attributes show random mock strings…
  }

Changes to Outputs:
  + bucket_arn = "arn:aws:s3:::s3-crmapp-d-web-lab"
  + bucket_id  = "s3-crmapp-d-web-lab"

Success! 1 passed, 0 failed.
```

Your random mock strings will differ. No container and no cloud call appear.

</details>

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
