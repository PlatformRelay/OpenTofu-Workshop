# Example — `capstone-build`

Reference implementation for **Lab 26 · Part B (build variant)** — the
stretch/homework track where the learner **authors** the colony's 4th resource
instead of consuming shipped code.

## What lives here

| File | Role |
|------|------|
| `colony_events.tf` | **Drop-in** — one valid implementation of the Part B contract: an `aws_sns_topic` named by [`modules/naming`](../../modules/naming), tagged with the shared `module.labels` map, plus output + `check` guardrail. Byte-identical to the fences in the lab/solution (drift-checked). |
| `tests/build.tftest.hcl` | **Drop-in** — the matching unit test: `plan` + aliased `mock_provider`, fixed suffix so the composed name is known at plan. |
| `context.tf` | **Not part of the drop-in.** Mirrors only what the drop-ins reference from [`examples/capstone`](../capstone) (variables + the shared `module.labels` call), so this reference root validates and unit-tests standalone under `task verify`. |

Both drop-in files reference addresses that exist identically in
`examples/capstone/` (`var.project`, `var.environment`, `module.labels`), and
this directory sits at the same depth as `examples/capstone/`, so the relative
`../../modules/…` sources resolve in both roots — copy them in unchanged.

## The learner never starts from this directory

Part B is authored **from a spec** in
[`labs/day-3/26-capstone.md`](../../labs/day-3/26-capstone.md): the learner
writes their own `examples/capstone/colony_events.tf` and
`examples/capstone/tests/build.tftest.hcl` in their working copy, then judges
the result with the **existing** gates (`tofu fmt -check`, `tofu validate`,
`tofu test`, `task verify`). Acceptance is gate-green, not matching these bytes.
Compare here only after your gates pass.

## Run it (standalone)

```sh
tofu -chdir=examples/capstone-build init -backend=false
tofu -chdir=examples/capstone-build validate
tofu -chdir=examples/capstone-build test
```

No Docker, no LocalStack, no encryption: the unit test mocks the AWS provider.
Applying the events topic against LocalStack is intentionally out of scope —
the capstone's provider `endpoints` block does not route `sns`, so the drop-in
stays a mock-only exercise (see the lab's Part B notes).
