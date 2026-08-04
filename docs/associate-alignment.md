# Terraform Associate alignment

A **design check** for workshop coverage — not exam prep, not a study guide, and
not a pass guarantee.

HashiCorp publishes **Terraform Associate** objectives that name practitioner
fundamentals (IaC concepts, configuration, workflow, modules, state,
collaboration platforms). This appendix asks one question only: *does this
workshop teach those fundamentals?* Answers map objectives → workshop sections.
Where the syllabus names something we deliberately skip, it is listed as
**consciously out-of-scope** — never silently omitted.

The compact closing table on the S26 deck
([`pages/S26-capstone/index.md`](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/pages/S26-capstone/index.md)) is the
in-room summary. **This file is the canonical appendix.**

### OpenTofu-first note

Learners run **`tofu`**. HCL still uses the top-level `terraform {}` block.
Associate themes below use familiar HashiCorp wording; in the room we say
OpenTofu and point at OpenTofu docs where behaviour diverges (especially state
encryption and Day-3 Terramate — see [Beyond Associate](#beyond-associate)).

---

## Coverage map

| Associate objective (theme) | Sub-themes (design check) | Covered by | Notes |
| --- | --- | --- | --- |
| IaC concepts / purpose | What IaC is; declarative vs imperative; why manage infra as code | **S01** | Fork/licensing beat is OpenTofu context, not an Associate objective. |
| Tool purpose vs alternatives | Provider model; multi-cloud / provider-agnostic benefits; role of state | **S01**, **S02**, **S04** | Framed with OpenTofu + LocalStack, not a vendor bake-off. |
| CLI / product basics & HCL | Install & version; providers & plugin architecture; find/fetch providers; HCL blocks (`resource`, `data`, `variable`, `output`, `provider`, `locals`, `module`); references | **S00**, **S02**, **S03** | S00 is orientation + first apply; S02 owns block literacy. |
| Core workflow | Write → plan → create/destroy; `init` / `plan` / `apply` / `destroy`; read a plan; dependency ordering; idempotency | **S03** | Capstone (**S26**) re-runs the same lifecycle on a multi-module root. |
| CLI outside the core loop | `fmt` / `fmt -check`; `validate`; state inspect / list / show; import; refactor without recreate | **S04**, **S09**, **S13**, **S19** | Verbose logging (`TF_LOG`) is only mentioned in passing — see out-of-scope. |
| Configuration authoring | Variables & outputs; complex types; expressions & functions; cross-resource refs; explicit/implicit deps; `dynamic` / `for_each`; sensitive values | **S02**, **S06**, **S09**, **S15** | S15 adds native conditions/`check` (Associate-adjacent; taught as OpenTofu/Terraform shared HCL). |
| Modules | Sources (local / Git / registry); inputs/outputs & scope; version constraints; compose & reuse | **S07**, **S08** | S08 is the flagship applied module pair (`naming` + `labels`), not registry theory alone. |
| State & backends | Local backend; remote backends; locking; drift; secrets in plaintext state | **S04** | Motivates S05; Associate *state security* themes land here first. |
| Native validation / conditions | Variable `validation`; pre/postconditions; `check` blocks | **S06**, **S15** | Complements, does not replace, CLI `validate`. |
| Testing & static checks | `fmt` / `validate` / TFLint; scanners; native `tofu test`; mocks | **S12**–**S17**, **S19** | Associate names `fmt`/`validate` explicitly; the pyramid and scanners are workshop depth. |
| Automation & collaboration | Remote runs, VCS-driven workflow, policy/governance, workspaces/projects (platform concepts) | **S11**, **S19** | S11 is vendor-neutral TACO landscape (optional in the 3-day cut). HCP Terraform is named only to state the **Terraform-only** constraint for OpenTofu shops. |

---

## Beyond Associate

These beats are **OpenTofu-current** (or workshop scale topics). They deepen
fundamentals or go past the Associate syllabus. Keep them labelled as such in
the room — never as “exam extras.”

| Topic | Where | Why it is beyond |
| --- | --- | --- |
| Client-side **state + plan encryption** (PBKDF2 / KMS / …) | **S05**, reused in **S08** / **S26** | No Terraform equivalent; Associate state-security themes stop at backends, locking, and plaintext risk. |
| OpenTofu differentiators (`-exclude`, provider `for_each`, early eval, ephemeral/write-only, OCI mirrors, …) | **S10** | Framed as OpenTofu-current; recommended tier, often cut in Day-1 fit. |
| Native test framework depth (`tofu test`, `mock_provider`, plan vs apply lanes) | **S16**, **S17** | Associate expects validation/`fmt`; full native test suites are workshop Part 2. |
| Terramate (stacks, codegen, orchestration, `--changed`) | **S20**–**S25**, optional stretch in **S26** | Orchestration layer — not Associate material. |
| Terratest / Infracost tip | **S18** (optional) | External Go lane; not Associate. |
| Capstone synthesis on LocalStack | **S26** | Integration of naming + labels + encryption + tests; the Associate table on that deck is only the short design-check summary. |

---

## Consciously out-of-scope

Associate-oriented themes the workshop **does not** claim to cover. Listed so a
facilitator never has to guess whether a gap is accidental.

| Theme | Why out of scope |
| --- | --- |
| Hands-on **HCP Terraform** (remote backend/`cloud` block, VCS-triggered runs, run UI, projects/workspaces as a daily driver) | OpenTofu-first workshop; HCP Terraform runs Terraform only. S11 explains the filter; S19 teaches portable CI, not HCP operations. |
| **Sentinel** policy authoring | TFC/HCP-only. S14 contrasts it with portable OPA/Conftest and does not teach Sentinel. |
| **Vault**-centric secret injection as a required lab path | Sensitive-value hygiene and passphrase-out-of-band patterns appear (S04–S06, S05); a full Vault integration track does not. |
| **Provisioners** (`local-exec` / `remote-exec`) as a primary pattern | Taught as anti-pattern / last resort if mentioned; not a lab outcome. |
| Deep **workspace** CLI workflows (`tofu workspace` as environment strategy) | Prefer separate roots / stacks (and Terramate on Day 3) over workspace multiplexing. |
| **Verbose logging** mastery (`TF_LOG` / `TF_LOG_PATH` troubleshooting playbook) | Occasional tip only; not a section outcome. |
| Provider **plugin development** / SDK | Consumer-side providers only. |
| Cloud-provider certification knowledge (IAM quirks, service limits, …) | LocalStack/mock labs prove the workflow; provider APIs are not the syllabus. |
| Exam technique, practice tests, or “pass the Associate” coaching | Explicitly excluded by workshop charter. |

---

## How facilitators should use this

1. After the S26 closing table, point curious learners here — not at an exam
   outline.
2. When cutting Day 1 (**S09** / **S10** via fit plan), say which Associate
   themes thin out (meta-args / refactoring; OpenTofu differentiators).
3. When skipping optional **S11**, say the collaboration theme is covered only
   lightly via **S19** CI — HCP hands-on remains out-of-scope either way.

See also the [facilitator runbook](facilitator-runbook.md) (S26 keep-row) and the
[contributor guide](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/AGENT.md).
