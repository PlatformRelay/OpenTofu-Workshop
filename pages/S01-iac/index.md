---
layout: section-cover
image: /covers/section-01-the-two-blueprints.png
day: Day 1
section: '01'
tier: core
---

# Infrastructure as Code

Stop clicking consoles and running one-off scripts. Describe the infrastructure
you *want*, and let a tool make reality match — repeatably, reviewably, and with
a plan you can read before anything changes.

<!--
Say: Frame the whole day. IaC means you stop clicking consoles and running
throwaway scripts, and instead describe the infrastructure you WANT as code — then
a tool converges reality to that description, repeatably and reviewably. The hook
for this section: by the end you can explain WHY IaC beats scripts, and you'll know
the OpenTofu fork story that decides which CLI we teach. (~1 min)
Then: "Let's start with why — what's actually wrong with the old way."
-->

---

<span class="kw-kicker">Why IaC</span>

# The problem with doing it by hand

<div class="kw-cols-3 mt-4">
  <KwCard heading="Not repeatable" variant="danger">
    <strong>Snowflakes.</strong> Click-ops and one-off scripts drift apart. No two
    environments are ever quite the same.
  </KwCard>
  <KwCard heading="No preview" variant="warn">
    <strong>Blind changes.</strong> A script just runs. You find out what it did
    <em>after</em> it did it — sometimes in production.
  </KwCard>
  <KwCard heading="No memory" variant="warn">
    <strong>No drift detection.</strong> Nothing records what <em>should</em> exist,
    so nothing notices when reality wanders off.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

IaC answers all three: infrastructure becomes **code** — version-controlled,
reviewed in a PR, and reconciled to a desired state on every run.

</div>

<!--
Say: Three failure modes of doing infra by hand. Not repeatable — click-ops and
ad-hoc scripts produce snowflakes; no two environments match. No preview — a script
just runs, so you learn what it did after the fact, sometimes in prod. No memory —
nothing records desired state, so nothing detects drift. Then the click reveal: IaC
fixes all three by making infrastructure code — versioned, PR-reviewed, and
reconciled to a desired state every run. (~3 min)
Then: "This didn't appear overnight — here's the evolution that got us here."
-->

---

<span class="kw-kicker">How we got here</span>

# Click-ops → scripts → declarative IaC

<div class="kw-cols-3 mt-6">
  <KwCard heading="1 · Click-ops" variant="danger">
    Point-and-click in a console. Fast to start, impossible to reproduce, review,
    or audit. Every change is a manual snowflake.
  </KwCard>
  <div v-click>
  <KwCard heading="2 · Scripts" variant="warn">
    Imperative <code>bash</code>/SDK calls: the exact <em>steps</em> to take. Repeatable-ish,
    but not idempotent — re-running can double-create or fail halfway.
  </KwCard>
  </div>
  <div v-click>
  <KwCard heading="3 · Declarative IaC" variant="ok">
    Describe the <em>desired state</em>; the tool computes the diff and converges.
    Idempotent, previewable, drift-aware. Where we live now.
  </KwCard>
  </div>
</div>

<!--
Say: The evolution in three steps, revealed click by click. Click-ops: point and
click, fast to start but impossible to reproduce, review, or audit. Scripts: an
improvement — imperative bash or SDK calls capture the STEPS, so it's repeatable-ish,
but it's not idempotent, so re-running can double-create or die halfway. Declarative
IaC: you describe the desired STATE, the tool computes the diff and converges —
idempotent, previewable, drift-aware. Stress that each step fixed a real pain of the
one before it. (~3 min)
Then: "And that last step changed more than the tooling — it changed who touches infrastructure."
-->

---

<span class="kw-kicker">Where IaC sits</span>

# Infrastructure joins the DevOps loop

<div class="kw-cols-3 mt-6">
  <KwCard heading="Same artefact" variant="ok">
    Infrastructure becomes a <strong>file in a repo</strong> — branched, diffed,
    and reviewed in a pull request like any other change.
  </KwCard>
  <div v-click>
  <KwCard heading="Same pipeline" variant="ok">
    <code>plan</code> on the pull request, <code>apply</code> on merge. The
    <strong>DevOps</strong> build → review → deploy loop, with infrastructure as
    the artefact.
  </KwCard>
  </div>
  <div v-click>
  <KwCard heading="Same feedback" variant="ok">
    Drift detection is monitoring for configuration: intent is compared to
    reality on <em>every</em> run, not at a quarterly audit.
  </KwCard>
  </div>
</div>

<div v-click class="mt-6 kw-muted text-sm">

The payoff is organisational, not just technical: infrastructure stops being a
**ticket queue** and becomes a **reviewable change** anyone on the team can
propose. Everything after this slide is the mechanics of making that safe.

</div>

<!--
Say: Place IaC in its DevOps context, revealed click by click. Same artefact —
infrastructure becomes a file in the repo, so it branches, diffs, and gets reviewed
in a PR like application code. Same pipeline — plan runs on the pull request, apply
runs on merge; that is the build-review-deploy loop with infrastructure as the
artefact. Same feedback — drift detection is monitoring for configuration: intent is
compared to reality on every run, not at an audit. Final reveal: the payoff is
organisational as much as technical — infrastructure stops being a ticket queue and
becomes a change anyone can propose. Everything after this slide is the mechanics of
making that safe. (~3 min)
Then: "Let's pin down that word — declarative vs imperative — with real code."
-->

---
layout: statement
kicker: 'The core distinction'
---

**Imperative** says *how*: the steps to take.

**Declarative** says *what*: the state to reach.

The tool figures out the how — and can preview it, repeat it, and repair it.

<!--
Say: This is the one distinction to nail. Imperative code says HOW — the ordered
steps. Declarative code says WHAT — the end state you want to exist. With
declarative, the tool derives the how, which is exactly what buys you the preview
(plan), the repeatability (idempotency), and the repair (drift reconcile). Keep it
crisp — the next slide shows the same intent both ways. (~2 min)
Then: "Here's the same job — write the project's manifest file — as a script, then as HCL."
-->

---
layout: two-cols-code
heading: Same job, two paradigms
---

````md magic-move
```bash
#!/usr/bin/env bash
# Imperative: the exact steps, every time.
mkdir -p build
echo "service = service-manifest, \
  environment = host-$RANDOM \
  — provisioned imperatively." \
  > build/manifest.txt
cat build/manifest.txt
# Run it twice → a DIFFERENT file.
# No plan. No idempotency. No drift check.
```

```hcl
# Declarative: the desired state.
resource "random_pet" "env" {
  length = 2
}

resource "local_file" "manifest" {
  filename = "${path.module}/build/manifest.txt"
  content  = "service = service-manifest, environment = ${random_pet.env.id}\n"
}
# tofu plan previews. apply is idempotent.
# Edit the file by hand → tofu detects drift.
```
````

::right::

<div class="mt-4">
  <KwCard heading="The script" variant="danger">
    <strong>Steps.</strong> New <code>$RANDOM</code> each run, no preview, no memory
    of what it built. Re-running is a fresh roll of the dice.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="The HCL" kind="resource" variant="ok">
    <strong>State.</strong> The pet name is generated <em>once</em> and stored;
    <code>plan</code> previews, <code>apply</code> is idempotent, and drift is
    detected and reconciled.
  </KwCard>
  </div>
</div>

<!--
Say: Same job — write the project's manifest file — expressed both ways via magic-move. The
bash version is imperative: mkdir, echo with $RANDOM, cat. Run it twice and you get
a different file; there's no plan, no idempotency, no memory. Morph to the HCL: a
random_pet generates a stable identity once and stores it in state, and a local_file
declares the manifest's desired content. That local_file.manifest is the SPINE of
the whole of Day 1 — every later stage still declares it, under that exact name. Now tofu plan previews before acting, apply is
idempotent, and if someone hand-edits the file tofu detects the drift and puts it
back. This is the HCL you build in Lab 01 — the lab's tracked `main.tf` is the source of truth (the slide is illustrative). (~5 min)
Then: "None of that behaviour is accidental — it falls out of six design principles."
-->

---

<span class="kw-kicker">Why it behaves that way</span>

# The six design principles

<div class="kw-cols-3 mt-4">
  <KwCard heading="1 · Declarative config">
    Configuration files describe the <strong>end state</strong>. You never write
    the ordered steps — the tool derives them.
  </KwCard>
  <KwCard heading="2 · Execution plan">
    By default a run first describes what it <em>would</em> create, update, or
    destroy, and waits for your approval.
  </KwCard>
  <KwCard heading="3 · Resource graph">
    Dependencies are inferred into a graph; non-dependent resources are created
    and modified <strong>in parallel</strong>.
  </KwCard>
</div>

<div class="kw-cols-3 mt-3">
  <KwCard heading="4 · State">
    A state file records what is managed — the memory that makes drift
    detectable and a second apply a no-op.
  </KwCard>
  <KwCard heading="5 · Immutability">
    Where a change cannot be made in place, the resource is
    <strong>replaced</strong> rather than patched into an unknown shape.
  </KwCard>
  <KwCard heading="6 · Modules">
    Reusable configuration components, so a pattern is written once and consumed
    with arguments.
  </KwCard>
</div>

<div v-click class="mt-5 kw-muted text-sm">

OpenTofu inherits **all six** from Terraform — the fork changed the licence and
the governance, not the model. Day 1 walks them in roughly this order: 1 and 2
today, 3 and 5 at the core workflow, 4 at state, 6 at modules.

</div>

<!--
Say: Name the principles behind everything the previous slide just demonstrated.
One, declarative configuration — files describe the end state, not the steps. Two,
execution plans — by default a run previews what it would create, update, or
destroy and waits for approval, which is why S00 had to pass -auto-approve to skip
the prompt. Three, the resource graph — dependencies are inferred and
non-dependent resources are handled in parallel, which is why applies are not
serial. Four, state — the recorded memory of what is managed, which is exactly what
makes drift detectable and a re-apply a no-op. Five, immutability — where a change
cannot be made in place the resource is replaced rather than patched into an unknown
shape. Six, modules — reusable components, so a pattern is written once. Then the
reveal: OpenTofu inherits all six from Terraform, and Day 1 walks them in this
order, so treat this slide as the map of the day. Be accurate about where each one
lands: 5 is taught in S03, where the plan reads `-/+ destroy and then create
replacement` — NOT in S04/S05, which teach state and its encryption and contain no
replacement content. Immutability as a named principle recurs in S09, which the
Day-1 fit plan skips, so S03 is the only place a canonical-cut learner meets it.
Sources, verified at authoring time — cite if challenged. OpenTofu's own overview,
https://opentofu.org/docs/intro/ : declarative configuration files describing
end-state infrastructure; "OpenTofu creates an execution plan"; "resource graph to
determine resource dependencies and creates or modifies non-dependent resources in
parallel"; the state file "acts as a source of truth for your environment"; an
"immutable approach to infrastructure"; "reusable configuration components called
modules". The same six are stated for Terraform at
https://developer.hashicorp.com/terraform/intro , which is what makes "inherited,
not invented" a fair claim rather than an assumption. (~3 min)
Then: "So why do we type 'tofu' and not 'terraform'? Here's the fork."
-->

---
clicks: 3
---

<span class="kw-kicker">The fork, on a timeline</span>

# HashiCorp → OpenTofu

<div class="mt-8 space-y-4">
  <div class="flex items-center gap-4">
    <KwChip>2023-08-10</KwChip>
    <span>HashiCorp relicenses Terraform <strong>MPL 2.0 → BUSL 1.1</strong> — open source becomes <em>source-available</em>.</span>
  </div>
  <div v-click class="flex items-center gap-4">
    <KwChip variant="warn">2023-08-25</KwChip>
    <span>The community forks the last MPL-2.0 release as <strong>OpenTofu</strong>.</span>
  </div>
  <div v-click class="flex items-center gap-4">
    <KwChip variant="ok">2024-01-10</KwChip>
    <span><strong>OpenTofu 1.6</strong> ships GA — drop-in compatible, under the <strong>Linux Foundation</strong>.</span>
  </div>
</div>

<div v-click class="mt-8 kw-muted text-sm">

That's why the HCL block is still `terraform {}` (compatibility) but the CLI you
run — and everything here — is `tofu`.

</div>

<!--
Say: The fork as a three-beat timeline, revealed click by click. 2023-08-10:
HashiCorp relicenses Terraform from MPL 2.0 to BUSL 1.1 — open source becomes
source-available. 2023-08-25: the community forks the last MPL-2.0 release as
OpenTofu. 2024-01-10: OpenTofu 1.6 ships GA, drop-in compatible, now under the Linux
Foundation. Final reveal: this is exactly why the top-level block is still named
terraform {} for compatibility, but the CLI we run — and everything in this
workshop — is tofu. (~3 min)
Then: "Let's make the licence difference concrete — MPL vs BUSL, side by side."
-->

---
layout: comparison
heading: MPL 2.0 vs BUSL 1.1 — what the licence buys you
leftHeading: OpenTofu
rightHeading: Terraform
leftBadge: 'MPL 2.0'
rightBadge: 'BUSL 1.1'
---

- **Open source** — OSI-approved, no field-of-use limit
- Use, modify, and build a **commercial** product on it freely
- Governed by the **Linux Foundation**; a **CNCF Sandbox** project since 2025-04-23 (neutral, community)
- HCL- and CLI-**compatible** — low-friction to adopt

::right::

- **Source-available**, not open source
- "Additional use grant" **forbids competing** commercial use
- Each release converts to an older licence only at its **change date**
- Controlled by a **single vendor**

<!--
Say: This is the "why it matters to you" slide. OpenTofu under MPL 2.0 is
OSI-approved open source with no field-of-use limit — you can use, modify, and build
a commercial product on it freely, and it's governed by the neutral Linux
Foundation. Terraform under BUSL 1.1 is source-available, not open source: the code
is visible, but the additional-use-grant forbids using it to compete with the
licensor until each release hits its change date, and it's controlled by a single
vendor. For a team that wants genuinely open, community-governed tooling, OpenTofu
is the answer — and it's compatible, so adopting it is low-friction. (~3 min)
Then: "And the licence isn't the whole story — since the fork, the feature sets
have diverged too."
-->

---
layout: statement
kicker: 'Beyond the licence'
---

The fork changed more than the licence — since 1.7, **the feature sets have
diverged**.

Same HCL, drop-in compatible — *and* OpenTofu ships features the Terraform CLI
simply doesn't have.

<!--
Say: Head off the assumption that OpenTofu is just a licence-clean copy. That was
true at 1.6; from 1.7 onward the feature sets have diverged, and several OpenTofu
features have no Terraform equivalent at all. The HCL and the plan/apply workflow
stay drop-in compatible — you lose nothing — but you gain capabilities Terraform's
CLI doesn't offer. The next two slides are the teaser; S10 is the deep dive. (~1 min)
Then: "Here are the three headliners you literally cannot write in Terraform."
-->

---

<span class="kw-kicker">The differentiators, teased</span>

# Three things you can't write in Terraform

<div class="kw-cols-3 mt-4">
  <KwCard heading="State & plan encryption" kind="state" variant="accent">
    <strong>1.7.</strong> Client-side encryption of state and plan files —
    <code>terraform { encryption {} }</code>, key providers, <code>fallback</code>
    to migrate. You'll <strong>build it yourself</strong> later today (S05).
  </KwCard>
  <KwCard heading="Provider for_each" kind="module" variant="ok">
    <strong>1.9.</strong> One <code>provider</code> block fans out to one instance
    per key — e.g. per region. Terraform needs a hand-written aliased block for
    each one.
  </KwCard>
  <KwCard heading="-exclude" kind="validation" variant="warn">
    <strong>1.9.</strong> The inverse of <code>-target</code>: plan everything
    <em>but</em> the addresses you name — often the shorter list when breaking
    out of a bad apply.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

All three are **OpenTofu-only** — Terraform's docs offer aliasing, `-target`,
and backend-delegated state encryption, but no equivalent of these.

</div>

<!--
Say: Three concrete features with no Terraform equivalent, so "why tofu" is never
just a licence argument. One: client-side state and plan encryption, shipped in
1.7 — an encryption block with key providers and a fallback to migrate plaintext
state; you will build it hands-on in S05 later today, so just plant the flag here.
Two: provider for_each from 1.9 — a single provider block becomes one instance
per key, say one per region, where Terraform makes you hand-write and hand-sync an
aliased block each. Three: -exclude, also 1.9 — the inverse of -target, planning
everything except the addresses you name. Click for the honesty line: all three
are genuinely absent from Terraform — its docs offer aliasing, -target, and
backend-delegated encryption instead. (~2 min)
Then: "And the pace hasn't slowed — here's the release timeline in one glance."
-->

---

<span class="kw-kicker">The pace since the fork</span>

# 1.7 → 1.12, in one glance — S10 has the depth

<div class="text-sm mt-4 space-y-2">
  <div><KwChip>1.7</KwChip> State &amp; plan <strong>encryption</strong> · provider-defined functions · <code>removed</code> block</div>
  <div v-click><KwChip>1.8</KwChip> <code>.tofu</code> file extension · test <strong>mocking &amp; overrides</strong></div>
  <div v-click><KwChip>1.9</KwChip> <strong>Provider <code>for_each</code></strong> · <strong><code>-exclude</code></strong> plan filter</div>
  <div v-click><KwChip>1.10</KwChip> <strong>OCI</strong> registries for providers &amp; modules · native S3 state locking · external key providers</div>
  <div v-click><KwChip>1.11–1.12</KwChip> Ephemeral resources &amp; write-only attributes · <code>enabled</code> meta-arg · <code>destroy = false</code></div>
</div>

<div v-click class="mt-6 kw-muted text-sm">

Current baseline: **OpenTofu 1.12.x** (supported to 2027-02-01); this workshop
pins **1.10.3** (`versions.env`) for reproducibility. The deep dive is
**S10 — OpenTofu differentiators** (skipped in the 3-day cut): its Lab 10 runs
the 1.9 pair against LocalStack — take it as follow-up.

</div>

<!--
Say: One release per beat, so the pace lands without memorizing anything. 1.7 is
the watershed: state and plan encryption, provider-defined functions, the removed
block. 1.8: the .tofu extension and test mocking. 1.9: provider for_each and
-exclude — the pair you just met. 1.10: OCI registries for providers and modules,
native S3 locking, external key providers. 1.11 and 1.12: ephemeral resources,
write-only attributes, the enabled meta-argument, destroy equals false. Final
click: today's baseline is 1.12.x, supported into 2027; the workshop pins 1.10.3
for reproducibility. This slide is deliberately a teaser — S10 is the deep dive
with a lab that runs the 1.9 pair on LocalStack; it's skipped in the 3-day cut,
so point the room at it as follow-up. (~2 min)
Then: "One honest caveat before the lab — OpenTofu is not the only tool in this space."
-->

---

<span class="kw-kicker">The honest caveat</span>

# Three practical alternatives — and when each fits

<div class="kw-cols-3 mt-4">
  <KwCard heading="Pulumi">
    <strong>IaC in a general-purpose language.</strong> Its docs list
    TypeScript/JavaScript, Python, Go, .NET, Java and YAML.
    <br><br>
    <em>Fits when</em> the team already thinks in one of those languages and the
    config needs real control flow. <em>Costs</em> you reviewers who can read
    that language — and a config that can do anything a program can.
  </KwCard>
  <KwCard heading="Crossplane">
    <strong>A control-plane framework.</strong> It extends Kubernetes with custom
    resources, so the cluster reconciles whatever your platform manages — a load
    balancer, an app, even a repository.
    <br><br>
    <em>Fits when</em> you are building a self-service platform and already run
    Kubernetes as your control plane. <em>Costs</em> you that cluster, plus the
    expertise to operate it.
  </KwCard>
  <KwCard heading="Ansible">
    <strong>Agentless automation.</strong> Configuration management and
    deployment; a playbook changes nothing once the system already matches it.
    <br><br>
    <em>Fits</em> <strong>alongside</strong> OpenTofu rather than instead of it:
    provision the machine here, configure what runs <em>inside</em> it there.
  </KwCard>
</div>

<div v-click class="mt-5 kw-muted text-sm">

Also in the room: **provider-native** tools — AWS **CloudFormation**, the AWS
**CDK**, Azure Bicep. AWS scopes CloudFormation to *your AWS resources*, and
that is the whole trade: the deepest single-cloud integration, none of the
cross-provider reach. We teach OpenTofu because this workshop wants **one**
declarative model that spans providers.

</div>

<!--
Say: Be straight with the room — OpenTofu is a choice, not the only option. Pulumi
does IaC in a general-purpose programming language; it fits a team that already
thinks in TypeScript or Python and needs real control flow, and the price is that
the config can now do anything a program can, so reviewers must read that language.
Crossplane is a control-plane framework that extends Kubernetes with custom
resources, so the cluster reconciles whatever the platform manages — its docs give
deploying an app, creating a load balancer and creating a repository as examples,
so do not narrow it to "cloud infrastructure"; it fits platform teams
building self-service on a cluster they already run, and the price is that cluster
and the expertise to operate it. Ansible is agentless configuration management — a
playbook changes nothing once the system already matches it — and it sits ALONGSIDE
OpenTofu: provision the box here, configure what runs inside it there. Click for the
provider-native family — CloudFormation, the AWS CDK, Bicep: deepest single-cloud
integration, no cross-provider reach. Say "the AWS CDK", not "CDK": CDKTF is a
different tool that targets Terraform/OpenTofu, and conflating them confuses the
point.
Honesty note for the facilitator. The "what it is" sentence on each card is that
project's own self-description: Pulumi https://www.pulumi.com/docs/iac/concepts/
("modern infrastructure as code platform … leverages existing programming
languages"); Crossplane https://docs.crossplane.io/latest/whats-crossplane/ ("a
control plane framework for platform engineering" that "extends Kubernetes"; "It
could deploy an app, create a load balancer, or create a GitHub repository");
Ansible https://docs.ansible.com/ansible/latest/getting_started/introduction.html
(agentless; "when the system is in the state your playbook describes, Ansible does
not change anything, even if the playbook runs multiple times"); AWS
https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html ("model
and set up your AWS resources"). The "fits when / costs you" lines are this
workshop's judgement, not a vendor claim — say so if someone pushes back. There are
deliberately no version numbers, licence names, or foundation-status claims on this
slide: those age badly and none is needed to make the point. If the room wants
managed platforms compared, that is S11's landscape, not this beat. (~4 min)
Then: "Now go do it yourself — Lab 01."
-->

---
layout: lab
lab: labs/day-1/01-iac-fork.md
duration: 20 min
env: 'mock ✓ (no docker)'
---

# Lab 01 — from a shell script to HCL

Run a throwaway imperative script twice and watch it produce a different file each
time. Then apply the **declarative** HCL, prove a re-apply is a **no-op**, hand-edit
the managed file, and watch `tofu` **detect the drift and reconcile** it. Finish by
reading the fork/licensing note.

Every task has a `<details>` spoiler; panic reset is `tofu destroy` + `rm`.

<!--
Say: Set up the lab and its payoff. First feel the imperative pain — run the bash
script twice, get a different file each time. Then apply the declarative HCL and hit
the three things scripts can't do: plan previews, a second apply is a clean no-op,
and when you hand-edit the managed file, tofu detects the drift and puts it back.
Close by reading the short fork/licensing note so the "why tofu" lands. Every task
has a spoiler; panic reset is tofu destroy plus rm — nothing cloud, nothing to leak.
(~20 min, matches the lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: Infrastructure as Code — recap
story: 'Describe the state you want; let the tool make reality match — and know why it says tofu.'
next: 'Next: HCL & building blocks'
---

- Doing infra by hand fails three ways: **not repeatable**, **no preview**, **no drift detection**.
- The evolution: **click-ops → scripts → declarative IaC**, each fixing the last one's pain.
- **Imperative** says *how*; **declarative** says *what* — and the tool previews, repeats, and repairs.
- Six **design principles**: declarative config, execution plan, resource graph, state, immutability, modules.
- The **fork**: BUSL relicense (2023-08-10) → OpenTofu fork (2023-08-25) → 1.6 GA (2024-01-10).
- **MPL 2.0** (open, Linux Foundation) vs **BUSL 1.1** (source-available, single vendor) — why we run `tofu`.
- **Beyond the licence**: state & plan **encryption** (1.7), provider **`for_each`** and **`-exclude`** (1.9) are OpenTofu-only — S10 is the deep dive.
- **Alternatives are real**: Pulumi, Crossplane and Ansible each fit a different job — know which one you have.

<!--
Say: Pull the six threads together. Doing infra by hand fails three ways — not
repeatable, no preview, no drift detection. The evolution went click-ops to scripts
to declarative IaC, each step fixing the prior pain. The core distinction:
imperative says how, declarative says what, and the tool previews, repeats, and
repairs. The fork timeline: BUSL relicense, community fork, 1.6 GA. And the licence
difference — MPL 2.0 open and Linux-Foundation-governed versus BUSL 1.1
source-available and single-vendor — is why we teach the tofu CLI. But the fork is
not only a licence story: state and plan encryption, provider for_each, and
-exclude are OpenTofu-only, and S10 is the deep dive when there's time. Then the
two orientation threads: the six design principles that explain the behaviour, and
the alternatives — Pulumi, Crossplane, Ansible — so nobody leaves the room thinking
OpenTofu is the only option. (~2 min)
Then: transition into S02 — HCL & building blocks.
-->
