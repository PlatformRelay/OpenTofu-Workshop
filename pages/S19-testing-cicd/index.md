---
layout: section-cover
image: /covers/section-19-the-automated-gauntlet.png
day: Day 2
section: '19'
tier: recommended
---

# Testing in CI/CD

## Make the pyramid run the same way for everyone

<!--
Say: Day 2 ends by wiring every layer you already know into a shared pipeline. The teaching artifact is this repository's real CI and verify script — not a toy workflow invented for slides. (~1 min)
Then: Start with the stages a trustworthy IaC pipeline must light up.
-->

---
layout: topology
clicks: 5
---

<span class="kw-kicker">S19 · pipeline stages</span>

# Light the pyramid in order

<div class="grid grid-cols-4 gap-3 mt-8">
  <KwCard v-click heading="1 · Static" icon="⚡" variant="plain">
    <code>fmt -check</code>, validate, lint, markdown hygiene
  </KwCard>
  <KwCard v-click heading="2 · Policy" icon="🛡️" variant="warn">
    Scanners and policy as code when the risk warrants them
  </KwCard>
  <KwCard v-click heading="3 · Unit" icon="🧪" variant="accent">
    <code>tofu test</code> plan/mock — no cloud required
  </KwCard>
  <KwCard v-click heading="4 · Integration" icon="🔌" variant="ok">
    Apply against a LocalStack <strong>service</strong> in CI
  </KwCard>
</div>

<p v-click class="mt-8 text-center text-xl font-semibold">Same commands locally and in CI — only the runner changes</p>

<!--
Say: Order matters because cheaper failures should stop the build before slower lanes spend minutes. Static and unit lanes stay free of cloud credentials; integration earns its cost by crossing a service boundary through LocalStack as a CI service container. (~3 min)
Then: Show where those lanes live in this repository.
-->

---
layout: code-walkthrough
---

<span class="kw-kicker">taught artifact · `.github/workflows/ci.yml`</span>

# Four jobs, one shared gate

```yaml {1-4|6-10|12-16|18-22}
# Excerpt from this repository's real CI
jobs:
  lint:                 # markdownlint on labs
  build:                # pnpm build · build:3day · build:templates
  verify-unit:          # scripts/verify.sh (fmt · validate · tofu test)
  verify-integration:   # tofu test -filter=… against LocalStack :4566
```

::notes::

<CodeNote at="1" label="Docs">Broken labs fail review before OpenTofu runs.</CodeNote>
<CodeNote at="2" label="Decks">All three root decks must build.</CodeNote>
<CodeNote at="3" label="Unit">The same gate developers run as <code>task verify</code>.</CodeNote>
<CodeNote at="4" label="Integration">Service container — not a laptop-only promise.</CodeNote>

<!--
Say: Point at the checked-in workflow. Lint and build protect the teaching surface; verify-unit reuses scripts/verify.sh so local and CI cannot diverge; verify-integration is a separate job with a pinned LocalStack service so apply tests never pretend to be unit tests. (~3 min)
Then: Zoom into the unit lane script.
-->

---
layout: two-cols-code
---

<span class="kw-kicker">unit lane · `scripts/verify.sh`</span>

# Local `task verify` is CI's unit job

::left::

```bash
# developers
task verify
# → bash scripts/verify.sh
```

- OpenTofu ≥ 1.8 preflight
- `tofu fmt -check` (enforcement)
- `validate` per module/example
- `tofu test` plan/mock only
- slide ↔ lab drift contracts

::right::

```yaml
# CI job verify-unit
- uses: opentofu/setup-opentofu@v1
  with:
    tofu_version: "1.10.3"
- run: |
    bash scripts/bootstrap-selftest.sh
    bash scripts/verify.sh
```

<p v-click class="mt-5 text-sm opacity-75">Integration <code>*.tftest.hcl</code> files are skipped here on purpose.</p>

<!--
Say: The script is the contract. CI installs a pinned OpenTofu and runs the identical unit lane. Integration files matching *integration*.tftest.hcl stay out of this job so a missing emulator cannot masquerade as a unit failure. (~3 min)
Then: Show how the integration job brings the emulator to the runner.
-->

---
layout: code-annotated
---

<span class="kw-kicker">integration lane · service container</span>

# LocalStack rides with the job

```yaml {none|1-3|4-8|9-12|13-16}
# Excerpt — verify-integration in ci.yml
services:
  localstack:
    image: localstack/localstack:4.9.2
    ports: ["4566:4566"]
    env:
      SERVICES: s3,dynamodb,iam,sqs,sns,kms,logs
    options: >-
      --health-cmd "curl -fsS http://localhost:4566/_localstack/health || exit 1"
steps:
  - name: Integration tests against LocalStack
    env:
      AWS_ENDPOINT_URL: http://localhost:4566
```

::notes::

<CodeNote at="1" label="Service">The emulator is a job service, not a manual laptop step.</CodeNote>
<CodeNote at="2" label="Pin">4.9.2 is the pinned community image this workshop standardises on.</CodeNote>
<CodeNote at="3" label="Health">The runner waits for healthy before steps run.</CodeNote>
<CodeNote at="4" label="Endpoint">Tests talk to the service URL with throwaway test credentials.</CodeNote>

<!--
Say: Integration in CI means the workflow declares the dependency. Pinning the image keeps licence and boot behaviour stable; a health check prevents racing the first API call. Learners who claim a LocalStack badge must run that emulator for real — this lab's paper workflow teaches the YAML shape without starting Docker. (~3 min)
Then: Contrast the commit-time loop with the shared authority.
-->

---
layout: comparison
---

<span class="kw-kicker">feedback loops · pre-commit vs CI</span>

# Fast locally; authoritative in CI

::left::

### On the commit boundary

```bash
export PCT_TFPATH="$(command -v tofu)"
pre-commit run --all-files
```

- rewrites with `tofu fmt` (repair)
- TFLint, docs, secrets, hygiene
- optional — not every clone installs hooks

::right::

### On every PR / push to main

```bash
bash scripts/verify.sh   # includes fmt -check
```

- fails the build on format drift
- runs validate + plan/mock tests
- protects contributors without local hooks

<p v-click class="mt-5 text-sm opacity-75">Pre-commit shortens feedback; required CI checks remain the team contract.</p>

<!--
Say: Pre-commit may rewrite files — that is a local repair loop. CI must enforce with fmt -check so an unformatted commit cannot slip through just because the runner rewrote a disposable workspace. Required status checks make that contract merge-blocking. (~3 min)
Then: Name the merge-gate pattern explicitly.
-->

---

<span class="kw-kicker">gating · required checks</span>

# Green means every required job passed

| Mechanism | What it does |
| --- | --- |
| Branch protection / rulesets | Lists the job names that must succeed before merge |
| Concurrent jobs | `lint`, `build`, `verify-unit`, `verify-integration` each vote |
| Concurrency group | Cancels superseded runs on the same ref |
| Environment badges | Lab headers declare `mock` vs `localstack` honestly |

<div v-click class="mt-5 kw-panel p-3 text-sm">
A job that rewrites formatting without <code>-check</code> can exit zero while the
branch still carries drift — that is a false green, and the lab will prove it.
</div>

<!--
Say: Required checks turn the pipeline into a merge policy. Badge honesty matters too: mock means paper or tool-only; localstack means the emulator actually ran. Never document a LocalStack badge for a YAML-only exercise. (~2 min)
Then: Keep provider and module pins from rotting in silence.
-->

---
layout: statement
kicker: 'dependency freshness'
---

**Renovate** or **Dependabot** open PRs when providers, actions, and module
pins move — CI is what proves those PRs are still trustworthy.

<!--
Say: Automation that only bumps versions without re-running fmt, validate, tofu test, and integration is incomplete. Treat dependency bots as PR authors whose work still has to clear the same required checks. This workshop repo may not ship a bot config yet; the pattern still belongs in the pipeline story. (~2 min)
Then: Put assembly and the false-green fmt trap into the lab.
-->

---
layout: lab
lab: labs/day-2/19-testing-cicd.md
duration: 30 min
env: 'mock ✓ (paper + fixture · no docker)'
---

# Lab — assemble the lanes; catch a false green

- Read this repository's real `ci.yml` and `verify.sh`.
- Complete a tracked workflow skeleton with unit + LocalStack-service jobs.
- Prove that `tofu fmt` without `-check` can exit zero on drift — then fix the gate.

<!--
Say: Learners stay on paper plus a local OpenTofu fixture — no Docker. They assemble the YAML from the real jobs, plant the missing -check failure mode, observe the false green, then restore the enforcement gate and the fixture. (~30 min)
Then: Debrief with a compact operating rule for CI.
-->

---
layout: recap
next: S20 · Why Terramate
---

<span class="kw-kicker">recap · shared evidence</span>

# Pipeline = pyramid + required checks

- Reuse one unit script locally and in CI (`scripts/verify.sh`).
- Keep integration behind a healthy LocalStack **service**, not a hope.
- Enforce formatting with `fmt -check`; rewriting alone is not a gate.
- Required checks + honest environment badges make the contract visible.
- Green ≠ costed: **Infracost** and Terratest sit in **S18**, outside the canonical cut.

<p v-click class="mt-8 text-xl font-semibold">If CI is optional, the pyramid is a suggestion.</p>

<div v-click class="mt-5 kw-panel p-3 text-sm">
<strong>Signpost — optional material.</strong> <strong>S18</strong> holds the Terratest and
<strong>Infracost</strong> beats. It is outside the canonical cut, so nothing here claims
cost coverage — read S18 when your risk needs it.
</div>

<!--
Say: The whole Day 2 portfolio only protects the team when every layer has a non-optional job and a truthful badge. Next, Day 3 asks how Terramate orchestrates many stacks without taking over state. (~2 min)
Cross-reference: the signpost is a pointer, not a lesson. S18 · Integration, e2e & cost carries Terratest and the Infracost beat, and S18 is `canonical: false`, so it is not in the three-day cut. Say plainly that this pipeline does not cover cost and that S18 is where to read when a team needs it. Do not demo Infracost here — it needs a free API key.
Then: S20 · Why Terramate.
-->
