# Claims verification — 2026-08-25

Evidence artifact for **US-C-FACTS** (phase 1). Every version, licensing, date
and project-status claim the workshop teaches is listed here with the **primary
source** it was checked against and the **date it was checked**.

**Check date for every row below: 2026-08-25.** Where a row says
`UNVERIFIED`, no primary source was reached in this pass — that is recorded
honestly rather than papered over with a plausible-looking citation.

## How to read this

| Verdict | Meaning |
| --- | --- |
| `VERIFIED` | The deck's wording matches a primary source quoted in the Evidence column. |
| `PARTIAL` | The core of the claim holds; a named part of it is not supported by the source. |
| `INCONSISTENT` | Sourced fine in isolation, but contradicts another assertion inside this repo. |
| `CONTRADICTED` | A primary source says something different. Needs a prose fix. |
| `INCOMPLETE` | True as written, but the source has moved on and the deck omits the newer fact. |
| `UNVERIFIED` | No primary source reachable or checked in this pass. Do not cite it as sourced. |

**Primary source** here means the project's own repository, changelog, release
metadata, licence text, or docs site — never a blog post, never recollection,
never this repo's own existing prose. GitHub facts were read through the GitHub
REST API (`gh api`) rather than scraped HTML, so dates and flags are exact.

## What gates do and do not say about this file

No gate reads this table's *content*, so a green run is not delivery evidence
here — the citations are. What the gates do establish, each by being run rather
than assumed:

- **`mkdocs build --strict` passes with this file present, and no `nav` entry is
  required.** MkDocs reports an omitted-from-nav page at INFO, not WARNING, so
  `strict: true` does not trip on it; four pages (`beta-limitations.md`,
  `rehearsal-checklist.md`, `timing-results-template.md`,
  `validation-matrix.md`) are already nav-omitted. Checked by building the
  pinned stack from `docs/requirements-docs.txt` in a throwaway venv — the
  `mkdocs` on PATH lacks `mkdocs-material` and fails at config-parse time, which
  is a tooling artefact, not a defect in this file.
- **`pnpm link-check` covers `docs/**` and passes** — but only from a clean
  checkout. In a dirty tree it exits 1 with ~200 failures, every one of them
  inside `.terraform/` provider trees vendored by a previous `verify.sh` run and
  none touching this file. That is exactly why the gate matrix runs
  `git clean -Xfd labs` first; a red here is almost always that, not a diff.
- **`markdownlint-cli2` does NOT lint this file in CI** — its globs are
  `labs/**` only. It was run against this path by hand instead (0 errors). Worth
  knowing before trusting a green markdownlint as cover for `docs/**`.

## Scope

The plan's §5 lists 13 stale-risky claims. Several of those are compound (one
row covering four separate assertions), so they are decomposed below into
atomic, individually checkable claims. Rows are grouped by the plan's numbering
where it maps cleanly.

**Counts.** Sections A–I hold **62 rows**, but three of them are *reference*
rows rather than claims the deck makes — each is annotated as such in place:

- **E7** is a gate-behaviour check (is the S14 slide block drift-armed?).
- **A10** records the 1.11.x support window, "*(not asserted in the deck)*".
- **G5** records that `tofuenv`/`tfenv` are superseded but not archived,
  "*(deck does not claim archived — recorded for accuracy)*".

That leaves **59 atomic deck claims**:

- **57** are `VERIFIED` (in any of its qualified forms) / `PARTIAL` /
  `INCONSISTENT` / `CONTRADICTED` / `INCOMPLETE` — i.e. a primary source was
  actually reached and quoted.
- **2** are `UNVERIFIED` outright: **F9** (Snyk IaC status) and **G8** (Terramate
  CLI surface).

One further item appears in §J that is **not** a 63rd row: **U2** is a named
sub-claim living inside the otherwise-verified **D3**. The `LOCALSTACK_VERSION`
release's existence and date were confirmed; the behavioural *rationale* in its
comment was not. It is listed separately so it is not silently carried by D3's
verdict — but it must not be double-counted.

So: **57 verified, 2 unverified, plus 1 unverified sub-claim inside a verified
row.** §J lists all three unverified items together so silence is never mistaken
for confirmation.

## A. OpenTofu release timeline and support window (plan §5 #1)

| # | Claim | Where | Verdict | Evidence (primary source, checked 2026-08-25) |
| --- | --- | --- | --- | --- |
| A1 | Current baseline is OpenTofu **1.12.x** | `pages/S10-opentofu-differentiators/index.md:65` | VERIFIED | GitHub API `repos/opentofu/opentofu/releases` — latest stable tag `v1.12.6`, published `2026-08-19T11:40:07Z`. |
| A2 | 1.12.x is "supported to 2027-02-01" | `pages/S10-opentofu-differentiators/index.md:65` | VERIFIED | `CHANGELOG.md` at tag `v1.12.0`, first line: "The v1.12.x release series is supported until **February 1 2027**." |
| A3 | **1.7** = client-side state **& plan** encryption · provider-defined functions · `removed` block | `pages/S10-.../index.md:55` | VERIFIED | `CHANGELOG.md` @ `v1.7.0`: "Add support for a `removed` block…"; "Provider-defined functions are now available." For encryption the changelog header reads "STATE ENCRYPTION — We're introducing optional end-to-end encryption for **state files**" and never says *plan*, which initially looked like the deck overclaiming. It is not. The **v1.7-versioned** docs settle it: `website/docs/language/state/encryption.mdx` at tag `v1.7.0` is titled "# State and Plan Encryption" and opens "OpenTofu supports encrypting **state and plan files** at rest, both for local storage and when using a backend." The changelog header is simply loose. (Method note: the *current* docs page carries the same sentence but is versioned v1.12.x, so it cannot adjudicate a 1.7 claim — the tagged docs source can, and does.) |
| A4 | **1.8** = early variable/backend evaluation · `.tofu` extension · test mocking & overrides | `pages/S10-.../index.md:56` | VERIFIED | `CHANGELOG.md` @ `v1.8.0` NEW FEATURES: "Variables and Locals allowed in module sources and backend configurations (with limitations)"; "Added support to new .tofu extensions"; "Added support for `override_resource`, `override_data` and `override_module` blocks"; "Added support for `mock_provider`, `mock_resource` and `mock_data` blocks". Release published `2024-07-29T13:04:14Z`. |
| A5 | **1.9** = provider `for_each` · `-exclude` · cross-referencing variable validation | `pages/S10-.../index.md:57` | VERIFIED | `CHANGELOG.md` @ `v1.9.0`: "**`for_each` in provider configuration blocks**"; "**`-exclude` planning option**"; "References to vars, data, etc. are now usable in variable validation". Published `2025-01-09T16:20:29Z`. |
| A6 | **1.10** = OCI registry for providers *and* modules · external key providers · native S3 state locking | `pages/S10-.../index.md:58` | VERIFIED | `CHANGELOG.md` @ `v1.10.0`: "install **module packages from OCI Registries**"; "**OCI Registries as a new kind of provider mirror**"; "**The `s3` backend can now implement locking without DynamoDB**"; "State encryption now supports using external programs as key providers." Published `2025-06-24T13:58:50Z`. |
| A7 | **1.11** = ephemeral resources & write-only attributes · `enabled` meta-arg | `pages/S10-.../index.md:59` | VERIFIED | `CHANGELOG.md` @ `v1.11.0`: "**Ephemeral values**… ephemeral resource types… managed resource types with write-only attributes"; "The new **`enabled` meta-argument**". Published `2025-12-09T18:52:00Z`. |
| A8 | **1.12** = dynamic `prevent_destroy` · `destroy = false` · concurrent provider install | `pages/S10-.../index.md:60` | VERIFIED | `CHANGELOG.md` @ `v1.12.0`: "A `prevent_destroy` argument… can now refer to other symbols in the same module"; "New `lifecycle` meta-argument `destroy`: when set to `false`…"; "Provider installation now makes concurrent requests to download provider packages". |
| A9 | The 1.7→1.12 span is a genuine divergence window — "several **with no Terraform equivalent**"; provider `for_each` is "**OpenTofu-only** since 1.9" | `pages/S10-.../index.md:39-40, 147, 291, 303` | VERIFIED | Two halves, checked separately. (a) Every feature listed in A3–A8 appears in OpenTofu's own changelog at the version claimed. (b) The *exclusivity* half was checked against **HashiCorp's** docs, not inferred: provider `for_each` — `https://developer.hashicorp.com/terraform/language/providers/configuration` documents only aliasing ("include multiple `provider` blocks with the same provider name, then add the `alias` argument…") and never mentions `for_each` on a provider block; `-exclude` — `https://developer.hashicorp.com/terraform/cli/commands/plan` documents `-target=ADDRESS` as its only resource-targeting option, with no `-exclude`; client-side state encryption — `https://developer.hashicorp.com/terraform/language/state/sensitive-data` states "You can encrypt your state at rest, but the encryption method depends on your specific backend", i.e. delegated to S3/GCS/HCP rather than a native `encryption` block with key providers. All three OpenTofu features named as differentiators are genuinely absent from Terraform. |
| A10 | 1.11.x support window | *(not asserted in the deck)* | VERIFIED | `CHANGELOG.md` @ `v1.11.0` first line: "The v1.11.x release series is supported until **August 1 2026**." → **1.11.x is out of support as of this check date.** Relevant because `versions.env` pins an even older series (see D1). |

## B. Licensing, fork and governance (plan §5 #3, #4)

| # | Claim | Where | Verdict | Evidence (primary source, checked 2026-08-25) |
| --- | --- | --- | --- | --- |
| B1 | 2023-08-10 — HashiCorp relicenses Terraform MPL 2.0 → BUSL 1.1 | `pages/S01-iac/index.md:310-311, 332, 490` | VERIFIED | HashiCorp's own announcement, `https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license`, dated **Aug 10, 2023**: "HashiCorp is changing its source code license from Mozilla Public License v2.0 (MPL 2.0) to the Business Source License (BSL, also known as BUSL) v1.1 on all future releases of HashiCorp products." |
| B2 | Terraform today is BUSL 1.1, source-available | `pages/S01-iac/index.md:347, 366, 491` | VERIFIED | `repos/hashicorp/terraform` `LICENSE` (GitHub API): "Business Source License 1.1"; `Licensed Work: Terraform Version 1.6.0 or later`; `Change License: MPL 2.0`; `Change Date: Four years from the date the Licensed Work is published.` GitHub classifies the licence as `NOASSERTION` (not an OSI licence). Note the `Licensor` field now reads **International Business Machines Corporation (IBM)** — accurate for *today's* licence text; the deck's "HashiCorp relicenses" wording is correct for the 2023 *event*. |
| B3 | 2023-08-25 — the community forks the last MPL-2.0 release as OpenTofu | `pages/S01-iac/index.md:314-315, 333, 490` | VERIFIED | OpenTofu's own manifesto, `https://opentofu.org/manifesto/`: "With no response from Hashicorp by August 25, we created a fork of Terraform." Same page independently confirms B1: "on August 10th, 2023… HashiCorp switched the license". |
| B4 | 2024-01-10 — OpenTofu 1.6 ships GA | `pages/S01-iac/index.md:318-319, 334, 490` | VERIFIED | GitHub API `repos/opentofu/opentofu/releases/tags/v1.6.0` — `published_at` `2024-01-10T14:13:28Z`; release body: "Time for the big release! OpenTofu 1.6.0 is now stable!" and "This release is a drop-in replacement". |
| B5 | OpenTofu is MPL 2.0 | `pages/S01-iac/index.md:346, 352, 491` | VERIFIED | GitHub API `repos/opentofu/opentofu/license` → `{"name":"Mozilla Public License 2.0","spdx_id":"MPL-2.0"}`. |
| B6 | OpenTofu is governed by the **Linux Foundation** | `pages/S01-iac/index.md:319, 352, 491`; `labs/day-1/01-iac-fork.md:336, 338`; `labs/day-1/01-iac-fork.solution.md:250, 252` | INCOMPLETE | True, and not contradicted by any source checked. But `https://www.cncf.io/projects/opentofu/` states: "OpenTofu was accepted to CNCF on **April 23, 2025** at the **Sandbox** maturity level." CNCF sits under the Linux Foundation, so the deck is not wrong — it is 16 months behind the governance story. |

## C. Native testing and mocking — sourced from OpenTofu, not Terraform (plan §5 #5)

This is the row the plan singles out as the highest-risk carryover: the
reference material dates `terraform test` to **Terraform** v1.6.0, and
OpenTofu's and Terraform's version histories diverged after the licence change.
Both engines' changelogs were read independently.

| # | Claim | Where | Verdict | Evidence (primary source, checked 2026-08-25) |
| --- | --- | --- | --- | --- |
| C1 | "Native testing became generally available with **OpenTofu 1.6**" | `pages/S16-tofu-test/index.md:31, 35` | VERIFIED | OpenTofu `CHANGELOG.md` @ `v1.6.0`, NEW FEATURES: "`tofu test`: The previously experimental `tofu test` command has been moved out of experimental. This comes with a significant change in how OpenTofu tests are written and executed." Release published `2024-01-10T14:13:28Z`. **This is OpenTofu's own changelog, not Terraform's** — the coincidence of both engines landing `test` GA at 1.6 is real, not a carryover. |
| C2 | `mock_provider` / `mock_resource` / `mock_data` are **OpenTofu 1.8** | `pages/S17-mocking/index.md:38, 43, 49, 161` | VERIFIED | OpenTofu `CHANGELOG.md` @ `v1.8.0`: "Added support for `mock_provider`, `mock_resource` and `mock_data` blocks in testing framework. ([#1772](https://github.com/opentofu/opentofu/pull/1772))". Published `2024-07-29T13:04:14Z`. |
| C3 | `override_resource` / `override_data` / `override_module` are **OpenTofu 1.8** | `pages/S17-mocking/index.md:51` | VERIFIED | Same changelog: "Added support for `override_resource`, `override_data` and `override_module` blocks in testing framework. ([#1499](https://github.com/opentofu/opentofu/pull/1499))". |
| C4 | "Terraform shipped comparable override/mocking earlier (**1.7**)" | `pages/S17-mocking/index.md:54` | VERIFIED | Terraform `CHANGELOG.md` @ `v1.7.0`, header "## 1.7.0 (January 17, 2024)", NEW FEATURES: "`terraform test`: Providers, modules, resources, and data sources can now be mocked during executions of `terraform test`… `mock_provider`: Can replace provider instances with mocked providers…". Terraform 1.7.0 (2024-01-17) does predate OpenTofu 1.8.0 (2024-07-29). The deck's attribution is correct in both directions. |
| C5 | "the workshop's floor remains OpenTofu **1.8+**" | `pages/S17-mocking/index.md:55` | VERIFIED | Consistent with C2/C3 — `mock_provider` genuinely requires ≥ 1.8. (But see E2 for the repo-wide floor inconsistency.) |

## D. Toolchain pins (`versions.env`) and lab pins

| # | Claim | Where | Verdict | Evidence (primary source, checked 2026-08-25) |
| --- | --- | --- | --- | --- |
| D1 | `TOFU_VERSION=1.10.3` | `versions.env:13` | VERIFIED (pin exists) / stale | `repos/opentofu/opentofu/releases` — `v1.10.3` published `2025-07-15T14:33:31Z`. It is not the newest 1.10 patch (`v1.10.10`, `2026-05-11`), and 1.10.x predates the 1.11.x series whose stated support ended 2026-08-01 (A10). The pin is a deliberate, reproducible choice, not an error — but it is two series behind what `pages/S10:65` calls "current baseline". |
| D2 | `GO_VERSION=1.23.6` | `versions.env:18` | VERIFIED (pin exists) / **EOL** | `repos/golang/go` git ref `refs/tags/go1.23.6` exists. `https://go.dev/doc/devel/release`: "Each major Go release is supported until there are two newer major releases", latest major listed **Go 1.27.0 (2026-08-19)** → supported series are 1.26 and 1.27. **Go 1.23 receives no security fixes.** Also newer within its own series: `go1.23.12`. |
| D3 | `LOCALSTACK_VERSION=4.9.2` | `versions.env:23` | VERIFIED (pin exists) | `repos/localstack/localstack/releases/tags/v4.9.2` — published `2025-10-06T09:01:27Z`. Latest is `v4.14.0` (`2026-02-26`). The comment's rationale ("last community release that boots without `LOCALSTACK_AUTH_TOKEN`") was **not** re-verified in this pass — see U2. |
| D4 | `TERRAMATE_VERSION=0.17.1` | `versions.env:27` | VERIFIED (pin exists) | `repos/terramate-io/terramate/releases/tags/v0.17.1` — published `2026-05-26T13:24:47Z`. Latest is `v0.17.2` (`2026-07-31`). One patch behind; no correction needed. |
| D5 | Lab pins Trivy **0.72.0** · Checkov **3.3.0** · Conftest **0.68.2** | `labs/day-2/14-security-scanners.md:8` | VERIFIED (pins exist) | `repos/aquasecurity/trivy/releases/tags/v0.72.0` → `2026-06-30`; `repos/bridgecrewio/checkov/releases/tags/3.3.0` → `2026-06-10`; `repos/open-policy-agent/conftest/releases/tags/v0.68.2` → `2026-04-15`. All three exist. Current latest: Trivy `v0.74.0` (`2026-08-14`), Checkov `3.3.13` (`2026-08-20`), Conftest `v0.69.0` (`2026-08-03`). **These three pins live only in lab prose — they are not in `versions.env` and nothing gates them.** |

## E. Version floors and provider constraints (plan §5 #2, #12)

| # | Claim | Where | Verdict | Evidence (primary source, checked 2026-08-25) |
| --- | --- | --- | --- | --- |
| E1 | `required_version = ">= 1.8"` | `labs/day-1/00-setup/versions.tf:2` (and ~20 peer files) | VERIFIED as a floor | Correct minimum for the `mock_provider`/`override_*` content (C2/C3). Note the plan's §5 cites `labs/day-1/00-setup/hello.tf:2`; the `terraform` block actually lives in `labs/day-1/00-setup/versions.tf:2` — `hello.tf` holds only the `local_file` resource. |
| E2 | ">= 1.8" is a *sufficient* floor for the workshop | **Repo-wide.** Deck: `pages/S00-welcome/index.md:218`, `pages/S17-mocking/index.md:55`, `pages/S28-ecosystem-tooling/index.md:88, 99`. Prose: `README.md:68`, `docs/setup.md:33`, `docs/validation-matrix.md:78`, `docs/facilitator-runbook.md:15`, `docs/rehearsal-checklist.md:29, 42`, `labs/day-3/28-ecosystem-tooling.solution.md:35-36`. Tooling: `setup/bootstrap.sh:25` and `scripts/verify.sh:92` (both `1.8`) | INCONSISTENT | `labs/day-1/10-differentiators.md:31` states "`tofu` ≥ 1.9 — provider `for_each` and `-exclude` are 1.9 features", and `labs/day-1/10-differentiators.md:60` sets `required_version = ">= 1.9.0"`. Confirmed against OpenTofu `CHANGELOG.md` @ `v1.9.0` (A5): both features genuinely arrived in 1.9. So "any `tofu ≥ 1.8` runs the labs" is false for Lab 10. |
| E3 | `aws = "~> 6.0"` | `labs/day-1/00-setup/versions.tf:7` | VERIFIED | `repos/hashicorp/terraform-provider-aws/releases/latest` → `v6.61.0` (`2026-08-19`). `~> 6.0` resolves inside the current major. |
| E4 | `local = "~> 2.5"` | `labs/day-1/00-setup/versions.tf:11` | VERIFIED | `repos/hashicorp/terraform-provider-local/releases/latest` → `v2.9.0` (`2026-05-13`). `~> 2.5` (≥2.5, <3.0) is satisfiable and current. |
| E5 | `random = "~> 3.7"` | `labs/day-1/00-setup/versions.tf:15` | VERIFIED | `repos/hashicorp/terraform-provider-random/releases/latest` → `v3.9.0` (`2026-05-13`). `~> 3.7` (≥3.7, <4.0) is satisfiable and current. |
| E6 | The S14 slide fixture pins `aws = "~> 5.0"` | `pages/S14-security-scanners/index.md:242` | INCONSISTENT | One major behind E3. The AWS provider's current major is 6.x, and `labs/day-1/00-setup/versions.tf:7` pins `~> 6.0` an hour earlier in the same workshop. **The repo is not uniformly 6.0, though, and that is deliberate:** `labs/day-1/10-differentiators.md:67` pins `">= 5.0, < 6.0"` with the reason in a comment — "provider v6's waiters are incompatible with LocalStack community (last release 4.9.2). v5 applies clean against :4566." That pin is correct and must not be swept up by any bump (nor by a gate — see §K). S14 is different: its fixture is scan-only, never applied against LocalStack, so no waiter behaviour is in play and the bump is safe — proven, not assumed, at F12. |
| E7 | *(gate check, not a deck claim)* Is the S14 slide's HCL block drift-checked against its fixture? | `pages/S14-.../index.md:235-289` vs `labs/day-2/14-security-scanners/messy/main.tf` | **NOT GATED** | `scripts/verify.sh` §6 only arms on a `<!-- source: PATH -->` comment "IMMEDIATELY followed by an opening ```hcl fence"; an "unannotated block → ignored (only counted/warned)". The fence at `pages/S14-.../index.md:235` has **no such marker** — line 234 is blank and 233 is a heading — so §6 does not read this pair at all. The two are byte-identical today — verified, not assumed: `sed -n '236,288p'` of the slide `diff`s clean against the 53-line fixture, and §6's fence regex explicitly tolerates the magic-move metadata this fence carries in its `{...}` highlight spec. So **adding the one-line marker arms the existing gate for free and passes on the first run.** Note the asymmetry that makes this worth doing: the *lab* copy of the same fixture (`labs/day-2/14-security-scanners.md:60`, marker at `:52`) **is** armed, so a fixture edit that skips the lab reds §6 immediately, while the same edit skipping the *slide* is silent. Two of the three copies are guarded and the learner-facing one is not. Recommended alongside L12. |

## F. Scanner and policy-tool status (plan §5 #6, #7 — "Two load-bearing facts")

| # | Claim | Where | Verdict | Evidence (primary source, checked 2026-08-25) |
| --- | --- | --- | --- | --- |
| F1 | "Aqua merged **tfsec** into Trivy (**2023**)" | `pages/S14-.../index.md:64, 154` | VERIFIED (the 2023 date) | `repos/aquasecurity/tfsec` commit history for `README.md`: "docs: README tfsec to trivy migration callout (#2020)", authored `2023-08-31T15:25:11Z`. The README text itself: "we have been consolidating all of our scanning-related efforts in one place, and that is Trivy… Going forward we want to encourage the tfsec community to transition over to Trivy." |
| F2 | tfsec belongs under the heading "**dead tools · don't adopt ghosts**" | `pages/S14-.../index.md:135, 146, 156, 169, 418` | PARTIAL — overstated | `repos/aquasecurity/tfsec` → `"archived": false`, `pushed_at: 2026-03-25T08:06:52Z`; latest release `v1.28.14` (`2025-05-02`). Its own README says: "tfsec will continue to remain available for the time being, although our engineering attention will be directed at Trivy going forward." **tfsec is superseded and in maintenance, not dead or archived.** The teaching advice ("new material should not teach `tfsec`"; "command today: `trivy config`") is sound and sourced; only the *ghost/dead* framing outruns the evidence — and it is grouped on the same slide as Terrascan, which genuinely *is* archived, which makes the conflation easy to absorb. |
| F3 | "Command today: **`trivy config`**" | `pages/S14-.../index.md:155` | VERIFIED | tfsec README links a "tfsec to Trivy migration guide" and directs users to Trivy for the same Terraform scanning engine; `repos/aquasecurity/trivy` is active (`archived: false`, `pushed_at: 2026-08-21`). |
| F4 | "**Terrascan → archived** — Archived **2025-11-20** (read-only)" | `pages/S14-.../index.md:75, 160, 162` | VERIFIED | `repos/tenable/terrascan` → `"archived": true`, `pushed_at: 2025-11-20T19:37:10Z`. Its `README.md` opens "## ⚠️ Archived / This project is no longer maintained. The repository is archived and no further updates, issues, or pull requests will be accepted." The commit that added it: "Added archival messages (#1740)", `2025-11-20T19:37:08Z`. **The exact date on the slide is correct.** |
| F5 | "Terrascan's last meaningful release trail went cold in **2024**" | `pages/S14-.../index.md:163` | VERIFIED | `repos/tenable/terrascan/releases` — newest is `v1.19.9`, published `2024-09-18T08:02:14Z`. |
| F6 | Trivy pinned at **0.72.0**; Trivy is ALIVE | `pages/S14-.../index.md:60, 265` | VERIFIED | See D5 and F3. Pin exists; project active. |
| F7 | Checkov pinned at **3.3.0**; Checkov is ALIVE; "Prisma Cloud / **Apache-2.0** CLI" | `pages/S14-.../index.md:68-70, 282` | VERIFIED | `repos/bridgecrewio/checkov/license` → `{"spdx_id":"Apache-2.0"}`; repo `archived: false`, `pushed_at: 2026-08-23`; `3.3.0` exists (`2026-06-10`). |
| F8 | KICS is ALIVE (Checkmarx OSS) | `pages/S14-.../index.md:80` | VERIFIED | `repos/Checkmarx/kics` → `archived: false`, `pushed_at: 2026-08-25T08:38:10Z`; latest release `v2.1.21` (`2026-07-30`). |
| F9 | Snyk IaC is ALIVE | `pages/S14-.../index.md:88` | UNVERIFIED | No primary source reached. Snyk IaC is a commercial product with no single canonical repo whose status settles the claim; the CLI repo was not checked in this pass. **Do not cite this as sourced.** |
| F10 | "CNCF **Graduated** OPA; Conftest wraps Rego for config" | `pages/S14-.../index.md:186` | VERIFIED | `https://www.cncf.io/projects/open-policy-agent-opa/`: "Open Policy Agent (OPA) was accepted to CNCF on March 29, 2018, moved to the Incubating maturity level on April 2, 2019, and then moved to the **Graduated** maturity level on January 29, 2021." |
| F11 | "Sentinel — **TFC / HCP Terraform only**" | `pages/S14-.../index.md:195-197` (bullets), `:204-205` (speaker note), `:421` (recap); `docs/associate-alignment.md:69` | CONTRADICTED | HashiCorp's own Sentinel landing page, `https://developer.hashicorp.com/sentinel`, names three products: "Use **HCP Terraform** with Sentinel to check that infrastructure will comply with policies"; "Use **Vault** with Sentinel to control who can access secrets based on their role or the endpoint"; "Use **Nomad** with Sentinel to control jobs based on driver or other attributes of the job object." Self-hosted Terraform Enterprise also carries it: `https://developer.hashicorp.com/terraform/enterprise/policy-enforcement/define-policies/custom-sentinel` resolves to a live page under HashiCorp's *Terraform Enterprise* docs tree, and the fetch returned the sentence "This topic describes how to create and manage custom policies using Sentinel policy language" from within it. The URL path is the load-bearing part of that citation; the quoted sentence is a supporting line from the page body, not its opening claim. The *teaching point* survives — Sentinel is not a portable OpenTofu-first default — but "TFC / HCP Terraform only" is factually wrong. |
| F12 | The captured scanner output on the slide (`Failures: 7 (HIGH: 6, CRITICAL: 1)`, `AWS-0086/0104/0107/0132`; `Passed 5, Failed 7`, `CKV_AWS_23/24/53-56/382`) | `pages/S14-.../index.md:265-282`; `labs/day-2/14-security-scanners.md:131, 185` | VERIFIED — **reproduced** | Confirming a *version* exists says nothing about the *output* it emits, so this was executed rather than inferred. Trivy reported `Version: 0.72.0` and Checkov `3.3.0` — the exact pins — so the lab's documented commands were run verbatim against `labs/day-2/14-security-scanners/messy/`. `trivy config --severity HIGH,CRITICAL --format table --exit-code 1 .` → `Tests: 7 (SUCCESSES: 0, FAILURES: 7)` / `Failures: 7 (HIGH: 6, CRITICAL: 1)` and exactly `AWS-0086, 0087, 0091, 0093 (HIGH)`, `AWS-0104 (CRITICAL)`, `AWS-0107, 0132 (HIGH)`. `checkov -d . --framework terraform --compact --quiet` → `Passed checks: 5, Failed checks: 7, Skipped checks: 0` and exactly `CKV_AWS_53, 54, 55, 56, 24, 23, 382`. **Every count, severity and rule ID on the slide and in the lab spoiler matches byte-for-byte.** |
| F13 | "**Facts verified 2026-07**" stamp on the field table | `pages/S14-.../index.md:44` | INCONSISTENT | The stamp is now this table's job. Every maintenance-status row above was re-checked on **2026-08-25**; the stamp still says 2026-07 and is the only staleness signal a facilitator sees. |

## G. Ecosystem tooling currency (plan §5 #9, #10, #11)

| # | Claim | Where | Verdict | Evidence (primary source, checked 2026-08-25) |
| --- | --- | --- | --- | --- |
| G1 | "**tenv** — successor to `tfenv`/`tofuenv`" | `pages/S28-.../index.md:85, 95-96, 265` | VERIFIED | `tofuenv`'s **own** README, `repos/tofuutils/tofuenv` `README.md`, "### Important Notice": "we are finally ready to announce a successor for **tfenv** and **tofuenv**: tenv 🚀 written in Golang. tenv is able to handle Terraform binaries as well as OpenTofu binaries." That is the superseded project itself saying so — the strongest available source. Corroborating: `repos/tofuutils/tofuenv/releases` newest is `v1.0.7` (`2025-04-08`) vs `repos/tofuutils/tenv/releases/latest` `v4.15.1` (`2026-07-24`, repo `pushed_at 2026-08-20`). |
| G2 | tenv is "actively maintained" | `pages/S28-.../index.md:95` | VERIFIED | `repos/tofuutils/tenv` → `archived: false`, `pushed_at: 2026-08-20T09:46:49Z`; release `v4.15.1` one month old at check date. |
| G3 | tenv "manages **OpenTofu, Terraform, Terragrunt, Atmos**" | `pages/S28-.../index.md:85-86, 96-97`; `labs/day-3/28-ecosystem-tooling.md:86-87`; `labs/day-3/28-ecosystem-tooling.solution.md:26-27` | INCOMPLETE | `repos/tofuutils/tenv` `README.md` line 19 reads: "OpenTofu, Terraform, Terragrunt, **Terramate** and Atmos version manager, written in Go." (The GitHub `description` field carries the same tool list in a different form — "OpenTofu / Terraform / Terragrunt / Terramate and Atmos version manager", slash-separated, no "written in Go" — so the quoted sentence is attributed to the README alone.) The README's tool table lists `tofu`, `tf`, `tg` (terragrunt), `tm` (terramate), `at` (atmos). **Terramate is missing from the deck's list — and this workshop spends all of Day 3 on Terramate**, so the omission drops the one entry the audience would most care about. |
| G4 | `tenv tofu install/use <version>` and `.opentofu-version` files | `pages/S28-.../index.md:80-81, 87` | VERIFIED | tenv `README.md`: tool table maps `tofu` → OpenTofu; `use` flag documented as "`-w, --working-dir` create `.opentofu-version` file in working directory"; env-var section references "`.opentofu-version` files". |
| G5 | `tofuenv`/`tfenv` are superseded but **not** archived | *(deck does not claim archived — recorded for accuracy)* | VERIFIED | `repos/tofuutils/tofuenv` → `archived: false`, `pushed_at: 2026-02-10`; `repos/tfutils/tfenv` → `archived: false`, `pushed_at: 2026-07-01`. The deck's "successor to" wording is correctly weaker than "archived" — no change needed. |
| G6 | Terragrunt: "**Unit** = a directory with `terragrunt.hcl`"; DRY via `remote_state`/`generate`; order via `dependency`; `run --all` (formerly `run-all`) | `pages/S27-terragrunt-comparison/index.md:61-68` | VERIFIED | `https://docs.terragrunt.com/reference/hcl/blocks/` documents `terragrunt.hcl` as the primary configuration file and states "The `remote_state` block is used to configure how Terragrunt will set up the remote state configuration of your OpenTofu/Terraform code" — **not deprecated**. Repo `gruntwork-io/terragrunt` is active (`archived: false`, `pushed_at: 2026-08-24`). |
| G7 | Terragrunt positioning is current | `pages/S27-.../index.md` (whole section) | INCOMPLETE | `repos/gruntwork-io/terragrunt/releases/tags/v1.0.0` — **Terragrunt reached v1.0.0 on 2026-03-30**; latest is `v1.1.3` (`2026-08-13`). The v1.0.0 release body: "Terragrunt is now v1! This means that Terragrunt will no longer have any breaking changes in minor releases". The same docs page documents `terragrunt.stack.hcl` — "Used for defining stacks of deployment units" — which is Terragrunt's answer to the very stacks-vs-units framing S27 builds its comparison on. Nothing in S27 is *wrong*; it is describing pre-1.0 Terragrunt and misses the stability guarantee and the stacks feature. |
| G8 | Terramate CLI surface (commands and flags taught in S21–S25) | `pages/S21-stacks` … `pages/S25-terramate-ci` | UNVERIFIED | Only the *version* was checked (D4). Verifying the taught command surface means reading Terramate's CLI reference per command — not attempted in this pass. **Do not cite S21–S25's CLI claims as sourced.** |

## H. Cost tooling (plan §5 #8)

| # | Claim | Where | Verdict | Evidence (primary source, checked 2026-08-25) |
| --- | --- | --- | --- | --- |
| H1 | Infracost "needs a **free API key** for live runs" | `pages/S18-integration-cost/index.md:122, 179` | PARTIAL | `https://www.infracost.io/docs/` states that `infracost setup` "walks you through getting a **free API key**, installing the right IDE extension, registering AI agent skills, and wiring up CI/CD." The *free* half is verbatim from Infracost's own docs. The *required* half is not stated in those words on the page fetched — the docs present the key as the onboarding path, not as an explicitly mandatory precondition. |
| H2 | Free tier terms | `pages/S18-.../index.md:196` ("core lab needs no API key") | VERIFIED (the tier) | `https://www.infracost.io/pricing/` free tier: "Cost estimations for Terraform, CloudFormation, and CDK", "Integrates with GitHub, GitLab, Azure DevOps", "1000 free runs per month, Slack Community support." The deck's design decision (keep Infracost an opt-in stretch so no learner must sign up) is unaffected and remains sound. |

## I. New S01 content — design principles and alternatives (plan §5 #13)

The plan flags this as brand-new prose that must be sourced rather than
paraphrased from a Terraform-era deck. The slide already carries inline source
URLs in its speaker notes; each was independently re-fetched here.

| # | Claim | Where | Verdict | Evidence (primary source, checked 2026-08-25) |
| --- | --- | --- | --- | --- |
| I1 | Six design principles: declarative config · execution plan · resource graph w/ parallelism · state as source of truth · immutability · modules | `pages/S01-iac/index.md:~230-262, 289` | VERIFIED | `https://opentofu.org/docs/intro/`, all six present verbatim: "OpenTofu configuration files are declarative, meaning that they describe the end state"; "OpenTofu creates an execution plan describing the infrastructure it will create, update, or destroy"; "OpenTofu builds a resource graph to determine resource dependencies and creates or modifies non-dependent resources in parallel"; "state file, which acts as a source of truth for your environment"; "OpenTofu takes an immutable approach to infrastructure"; "OpenTofu supports reusable configuration components called modules". |
| I2 | Pulumi: "IaC in a general-purpose language… TypeScript/JavaScript, Python, Go, .NET, Java and YAML" | `pages/S01-iac/index.md:381-388, 435` | VERIFIED | `https://www.pulumi.com/docs/iac/concepts/`: "Pulumi is a modern infrastructure as code platform." Languages listed: TypeScript & JavaScript (Node.js), Python, Go, C#/VB/F# (.NET), Java, Pulumi YAML. The deck's list matches. |
| I3 | Crossplane: "a control plane framework… extends Kubernetes… deploy an app, create a load balancer, create a repository" | `pages/S01-iac/index.md:389-397, 437` | VERIFIED | `https://docs.crossplane.io/latest/whats-crossplane/`: "Crossplane is a control plane framework for platform engineering."; "Crossplane extends Kubernetes."; "It could deploy an app, create a load balancer, or create a GitHub repository." |
| I4 | Ansible: agentless; "a playbook changes nothing once the system already matches it" | `pages/S01-iac/index.md:398-406, 440-442` | PARTIAL | `https://docs.ansible.com/ansible/latest/getting_started/introduction.html` returns the idempotence sentence verbatim: "When the system is in the state your playbook describes, Ansible does not change anything, even if the playbook runs multiple times." The *agentless* claim came back as a paraphrase ("Low maintenance overhead by avoiding the installation of additional software across IT infrastructure") rather than the literal word — accurate in substance, but the literal adjective was not quoted back by the fetch, so it is recorded as partial rather than asserted. |
| I5 | CloudFormation: "model and set up your AWS resources" | `pages/S01-iac/index.md:409-413, 443-444` | VERIFIED | `https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html`: "CloudFormation is a service that helps you **model and set up your AWS resources** so that you can spend less time managing those resources…" |
| I6 | "There are deliberately no version numbers, licence names, or foundation-status claims on this slide" | `pages/S01-iac/index.md:~447` (facilitator note) | VERIFIED | Read against the slide body — correct. This is good practice and is why the alternatives slide needed no corrections; contrast the failure modes in F and G, which are all dated or status assertions. |

## J. Unverified — the honest list

Three claims could not be sourced in this pass. They are named here so nobody
mistakes silence for confirmation.

(A fourth — S14's captured scanner output — *was* originally on this list. Trivy
0.72.0 and Checkov 3.3.0 turned out to be installed in the verification
environment, so it was executed instead of assumed and is now VERIFIED at F12.)

| # | Claim | Why unverified | What would settle it |
| --- | --- | --- | --- |
| U1 (F9) | Snyk IaC is "ALIVE" | No canonical primary repo checked; Snyk IaC is a commercial product whose status is not readable from a single repo flag. | Check `snyk/cli` release cadence plus Snyk's own IaC product-lifecycle page. |
| U2 (D3) | LocalStack 4.9.2 is "the last community release that boots without `LOCALSTACK_AUTH_TOKEN`" | Only the release's existence and date were confirmed; the *rationale* is a behavioural claim about newer images. | Boot 4.10+ community without a token in the integration lane and record the result. |
| U3 (G8) | Terramate CLI surface taught across S21–S25 | Out of this pass's budget — needs a per-command read of Terramate's CLI reference against every command the five sections teach. | A dedicated pass over `terramate.io/docs` CLI reference vs the S21–S25 command inventory. |

## K. Should an automated prose check be built?

`scripts/verify.sh` §10 (header at `:646`) enforces that **consumers** of `versions.env`
(CI workflow literals, `setup/terratest/Dockerfile`, `setup/bootstrap.sh`,
`docker-compose.yml`) do not drift from the pin file. Nothing gates prose claims
under `pages/**`. That asymmetry is deliberate and recorded — the question is
whether it should stay.

**Recommendation: yes, but only for a narrow mechanical subset. Three checks,
not a general fact-checker.**

### First, a gate that does not do what its output says

`scripts/verify.sh` §9 ("Day-2/3 optional tool lanes") prints, on every green
run:

```text
· trivy available — S14 security scanning checks run when their content is authored
· checkov available — S14 security scanning checks run when their content is authored
· conftest available — S14 policy checks checks run when their content is authored
```

Reading §9's body, the loop runs `trivy --version`, `checkov --version`,
`conftest --version` and emits `info` on non-empty output. **That is the whole
check.** No S14 content is scanned, no pinned version is compared against the
lab's documented pin (`labs/day-2/14-security-scanners.md:8`), and the promised
"checks run when their content is authored" never materialise — the content *is*
authored.

To be precise about what §9 costs: it does **not** inflate the 139-check total.
Only `pass()` increments the counter (`scripts/verify.sh:45`), and §9 emits
`info`/`warn` exclusively — so it contributes *output lines*, not *checks*. The
defect is therefore purely one of misleading output: three lines that read as
S14 scanner coverage on every green run, backed by nothing.

This matters for the recommendation below, not as a complaint: the tool-detection
scaffolding (`have`, graceful skip on a Day-1-only machine) is already built and
already green. A real check can be hung off it cheaply.

**Build check 1 — pin↔prose agreement.** Assert that when a `pages/**` or
`labs/**` file states a version for a tool that `versions.env` pins, the two
agree; and that the workshop's stated `required_version` floor is not
contradicted by any lab that demands a higher one. This is deterministic,
offline, and needs no network — it is the same shape as the §10 check already
in `verify.sh`, pointed at a different file set.

The justification is empirical, not theoretical — but the honest yield is
**one solid catch and one arguable one**, not three. Scoring the check against
this pass's own findings, strictly as specified above:

- **E2 — caught.** `pages/S28:88` and `setup/bootstrap.sh:25` say "≥ 1.8 runs the
  labs" while `labs/day-1/10-differentiators.md:60` requires `>= 1.9.0`. This is
  squarely the floor half of the check, and it is the defect with real learner
  cost: follow the setup docs on 1.8 and Lab 10 hard-fails.
- **D1 vs A1 — arguable.** `pages/S10:65` calls 1.12.x the "current baseline"
  while `versions.env` pins `TOFU_VERSION=1.10.3` and `pages/S28:69,80,265`
  quotes `1.10.3` verbatim. The check would flag the disagreement, but the
  correct fix (L1) is a *clarifying clause*, not making the strings agree — so a
  strict equality gate would nag at prose that is defensible as written.
- **E6 — NOT caught, and worth dwelling on.** `pages/S14:242` pins `aws ~> 5.0`
  against Day 1's `~> 6.0`, but `aws` is not in `versions.env`, so the check as
  scoped never sees it. The tempting fix — extend check 1 to *all* provider
  constraints — must be resisted: `labs/day-1/10-differentiators.md:67`
  deliberately pins `">= 5.0, < 6.0"` with the reason in a comment ("provider
  v6's waiters are incompatible with LocalStack community"). A whole-repo
  provider-version gate would red on a correct, deliberate, documented pin. That
  is exactly the false-positive class this section argues against elsewhere, and
  it would arrive by way of a well-intentioned scope creep.

None of this needs a network call — these are cross-file string disagreements
inside the repo, which is what a gate is good at. But the scope boundary is the
design, not an afterthought: **`versions.env`-pinned tools plus the
`required_version` floor, and nothing wider.**

**Build check 2 — stamp staleness.** `pages/S14:44` carries "Facts verified
2026-07". Make that stamp a first-class, machine-readable, *required* marker on
every slide asserting maintenance or project status, and fail the build when any
stamp is older than N months (6 is a reasonable first setting for a workshop
whose release cadence is measured in weeks). This converts an easily-ignored
decoration into an expiry date, and — importantly — it fails **loudly and on
schedule** rather than silently going stale between audits.

**Build check 3 — scanner-output regression, hung off §9.** When `trivy` and
`checkov` are present *and* report the versions the lab pins, run the lab's own
documented commands against `labs/day-2/14-security-scanners/messy/` and assert
the failure counts and rule IDs match the captured output in
`pages/S14-.../index.md` and `labs/day-2/14-security-scanners.md`. Skip
(don't fail) when the tools are absent or off-pin — exactly the pattern §9
already implements.

This one is not speculative: **F12 was verified this way during this pass**, and
it took two commands. Both scanners are installed at the pinned versions, both
reproduced the documented output byte-for-byte, and re-running them against a
`~> 6.0` variant of the fixture produced identical findings — which is how L12
was cleared as safe to apply without a re-capture. The check is deterministic
(no network: Trivy's misconfig rules are compiled in), it is offline, and it
guards the single most learner-visible class of claim in the deck: output a
learner will diff against their own terminal. If it ever reds, that is rule
churn on a version bump — precisely the event the slide's own speaker note warns
about ("counts will drift as rule packs update") and currently has no way to
detect.

**Do NOT build: a live project-status checker.** Resolving "is Terrascan
archived", "is tfsec dead", "is OPA graduated", or "what does Infracost's free
tier include" requires network calls to GitHub, CNCF and vendor sites. That gate
would be non-deterministic, rate-limited, and red on any offline or air-gapped
run — and the repo's own `scripts/link-check.mjs` already establishes the
correct precedent here, in its header comment: external links are "reported for
information only and never fail the check — liveness is flaky (rate limits) and
must not gate CI." A status checker would violate that principle for facts that
change on a scale of months, not minutes. Check 2 is the right substitute: it
does not ask *whether* a fact is still true, it asks *whether anyone has looked
recently* — which a gate can answer offline and deterministically.

**Cost/benefit.** Check 1 is roughly the size of the existing §10 block and
reuses its parsing. Check 2 is a regex plus a date comparison. Check 3 is two
subprocess calls and a grep, hung off scaffolding §9 already has. Together they
would have caught the `>= 1.8` floor defect — which, after the repo-wide sweep,
turns out to span **eleven** locations (L15–L18, L20–L26), making it by far the
most widely-mirrored defect in the repo. Add one more it would flag without
prescribing the right fix (L1). Against a 31-row correction list that is still
**1 defect class solidly, 2 at the most generous reading** — not the "three" an
earlier draft of this section claimed — but the *blast radius* of that one class
is eleven files, which strengthens the case for check 1 considerably. Check 3 additionally *locks in* the F12
result that took this pass a manual run to establish, and the E7 marker arms an
already-built gate over the S14 slide.

That is a modest yield, and stating it accurately is the point: a document whose
job is accuracy cannot inflate its own business case. The checks are still worth
building — E2 is a real learner-facing failure, and checks 2 and 3 guard against
*future* drift rather than past defects, which is where their value actually
sits.

The remaining twenty-odd corrections are semantic (F11's "Sentinel TFC-only", F2's
"dead tools" framing, G3's missing Terramate, G7's pre-1.0 Terragrunt framing,
B6's CNCF gap) and are only reachable by a human reading a primary source. That
is the honest ceiling of automation here, and it is worth being explicit about
it rather than implying a gate could make this table unnecessary.

Also cheap and worth doing at the same time: add the one-line
`<!-- source: … -->` marker at `pages/S14-.../index.md:235` (E7), which arms an
*already-built* gate over the slide/fixture pair and passes today.

**What a green gate would and would not mean.** None of the three checks
verifies that a claim is *true* of the outside world. Check 1 verifies the repo
does not contradict itself; check 2 verifies someone re-read a source recently;
check 3 verifies the deck's captured output still matches the pinned tools.
**This table remains the delivery evidence for factual accuracy; a gate can only
ever be a regression alarm around it.** §9 above is the cautionary example — an
`info` line that reads like coverage and delivers none.

## L. Correction list — for the follow-up prose lane

Phase 1 does not apply these. Each row gives file, line, current text, corrected
text, and the row above that carries the citation.

**Completeness by construction, and the boundary is the REPO — not `pages/**`.**
Phase 2 executes this list literally and blind, so a claim that appears in six
places and gets one row ships five-sixths of the defect. Two things are asserted:

1. Every row in sections A–I whose verdict is not plain `VERIFIED` was walked,
   and **every location named in its Where cell** has either an L row or an
   entry in "Locations deliberately left alone" below.
2. Every contested claim *family* was then re-grepped across **the whole repo** —
   `README.md`, `docs/*.md`, `labs/**` prose and solutions, and `pages/**` — not
   just the deck.

Step 2 is the one that had been missing. An earlier revision of this document
swept `pages/**` only, which cannot satisfy a remit that says "every claim the
workshop teaches": the repo's front door is `README.md`, and a learner reads it
before opening any deck. Widening the boundary found **twelve** further
locations (L20–L31), including `README.md:68` — arguably higher-value than
anything in the deck, because `labs/day-1/10-differentiators/` is a Day-1 lab
requiring `>= 1.9.0`, which makes that line false by this document's own
evidence — and `docs/validation-matrix.md:78`, which is Lab 10's *own* row
claiming ≥1.8 while the lab it indexes demands 1.9.

**Every `Current` cell is machine-checked, by a script that reads this table.**
`scripts/claims-check.mjs` parses the rows below, extracts each code span, and
asserts it appears within the named line range. Run it with
`node scripts/claims-check.mjs`; it exits non-zero on any stale pointer.

Phase 2 **must** re-run it before editing and again after, because line numbers
drift as soon as any earlier correction lands.

The script deliberately parses this table rather than carrying its own copy of
the expected strings. That is not a stylistic choice — an earlier hand-written
version of this check reported "23 OK" while row L5 was wrong, because the two
lists had drifted apart and the check was no longer testing what the document
claimed. Re-deriving from the table makes that class of false green impossible.
Running it also surfaced two rows (L4, L15) whose `\``-escaped code spans do not
render as intended in CommonMark, and confirmed L5's quote spans lines 134–135
rather than sitting on 135 alone.

| # | File | Line | Current | Corrected | Source |
| --- | --- | --- | --- | --- | --- |
| L1 | `pages/S10-opentofu-differentiators/index.md` | 65 | `Current baseline: **OpenTofu 1.12.x** (supported to 2027-02-01).` | `Current baseline: **OpenTofu 1.12.x** (supported to 2027-02-01) — the workshop toolchain pins **1.10.3** (\`versions.env\`) for reproducibility.` | A1, A2, D1 |
| L2 | `pages/S14-security-scanners/index.md` | 44 | `Facts verified 2026-07 — re-check maintenance status before you ship a standard.` | `Facts verified 2026-08-25 — re-check maintenance status before you ship a standard.` | F13, this table |
| L3 | `pages/S14-security-scanners/index.md` | 146 | `<span class="kw-kicker">dead tools · don't adopt ghosts</span>` | `<span class="kw-kicker">superseded &amp; archived · don't adopt either</span>` | F2, F4 |
| L4 | `pages/S14-security-scanners/index.md` | 156 | ``- New material should not teach `tfsec` `` | ``- Still published (v1.28.14, 2025-05-02) but superseded — new material should not teach `tfsec` `` | F2 |
| L5 | `pages/S14-security-scanners/index.md` | 134-135 | speaker note; the quote spans two lines — line 134 ends ``— teach`` and line 135 begins `` `trivy config`, not a dead binary. `` | ``teach `trivy config`, not the superseded binary.`` | F2 |
| L6 | `pages/S14-security-scanners/index.md` | 169 | `Say: Say these two facts slowly — they are the workshop's "don't teach the dead` (note wraps; `tool" pair.` is on line 170) | `Say: Say these two facts slowly — they are the workshop's "don't teach the superseded or archived` / `tool" pair.` | F2 |
| L7 | `pages/S14-security-scanners/index.md` | 418 | `- **tfsec → Trivy**; **Terrascan → archived** — do not teach ghosts.` | `- **tfsec → Trivy** (superseded); **Terrascan → archived** — teach neither.` | F2 |
| L8 | `pages/S14-security-scanners/index.md` | 195 | `- **TFC / HCP Terraform only**` | `- **HashiCorp products only** — HCP Terraform / Terraform Enterprise, Vault, Nomad` | F11 |
| L9 | `pages/S14-security-scanners/index.md` | 197 | `- Fine inside that product — not a portable default` | `- Fine inside those products — not a portable default` | F11 |
| L10 | `pages/S14-security-scanners/index.md` | 204-205 | `Sentinel is real and useful, but it` / `is tied to HashiCorp's cloud product; do not present it as the OpenTofu-first` (speaker note) | `Sentinel is real and useful, but it` / `is tied to HashiCorp's own products; do not present it as the OpenTofu-first` | F11 |
| L11 | `pages/S14-security-scanners/index.md` | 421 | `- Sentinel stays TFC-only; portable policy prefers OPA.` | `- Sentinel stays inside HashiCorp's products; portable policy prefers OPA.` | F11 |
| L12 | `pages/S14-security-scanners/index.md` | 242 | `version = "~> 5.0"` (indented 6 spaces) | `version = "~> 6.0"` (same indent) — **all three copies of this pin must move together**; see the note directly below this table | E3, E6, E7, F12 |
| L13 | `pages/S28-ecosystem-tooling/index.md` | 86 | `Terraform, Terragrunt, Atmos**.` (indented 2 spaces) | `Terraform, Terragrunt, Terramate, Atmos**.` (same indent) | G3 |
| L14 | `pages/S28-ecosystem-tooling/index.md` | 96 | `tfenv and tofuenv, is one binary that manages OpenTofu, Terraform, Terragrunt,` | `tfenv and tofuenv, is one binary that manages OpenTofu, Terraform, Terragrunt, Terramate,` (line 97 already reads `and Atmos`) | G3 |
| L15 | `pages/S28-ecosystem-tooling/index.md` | 88 | ``- **Not** part of `task setup` here — any `tofu ≥ 1.8` runs the labs. Adopt`` | ``- **Not** part of `task setup` here — `tofu ≥ 1.8` runs most labs (Lab 10 needs ≥ 1.9). Adopt`` | E2 |
| L16 | `pages/S28-ecosystem-tooling/index.md` | 99 | `workshop deliberately does not require tenv — any tofu one-point-eight or newer` (speaker note; line 100 continues `works —`, which the replacement absorbs — apply as a two-line edit and delete the now-duplicated `works —` from line 100) | `workshop deliberately does not require tenv — any tofu one-point-eight or newer runs most labs, and Lab 10 needs one-point-nine —` | E2 |
| L17 | `pages/S00-welcome/index.md` | 218 | `<KwCard heading="tofu ≥ 1.8" icon="🧊">` (indented 2 spaces) | `<KwCard heading="tofu ≥ 1.9" icon="🧊">` (same indent) — **the highest-value row in this table.** This is the "# Required toolchain" card a learner reads before installing anything; at 1.8 they satisfy it and still hard-fail Lab 10. Raising the advertised floor is simpler and safer than annotating an exception on a setup card. | E2 |
| L18 | `pages/S17-mocking/index.md` | 55 | `blocks; the workshop’s floor remains OpenTofu <strong>1.8+</strong>.` (note the curly apostrophe ’ — match it exactly) | `blocks; \`mock_provider\` needs OpenTofu <strong>1.8+</strong>, and Lab 10 raises the workshop's floor to <strong>1.9</strong>.` | C5, E2 |
| L19 | `pages/S01-iac/index.md` | 352 | `- Governed by the **Linux Foundation** (neutral, community)` | `- Governed by the **Linux Foundation**; a **CNCF Sandbox** project since 2025-04-23 (neutral, community)` | B6 |
| L20 | `README.md` | 68 | ``\| Decks and Day 1 \| OpenTofu ≥1.8, Node.js ≥20, pnpm, Task, Docker \|`` | ``\| Decks and Day 1 \| OpenTofu ≥1.9, Node.js ≥20, pnpm, Task, Docker \|`` — **arguably the single highest-value row here, ahead of L17.** `labs/day-1/10-differentiators/` IS a Day-1 lab and requires `>= 1.9.0`, so this line is false *by this document's own evidence*, and it sits in the repo's front door where a learner reads it before opening any deck. | E2 |
| L21 | `docs/setup.md` | 33 | ``\| Decks and Day 1 \| OpenTofu ≥1.8, Node.js ≥20, pnpm, Task, Docker \|`` | Same substitution as L20 — this is the same table row mirrored into the setup guide. | E2 |
| L22 | `docs/validation-matrix.md` | 78 | ``OpenTofu ≥1.8; `:4566` `` (the toolchain cell of the `day-1/10-differentiators` row) | ``OpenTofu ≥1.9; `:4566` `` — **this row describes Lab 10 itself**, whose own prerequisite at `labs/day-1/10-differentiators.md:31` reads "`tofu` ≥ 1.9". The matrix contradicts the lab it indexes. **Regenerate the inventory in the same change — see the L22 trap below.** | E2 |
| L23 | `docs/facilitator-runbook.md` | 15 | ``\`tofu version\` ≥1.8`` | ``\`tofu version\` ≥1.9`` — facilitator preflight; a facilitator who checks 1.8 will not discover the gap until Lab 10 fails in the room. | E2 |
| L24 | `docs/rehearsal-checklist.md` | 29 | ``confirm \`tofu version\` ≥1.8.`` | ``confirm \`tofu version\` ≥1.9.`` | E2 |
| L25 | `docs/rehearsal-checklist.md` | 42 | ``- [ ] OpenTofu ≥1.8 on \`PATH\` (\`task setup\`).`` | ``- [ ] OpenTofu ≥1.9 on \`PATH\` (\`task setup\`).`` | E2 |
| L26 | `labs/day-3/28-ecosystem-tooling.solution.md` | 35-36 | quote spans two lines — line 35 ends `` on purpose: any `tofu ≥ 1.8` `` and line 36 begins ``runs the labs.`` | ``…on purpose: `tofu ≥ 1.8` runs most labs, and Lab 10 needs ≥ 1.9.`` — same false sufficiency claim as L15, in the lab prose rather than the deck. | E2 |
| L27 | `labs/day-3/28-ecosystem-tooling.md` | 86-87 | ``one binary that manages **OpenTofu, Terraform,`` ends line 86; ``Terragrunt, and Atmos**.`` begins line 87 | Insert Terramate: ``Terragrunt, Terramate, and Atmos**.`` | G3 |
| L28 | `labs/day-3/28-ecosystem-tooling.solution.md` | 26-27 | ``one binary for OpenTofu, Terraform, Terragrunt, and`` ends line 26; ``Atmos — is how a laptop mirrors that pin per project:`` begins line 27 | Insert Terramate: ``…Terraform, Terragrunt, Terramate, and`` / ``Atmos — …`` | G3 |
| L29 | `docs/associate-alignment.md` | 69 | ``**Sentinel** policy authoring \| TFC/HCP-only.`` | ``**Sentinel** policy authoring \| HashiCorp products only (HCP Terraform / Terraform Enterprise, Vault, Nomad).`` — the same CONTRADICTED claim as L8/L11, mirrored into the certification-alignment doc. | F11 |
| L30 | `labs/day-1/01-iac-fork.md` | 338 | ``So OpenTofu stays **MPL 2.0** (truly open source, Linux-Foundation-governed) and`` | ``So OpenTofu stays **MPL 2.0** (truly open source, Linux-Foundation-governed, CNCF Sandbox since 2025-04-23) and`` — present-tense governance, so it takes the same update as L19. Without this the lab never gets the CNCF fact the deck does. | B6 |
| L31 | `labs/day-1/01-iac-fork.solution.md` | 252 | ``So OpenTofu stays **MPL 2.0** (truly open source, Linux-Foundation-governed) and`` | Same substitution as L30 — solution mirror. | B6 |

### The L22 trap — regenerate the inventory

`docs/validation-matrix.md` is the human source of truth for
`infra/lab-inventory.json`, and the JSON mirrors the toolchain column verbatim
(the `pinned` field for `day-1/10-differentiators` reads `OpenTofu ≥1.8; :4566`). Editing
the matrix without regenerating reds `pnpm test:inventory`.

**Reproduced, not reasoned about.** Applying L22 alone: `pnpm test:inventory`
fails with a `deepStrictEqual` diff, exit 1. Running
`node scripts/lab-inventory.mjs --write` and re-running:
`infra/lab-inventory.json: OK (matches docs/validation-matrix.md)`. Both edits
were reverted afterwards — this lane changes no prose and no inventory.

This is the same shape as the L12 trap: a second file mirrors the text you are
editing, and a gate watches the pair.

### The L12 trap — read before applying it

`aws ~> 5.0` exists in **three** places and all three must move in one change:

1. `pages/S14-security-scanners/index.md:242` — the slide block.
2. `labs/day-2/14-security-scanners/messy/main.tf:7` — the tracked fixture.
3. `labs/day-2/14-security-scanners.md:60` — the lab's copy of the fixture.

The third is the trap. `labs/day-2/14-security-scanners.md:52` carries
`<!-- source: labs/day-2/14-security-scanners/messy/main.tf -->`, so that block
**is** armed under `verify.sh` §6, and editing the fixture without it reds the
gate. The slide copy at `:242` is *not* armed (E7), which is why the
fixture+slide pair alone looks safe and is not.

**Both directions were reproduced rather than reasoned about.** All three edits
together: `verify PASSED — 139 check(s) OK, 0 failures`, with
`all 82 annotated block(s) match their source files`. Reverting only the lab
copy: `✗ drift: block in labs/day-2/14-security-scanners.md does NOT match
source file` and `verify FAILED — 1 failure(s) across 138 check(s)`. The edits
were reverted afterwards — this lane changes no prose.

**No re-capture of the F12 scanner output is needed.** Both pinned scanners were
re-run on a fixture copy carrying `~> 6.0` and emitted byte-identical findings
(same 7 Trivy IDs, same 7 Checkov IDs, same counts). The provider constraint
does not reach any rule.

### Locations deliberately left alone

Named in a Where cell above, or surfaced by the deck-wide grep, and correctly
carrying **no** L row. Recorded so a phase-2 reader can tell a decision from an
oversight.

| Location | Why no correction |
| --- | --- |
| `pages/S01-iac/index.md:319` (B6) | The timeline chip dates OpenTofu's 2024-01-10 GA "under the Linux Foundation". That was true then; CNCF acceptance came 15 months later (2025-04-23). Adding CNCF to a 2024 timeline beat would be an anachronism. L19 carries the update in the governance comparison, where it is timeless. |
| `pages/S01-iac/index.md:491` (B6) | Compressed one-line recap of the licence contrast. One insertion at `:352` is enough for the deck to state current governance; padding the recap costs clarity for no added truth. |
| `pages/S18-integration-cost/index.md:122, 179` (H1) | H1 is PARTIAL only because Infracost's docs call the key "free" without stating in those words that it is *mandatory*. The deck's wording ("needs a free API key for live runs") is if anything conservative — it over-warns, and the design decision it protects (Infracost stays an opt-in stretch; the core lab needs no signup) is unaffected either way. Correcting toward "may need" would make the deck less safe, not more accurate. |
| `pages/S27-terragrunt-comparison/index.md` (G7) | Nothing in S27 is *wrong*; G7 is an omission (Terragrunt v1.0.0 on 2026-03-30 and `terragrunt.stack.hcl`). The fix is new content, not a line edit, so it has no current/corrected pair. Belongs to a content story, not this list. |
| `pages/S01-iac/index.md:398-406, 440-442` (I4) | I4 is PARTIAL because the fetch returned Ansible's agentless property as a paraphrase rather than the literal adjective. The deck's substance matches the source; there is nothing to correct, only a weaker-than-hoped citation to record honestly. |
| `pages/S14-security-scanners/index.md:88` (F9) | UNVERIFIED is not "wrong". No source was reached on Snyk IaC's status, so there is nothing to correct toward. Correcting on an unsourced hunch is the exact failure this document exists to prevent. |
| `pages/S21-stacks` … `pages/S25-terramate-ci` (G8) | Same reasoning as F9: the Terramate CLI surface was never checked, so no correction can be justified. |
| `pages/S11-taco-landscape/index.md:231, 239` | Surfaced by the deck-wide `Sentinel` grep and **correctly left alone**: these say Sentinel policy *on HCP Terraform* is Terraform-only, i.e. a statement about which engine HCP Terraform runs. That is a different claim from F11's "Sentinel exists only in TFC", and it is accurate. A phase-2 lane grepping `Sentinel.*only` will hit it — do not "fix" it. |
| `pages/S19-testing-cicd/index.md:94` ("OpenTofu ≥ 1.8 preflight") | Accurate description of what the gate does: `scripts/verify.sh:92-95` really does `pass "tofu ${TOFU_VER} (>= 1.8)"` / `fail "… is below the required 1.8"`. It reports the gate's threshold, not a claim about lab sufficiency. (That the threshold *itself* understates Lab 10 is a separate finding — see below.) |
| `pages/S14-security-scanners/index.md:164` ("Do not pick a dead tool as your standard") | Sits in the `::right::` / Terrascan column, which genuinely **is** archived (F4). "Dead" is correct here. Only the tfsec-scoped uses (L3–L7) overstate. |
| `pages/S14-security-scanners/index.md:221` ("replaces the tfsec habit") | Accurate as written — it describes migrating off a habit, not declaring the tool dead. |
| `versions.env:13, 18, 23, 27` (D1–D4) and `labs/day-2/14-security-scanners.md:8` (D5) | Pins, not prose. Deliberately untouched by this docs-only lane; carried in the out-of-scope section below. |
| `labs/day-1/00-setup/versions.tf:2` and ~20 peers (E1) | The `>= 1.8` floor is *correct* for the content it guards. Only the claim that it suffices for **every** lab is wrong, and that is E2's business (L15–L18). |
| `labs/day-3/28-ecosystem-tooling.md:98` ("any `tofu ≥ 1.8` **works here**") | **Considered and deliberately kept.** Unlike L15/L26, this sentence is scoped to the lab the reader is currently in — Lab 28 genuinely runs on 1.8. It makes no claim about "the labs" collectively, so it is true as written. Flagged here because a phase-2 grep for `tofu ≥ 1.8` will hit it two lines from a sentence that IS being corrected. |
| The per-lab prerequisite lines — `- \`tofu\` ≥ 1.8 (\`task setup\` installs it).` in ~18 labs across Days 1–3 | Each states the floor for *its own* lab and each is correct; Lab 10, the only one needing more, already says "`tofu` ≥ 1.9" at `labs/day-1/10-differentiators.md:31`. These are the reason the defect stayed invisible: the pattern is overwhelmingly correct, and only the handful of *aggregate* claims (L15, L20–L26) overreach. Do not sweep them. |
| `docs/validation-matrix.md:50` ("macOS / Linux + OpenTofu ≥1.8") | Describes the environment the `verify.sh` unit lane is validated on, and `scripts/verify.sh:92` really does preflight at 1.8 — so it reports the gate's actual threshold. It becomes wrong only when that threshold is raised, which is the out-of-scope toolchain item below; correct it in that change, not this one. |
| `docs/validation-matrix.md:67` (`day-1/00-setup` row, "OpenTofu ≥1.8") | Correct for Lab 00, which is a `local_file` exercise. Unlike L22 this row indexes a lab that really does run on 1.8. |
| `labs/day-1/11-taco-landscape.md:37` ("HCP Terraform … Sentinel + OPA") | Same disposition as `pages/S11:231,239` — a statement about what HCP Terraform offers, not about where Sentinel exists. Accurate. A `Sentinel` grep will hit it; do not "fix" it. |
| `labs/day-2/14-security-scanners.md:327` and `.solution.md:217, 295` ("replaces the old `tfsec` habit via `trivy config`") | Same disposition as `pages/S14:221` — describes migrating off a habit rather than declaring the tool dead. Accurate; these are the only tfsec mentions outside the deck. |
| `labs/day-1/01-iac-fork.md:336` and `.solution.md:250` ("now governed by the **Linux Foundation**") | Timeline beats dated **2024-01-10**, exactly parallel to `pages/S01:319`. CNCF acceptance came 2025-04-23, so adding it to a 2024 beat would be an anachronism. The *present-tense* governance sentence two lines below each — `:338` and `:252` — is a different proposition and **does** get corrected, at L30/L31. |
| `pages/S14-security-scanners/index.md:64, 154` (F1) | The 2023 tfsec→Trivy date is verified correct. Only the dead/ghost framing around it overstates. |

### Out-of-scope findings raised by this pass

Not prose corrections — recorded so they are not lost.

- `setup/bootstrap.sh:25` sets `MIN_TOFU="1.8"`, which understates Lab 10's real
  1.9 requirement (E2), and `scripts/verify.sh:92` preflights at the same 1.8. Whoever applies L15–L18 should raise both in the same change
  or file it separately.
- **Raising the advertised floor to 1.9 (L20–L26) must move the enforcers too.**
  `setup/bootstrap.sh:25` sets `MIN_TOFU="1.8"` and `scripts/verify.sh:92`
  preflights `pass "tofu ${TOFU_VER} (>= 1.8)"`. If the docs say 1.9 while the
  gates accept 1.8, the repo has merely relocated the inconsistency. Apply
  L20–L26 and both tooling bumps in one change, and only then correct
  `docs/validation-matrix.md:50` (see the left-alone table).
- `versions.env:18` pins `GO_VERSION=1.23.6`, a Go series that no longer
  receives security fixes (D2). This is a toolchain decision with `verify.sh`
  §10 consumers behind it (CI literals, `setup/terratest/Dockerfile`,
  `setup/bootstrap.sh`) and a Terratest re-run required — deliberately **not**
  changed by this docs-only lane. It should become its own story.
- `pages/S14-.../index.md:235` reproduces `labs/day-2/14-security-scanners/messy/main.tf`
  verbatim but carries no `<!-- source: … -->` marker, so `verify.sh` §6 silently
  skips it (E7). Adding the one-line marker arms an already-built gate at zero cost
  and passes today. This is the cheapest gate improvement this pass found.
- `scripts/verify.sh` §9 emits three `info` lines claiming "S14 security scanning
  checks run when their content is authored" while running only `--version`. The
  content is authored and no check runs (see §K). Either implement check 3 or
  reword the output so a green run does not read as coverage it does not provide.
- The Trivy / Checkov / Conftest versions are pinned only in lab prose
  (`labs/day-2/14-security-scanners.md:8`) and nowhere else (D5). If check 1 in
  §K is built, promoting these three into `versions.env` would bring them under
  the existing §10 gate for free.
