# Lab 11 — Pick a TACO platform, defend the choice (S11)

| | |
| --- | --- |
| **Section** | S11 — The TACO landscape *(optional: who runs your IaC, and how you choose them)* |
| **Environment** | `paper ✓` — a decision exercise. **No cloud, no Docker, no `tofu`, no workdir.** Bring a pen or a text file. |
| **Estimated time** | 20 min |

## Objective

This is a **paper lab**: there is nothing to `apply`. Platform choice is a
judgement call, and the skill worth practising is *making it defensibly*. You take
a set of hard constraints, apply the **constraints-first** method from the slides
(hard filters eliminate options, *then* weigh the soft trade-offs), shortlist the
field, pick **one** platform, and justify the pick against a scoring **rubric**.

The landscape you are choosing from (see the S11 comparison table) is dated
`2026-07` on purpose — it is the fastest-rotting slide in the deck. Treat the cells
as coarse (`✓` means "supported", not a feature audit) and **re-verify any vendor
fact before you rely on it in real life**. The one hard, binary fact you may lean
on: **HCP Terraform runs Terraform only — OpenTofu is not supported on it.**

## Prerequisites

- You have seen the S11 slides: the six capabilities a TACO platform adds, the
  comparison axes, and the constraints-first method.
- No tools required. This lab creates no infrastructure, so there is nothing to
  bill, leak, or clean up.

## The candidate field

A coarse, `2026-07`-dated shortlist — the same one from the slide. Re-verify before
you rely on any cell.

| Platform | OpenTofu support | Self-host option | Policy engine | OSS / proprietary |
| --- | --- | --- | --- | --- |
| HCP Terraform | ✗ Terraform only | SaaS (self-host = TF Enterprise) | Sentinel + OPA | Proprietary |
| Spacelift | ✓ | ✓ self-host / air-gap | OPA (Rego) | Proprietary |
| env0 | ✓ | SaaS + self-hosted agents | OPA (Rego) | Proprietary |
| Scalr | ✓ | SaaS + self-hosted agents | OPA (Rego) | Proprietary |
| Atlantis | ✓ | ✓ self-host (you run it) | Bring-your-own (OPA/conftest) | OSS |

## The scoring rubric

Score each *surviving* candidate (the ones that pass the hard filters) out of
**10**. A pick is only "defended" if it scores highest **and** you can name the
trade-off you accepted.

| Criterion | Weight | What full marks looks like |
| --- | --- | --- |
| **Meets hard filters** | Pass/fail | A candidate that fails *any* hard filter scores **0** overall — it is eliminated, not down-weighted. |
| **Policy model fit** | 3 | Policy is portable and open (OPA/Rego), not locked to one vendor's engine. |
| **Operating cost fit** | 3 | The licence-vs-ops trade-off suits the team: OSS/self-run for cost, managed SaaS for low ops. |
| **Team-scale fit** | 2 | Matches the team's size and governance needs (small → simple; regulated → RBAC + audit). |
| **Future-proofing** | 2 | Choice survives a re-verify: no single-vendor lock-in that a fact-rot could strand. |

> **The order is the point.** Apply the hard filters *first* — they shrink the
> field. Only then score the survivors on the weighted criteria. Scoring an
> eliminated candidate is wasted effort.

---

## Scenario A — the primary decision

You run infrastructure for a **small platform team**. The mandate:

- **Must run OpenTofu** (the org standardised on it after the licence change).
- **Must self-host** (regulated data; no third-party SaaS may hold state or run
  plans).
- **Needs policy-as-code** (a compliance rule must block non-conforming plans).
- **Small team** — low appetite for operating heavyweight platform infrastructure.

**Task:** Apply the constraints-first method. Which candidates does each hard
filter eliminate? Of the survivors, which do you pick, and what trade-off did you
accept?

<details><summary>Rationale / a defensible answer</summary>

**Hard filters first — eliminate before you score:**

1. *Must run OpenTofu* → **HCP Terraform is out** (Terraform only; this is the
   binary fact). It cannot be rescued by any other strength.
2. *Must self-host* → drops any SaaS-only path. Spacelift, Scalr, env0 and
   Atlantis all offer a self-hosted or self-run option, so they survive; a
   SaaS-only tier would not.

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

## Scenario B — change one constraint

Same team, but the mandate changes: **drop "must self-host"** (leadership now
accepts a trusted SaaS vendor) and **add "minimise operating effort"** (the team is
shrinking and cannot run its own platform).

**Task:** Re-run the method. Does your pick change? Which filter no longer bites,
and which criterion now dominates?

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
