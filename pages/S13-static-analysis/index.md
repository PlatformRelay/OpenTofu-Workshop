---
layout: section-cover
image: /covers/section-13-the-inspection-bench.png
day: Day 2
section: '13'
tier: core
---

# Static analysis & formatting

## Make the cheapest failures impossible to miss

---
layout: topology
---

<span class="kw-kicker">S13 · fast feedback</span>

# Stop defects before a plan

<div class="grid grid-cols-4 gap-4 mt-10">
  <KwCard v-click title="1 · Edit" icon="✍️" tone="neutral">
    Change tracked HCL in a small, reviewable step.
  </KwCard>
  <KwCard v-click title="2 · Format" icon="↔️" tone="info">
    Canonical layout removes style debate.
  </KwCard>
  <KwCard v-click title="3 · Validate" icon="🧩" tone="warning">
    Parse HCL and check native type contracts.
  </KwCard>
  <KwCard v-click title="4 · Lint" icon="🔎" tone="success">
    Apply conventions and semantic rules.
  </KwCard>
</div>

<p v-click class="mt-8 text-center text-xl font-semibold">Fast → deterministic → local → safe to automate</p>

<!--
Say: Static analysis is the broad base of the testing pyramid because it is cheap enough to run constantly. Each step answers a narrower question before any provider API or infrastructure is involved. (~2 min)
Then: Begin with the smallest contract: canonical formatting.
-->

---
layout: comparison
---

<span class="kw-kicker">formatting · one canonical shape</span>

# `fmt` fixes; `fmt -check` enforces

::left::

### Local feedback

```bash
tofu fmt -diff main.tf
```

- rewrites the file in place
- prints the changed filename
- `-diff` shows what moved

::right::

### Gate feedback

```bash
tofu fmt -check -diff main.tf
```

- changes nothing
- exits non-zero on drift
- ideal for CI and pre-commit

<p v-click class="mt-5 text-sm opacity-75">Formatting says nothing about whether the configuration is valid.</p>

<!--
Say: `tofu fmt` is the repair command, while `-check` turns the same canonical formatter into an enforcement gate. A clean format result proves only layout, not correctness. (~2 min)
Then: Move from text shape to OpenTofu's own configuration contracts.
-->

---
layout: code-annotated
---

<span class="kw-kicker">validation · read the diagnostic</span>

# The error gives four clues

```hcl {none|1-4|5-9|8|5-9}
variable "service_names" {
  description = "Services included in the static-analysis exercise."
  type        = list(string)
  default     = "payments"
}

output "service_count" {
  value = length(var.service_names)
}
```

::notes::

<CodeNote at="1" label="Declaration">OpenTofu identifies the variable block.</CodeNote>
<CodeNote at="2" label="Constraint">The contract requires a list of strings.</CodeNote>
<CodeNote at="3" label="Value">The default is one string, not a list.</CodeNote>
<CodeNote at="4" label="Repair">Use <code>["payments"]</code>; do not weaken the type.</CodeNote>

<!--
Say: `tofu validate` parses the configuration and checks internal contracts without planning infrastructure. Read its location, expression, expected type, and observed type in order; here the right repair is to make the value satisfy the declared list contract. (~3 min)
Then: Native validation stops there, so add a semantic ruleset.
-->

---
layout: two-cols-code
---

<span class="kw-kicker">tflint · semantic conventions</span>

# Valid HCL can still be suspicious

::left::

```hcl
variable "legacy_name" {
  description = "Retired input."
  type        = string
  default     = "retired"
}
```

This declaration is valid—but unused.

::right::

```console
$ tflint --minimum-failure-severity=warning
1 issue(s) found:

Warning: [Fixable] variable "legacy_name"
is declared but not used
(terraform_unused_declarations)
```

<p v-click class="mt-5 text-sm opacity-75">TFLint complements `validate`; it does not replace it.</p>

<!--
Say: TFLint applies rules that are outside OpenTofu's validity contract. An unused variable is legal HCL, yet it misleads callers and deserves a visible warning; the minimum-severity flag makes warnings gate the exercise. (~3 min)
Then: Show where this repository's lint policy actually lives.
-->

---
layout: code-walkthrough
---

<span class="kw-kicker">policy as code · `.tflint.hcl`</span>

# Teach the checked-in ruleset

```hcl {1-4|6-9|11-14}
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}
```

::notes::

<CodeNote at="1" label="Baseline">The bundled Terraform ruleset supplies the recommended baseline.</CodeNote>
<CodeNote at="2" label="Intent">Explicit rules make workshop policy discoverable.</CodeNote>
<CodeNote at="3" label="Convention">Names follow one repository-wide shape.</CodeNote>

<!--
Say: The repository root `.tflint.hcl` is the policy learners run, not a slide-only approximation. The recommended preset supplies breadth and explicit rules document the conventions we care about. (~2 min)
Then: Wire the same commands into the commit boundary.
-->

---
layout: comparison
---

<span class="kw-kicker">automation · `.pre-commit-config.yaml`</span>

# One policy, two feedback loops

::left::

### On demand

```bash
tofu fmt -check -recursive
tofu validate
tflint --recursive
```

Use while editing and debugging.

::right::

### Before commit

```bash
export PCT_TFPATH="$(command -v tofu)"
pre-commit run --all-files
```

The checked-in hooks run formatting, TFLint, docs, secret scanning, and hygiene.

<p v-click class="mt-5 text-sm opacity-75">Pre-commit shortens feedback; CI remains the shared authority.</p>

<!--
Say: The checked-in pre-commit configuration reuses these commands and selects the OpenTofu binary through `PCT_TFPATH`. Local hooks improve speed, while CI still protects contributors who have not installed the hook. (~3 min)
Then: Put the full loop into practice on a deliberately broken module.
-->

---
layout: lab
duration: 30 min
---

<span class="kw-kicker">lab · break → read → fix</span>

# Repair three defect classes

<LabCallout lab="labs/day-2/13-static-analysis.md" duration="30 min" />

1. Let `fmt -check` expose layout drift; repair it with `tofu fmt`.
2. Read the `validate` type error line-by-line; fix the value, not the contract.
3. Let TFLint find the unused declaration; remove it and rerun all gates.

<!--
Say: Learners now run the same escalating loop on one tracked fixture. Emphasize that every failure is intentional and that the cleanup restores the planted defects for the next learner. (~30 min)
Then: Return to the pyramid with a compact operating rule.
-->

---
layout: recap
next: S14 · Security & policy scanners
---

<span class="kw-kicker">recap · cheapest useful signal first</span>

# Format → validate → lint → automate

- **Format** removes irrelevant textual variation.
- **Validate** enforces OpenTofu syntax and native contracts.
- **TFLint** adds repository and ecosystem conventions.
- **Pre-commit + CI** make the loop repeatable for the whole team.

<p v-click class="mt-8 text-xl font-semibold">Static checks are necessary—and intentionally incomplete.</p>

<!--
Say: The static-analysis loop layers independent signals, from canonical text to semantic conventions, and automates them at the earliest useful boundary. It cannot discover exposed services or organization-specific policy violations. (~2 min)
Then: S14 · Security & policy scanners extends the base with security findings and custom policy.
-->
