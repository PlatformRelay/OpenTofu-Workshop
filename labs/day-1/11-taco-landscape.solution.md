# Lab 11 — Pick a TACO platform, defend the choice (S11) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

### Scenario A — the primary decision

You run infrastructure for a **small platform team**. The mandate:

- **Must run OpenTofu** (the org standardised on it after the licence change).
- **Must self-host** (regulated data; no third-party SaaS may run plans — runs
  must execute inside your own network).
- **Needs policy-as-code** (a compliance rule must block non-conforming plans).
- **Small team** — low appetite for operating heavyweight platform infrastructure.

**Task:** Apply the constraints-first method. Which candidates does each hard
filter eliminate? Of the survivors, which do you pick, and what trade-off did you
accept?

---

<details><summary>Rationale / a defensible answer</summary>

**Hard filters first — eliminate before you score:**

1. *Must run OpenTofu* → **HCP Terraform is out** (Terraform only; this is the
   binary fact). It cannot be rescued by any other strength.
2. *Must self-host (runs execute in-network)* → the test is **where plans run**,
   not where the vendor sits. Spacelift and Atlantis self-host outright; Scalr and
   env0 keep a SaaS control plane but run plans on **self-hosted agents inside your
   network**, so they satisfy "no SaaS may run plans" and survive. A tier that ran
   plans in the vendor's cloud with no in-network agent would be dropped here.

**Survivors:** Spacelift, env0, Scalr, Atlantis. Now score the soft criteria.

- **Atlantis** is the strong pick for *this* scenario: OSS and self-run satisfies
  "must self-host" completely, it drives OpenTofu, and it integrates a
  bring-your-own policy engine (OPA/conftest) to meet policy-as-code. The
  **trade-off you accept** is operating burden — you run and maintain it — but for
  a small team that already wants full control of its own infra, that cost is
  acceptable, and there is no licence bill or vendor lock-in.
- **Spacelift** is the defensible runner-up: it self-hosts (including air-gapped),
  supports OpenTofu, and ships OPA policy out of the box, trading a licence cost
  for far less operating burden than running Atlantis yourself. If the team's
  appetite for ops were even lower, this becomes the better pick.

Either **Atlantis** (optimise for cost/control, accept ops burden) or **Spacelift**
(optimise for low ops, accept a licence bill) is a *defended* answer — because in
each case you can name the trade-off. An **undefended** answer names a platform
with no trade-off stated, or picks HCP Terraform (which the first filter already
eliminated).

</details>

---

### Scenario B — change one constraint

Same team, but the mandate changes: **drop "must self-host"** (leadership now
accepts a trusted SaaS vendor) and **add "minimise operating effort"** (the team is
shrinking and cannot run its own platform).

**Task:** Re-run the method. Does your pick change? Which filter no longer bites,
and which criterion now dominates?

## Expected observations

- **Filters eliminate; they do not down-weight.** A candidate that fails a hard
  filter scores zero overall — you never "make up for it" on another axis. "Must
  run OpenTofu" removes HCP Terraform every time.
- **The pick is a trade-off, not a favourite.** A defended answer always names the
  trade-off it accepted (ops burden vs licence bill; control vs convenience).
- **The same field yields different winners** as the constraints change (Scenario A
  vs B) — proof that there is no context-free "best" platform.
- **The comparison is dated and coarse.** `✓`/`✗` cells are steering aids, not a
  feature audit; re-verify vendor facts before a real decision.

## Cleanup / panic reset

Nothing to clean up — this lab creates no files, no state, and no infrastructure.
Close your notes and move on.

## Stretch (optional)

- **Add a fourth hard filter of your own** (e.g. "must integrate with our existing
  OCI registry", or "must support drift detection on a schedule") and re-run
  Scenario A. Does the shortlist shrink further?
- **Write the one-paragraph decision record** you would attach to the choice: the
  constraints, the survivors, the pick, and the single trade-off accepted. That
  paragraph — not the score — is what a reviewer actually reads.
- **Re-verify one cell.** Pick any platform row and check the vendor's current docs
  for one axis (OpenTofu support, or self-host). Did the coarse cell still hold?
  This is the habit the dated stamp is training.

<details><summary>Rationale / a defensible answer</summary>

Dropping "must self-host" **removes the filter that kept Atlantis attractive** —
self-hosting is no longer required, so the ops burden of running Atlantis yourself
becomes pure downside against the new "minimise operating effort" goal.

The *must-run-OpenTofu* filter still eliminates **HCP Terraform** — that fact does
not change with the mandate.

With operating effort now dominant, a **managed SaaS with first-class OpenTofu**
support wins: **Spacelift, env0, or Scalr** are all defensible. The tie-breaker is
which soft criterion you weight next — e.g. Scalr/env0's self-hosted *agents* let
runs execute inside your network while the control plane stays managed (a
data-locality nicety even without a hard self-host rule), or Spacelift's policy
depth. The **trade-off you now accept** is a licence bill and a SaaS dependency, in
exchange for near-zero platform ops.

The teaching point: **the same field, a different constraint, a different answer.**
Nothing here is a permanent "best platform" — the winner is whichever survives your
filters and scores highest on *your* weighted criteria today. Re-verify the cells
before you commit; this landscape rots fast.

</details>

---

## Expected state / output

- **Filters eliminate; they do not down-weight.** A candidate that fails a hard
  filter scores zero overall — you never "make up for it" on another axis. "Must
  run OpenTofu" removes HCP Terraform every time.
- **The pick is a trade-off, not a favourite.** A defended answer always names the
  trade-off it accepted (ops burden vs licence bill; control vs convenience).
- **The same field yields different winners** as the constraints change (Scenario A
  vs B) — proof that there is no context-free "best" platform.
- **The comparison is dated and coarse.** `✓`/`✗` cells are steering aids, not a
  feature audit; re-verify vendor facts before a real decision.

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

Nothing to clean up — this lab creates no files, no state, and no infrastructure.
Close your notes and move on.

To recover from a dead-end analysis, discard scratch notes and re-read the scenario constraints from the participant lab — no infrastructure reset is required.

```bash
cd ../../..
```

## Stretch solution

### Commands / manifest

(optional)

- **Add a fourth hard filter of your own** (e.g. "must integrate with our existing
  OCI registry", or "must support drift detection on a schedule") and re-run
  Scenario A. Does the shortlist shrink further?
- **Write the one-paragraph decision record** you would attach to the choice: the
  constraints, the survivors, the pick, and the single trade-off accepted. That
  paragraph — not the score — is what a reviewer actually reads.
- **Re-verify one cell.** Pick any platform row and check the vendor's current docs
  for one axis (OpenTofu support, or self-host). Did the coarse cell still hold?
  This is the habit the dated stamp is training.

Re-run the scenario on paper or in a scratch file — no `tofu` commands apply.

### Expected state / output

When the stretch applies cleanly, your shortlist and trade-off paragraph match the rubric and named constraints.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
