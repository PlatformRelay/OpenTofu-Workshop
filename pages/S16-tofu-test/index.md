---
layout: section-cover
image: /covers/section-16-the-dry-run-rehearsal.png
day: Day 2
section: '16'
tier: core
---

# Native testing — `tofu test`

<!--
Say: OpenTofu has a native test runner, so infrastructure contracts can live beside the configuration they protect. This section moves from test-file anatomy to plan and apply runs, variables, assertions, and expected failures. (~1 min)
Then: “Start with the smallest useful native test.”
-->

---

<span class="kw-kicker">A first-class test runner</span>

# Configuration is executable; test its contract

```text
main.tf  +  *.tftest.hcl  ──tofu test──▶  run  ──▶  assert  ──▶  pass / fail
```

- Test files use HCL and are discovered in the root or `tests/`.
- Each `run` plans or applies the configuration in an isolated test run.
- A failing assertion returns a non-zero exit code suited to automation.

<div class="mt-4 kw-panel p-3 text-sm">
Native testing became generally available with OpenTofu 1.6.
</div>

<!--
Say: A native test is configuration plus a test file, executed by the same CLI learners already use. Runs are isolated, assertions describe observable contracts, and failure is machine-readable through the process exit code. OpenTofu 1.6 made this framework generally available. (~3 min)
Then: “Now build a test one responsibility at a time.”
-->

---
layout: two-cols-code
clicks: 3
---

<span class="kw-kicker">Build the contract</span>

# From run to useful failure

````md magic-move
```hcl
run "project_contract" {
  command = plan
}
```
```hcl
run "project_contract" {
  command = plan

  variables {
    project = "crmapp"
  }
}
```
```hcl
run "project_contract" {
  command = plan

  variables {
    project = "crmapp"
  }

  assert {
    condition     = output.project == "crmapp"
    error_message = "expected crmapp, got ${output.project}"
  }
}
```
````

::right::

<KwCard heading="1 · Run" kind="test" variant="ok">
Choose a stable name and the cheapest command that can prove the contract.
</KwCard>
<div class="mt-3">
<KwCard heading="2 · Arrange" kind="variable">
Per-run variables override root test variables for this run only.
</KwCard>
</div>
<div class="mt-3">
<KwCard heading="3 · Assert" kind="validation" variant="warn">
Compare an observable value and make the failure explain expected versus actual.
</KwCard>
</div>

<!--
Say: A run names one scenario. Add inputs locally when the scenario differs from shared defaults, then assert only a value the chosen command can know. Error messages should make diagnosis possible without opening the test source. (~4 min)
Then: “The command determines how much reality the run crosses.”
-->

---

<span class="kw-kicker">Choose the boundary deliberately</span>

# `plan` and `apply` answer different questions

| | `command = plan` | `command = apply` |
| --- | --- | --- |
| Proves | configuration and planned values | post-apply values and resource behaviour |
| Side effects | no infrastructure created | creates, then test cleanup destroys |
| Best default | fast contract tests | risks only observable after apply |
| Needs | providers/configuration needed to plan | reachable real or emulated API when resources require one |

<div class="mt-4 grid grid-cols-2 gap-3 text-sm">
<div class="kw-panel p-3"><strong>Rule:</strong> prefer plan until the claim requires apply.</div>
<div class="kw-panel p-3"><strong>Lab:</strong> built-in <code>terraform_data</code> makes the apply lifecycle real without cloud credentials.</div>
</div>

<!--
Say: Plan runs are the default because they are fast and avoid resource side effects. Apply runs earn their cost when the assertion needs a value or behaviour that only exists after creation; provider-backed resources then need a real or emulated API. The lab uses a built-in resource so learners can observe native apply and cleanup without Docker. (~3 min)
Then: “Inputs can be shared or scoped to one scenario.”
-->

---

<span class="kw-kicker">Arrange once, override narrowly</span>

# Variables have two useful scopes

```hcl
variables {
  project          = "crmapp" # shared by every run
  expected_project = "crmapp"
}

run "project_contract" {
  command = plan
}

run "another_project" {
  command = plan
  variables {
    project = "orders"        # this run only
  }
}
```

- Root `variables` establish the test fixture.
- A run-level block overrides only the inputs that scenario changes.

<!--
Say: Root variables keep repeated setup visible once. A run-level variables block describes the delta for one scenario, which makes a test suite read like a set of cases rather than duplicated fixtures. CLI `-var` values can override the root module input during an intentional break exercise. (~3 min)
Then: “Not every expected error should fail the suite.”
-->

---

<span class="kw-kicker">Negative tests without false alarms</span>

# Declare the diagnostic you expect

```hcl
run "invalid_project_is_rejected" {
  command = plan

  variables {
    project = "BAD!"
  }

  expect_failures = [
    var.project,
  ]
}
```

`expect_failures` passes only when the named checkable object produces the expected diagnostic.

<div class="mt-4 kw-panel p-3 text-sm">
Do not use it to silence unrelated errors: target the variable, output, resource, or check that owns the contract.
</div>

<!--
Say: Negative tests prove that guardrails reject bad input. Naming the exact checkable object distinguishes an expected validation diagnostic from an unrelated failure, so a broken provider or syntax error cannot masquerade as success. (~3 min)
Then: “Put all three patterns into one executable lab.”
-->

---
layout: lab
duration: 35 min
---

# Lab — plan, apply, and expected failure

<LabCallout number="16" duration="35 min" environment="mock ✓ · built-in apply · no Docker">
Run a shared-variable plan contract, a real provider-free apply test, and an
<code>expect_failures</code> case. Break one assertion through a CLI variable,
read the diagnostic, then restore the passing contract.
</LabCallout>

`labs/day-2/16-tofu-test.md`

<!--
Say: Learners execute a tracked native test suite rather than pasting disposable files. They see plan and apply runs, an expected validation failure, then deliberately break an assertion and use its diagnostic to fix the test input. The stretch adds verbose output and filtering. (~35 min)
Then: “Debrief by matching each syntax feature to the risk it covers.”
-->

---
layout: recap
next: Mocking providers without credentials
---

# Native tests are contracts with boundaries

- `run` names a scenario; `assert` makes its observable promise executable.
- Prefer `command = plan`; use `apply` only when the claim needs created state.
- Root variables define the fixture; run variables define the scenario delta.
- `expect_failures` proves a specific guardrail rejects invalid input.

<!--
Say: Native tests turn module expectations into versioned, executable contracts. The strongest suite uses cheap plan runs broadly, narrowly chosen apply runs, scoped fixtures, diagnostic assertions, and explicit negative cases. (~3 min)
Then: “Next: Mocking providers without credentials.”
-->
