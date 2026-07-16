---
layout: section-cover
image: /covers/section-04-the-great-survey-map.png
day: Day 1
section: '04'
tier: core
---

# State

OpenTofu remembers what it built in a **state file** — the map from your config
to the real world. It's what makes a plan a *diff*. It's also a plaintext
database of everything you deployed, secrets included.

<!--
Say: Frame S04. Last section ended on the word "state" — apply records its result
there, and that memory is what lets the next plan be a diff instead of a fresh
create. This section answers three questions: what state actually is, why it's
load-bearing (locking, backends), and why it's dangerous — it stores resolved
secrets in plaintext. That last point is the hook straight into S05, state
encryption. This is the Terraform-Associate state / backends / state-security
objective. (~1 min)
Then: "Start with what state actually is — reconcile three things."
-->

---

<span class="kw-kicker">What state is</span>

# Desired · actual · state

<div class="kw-cols-3 mt-4">
  <KwCard heading="Desired" kind="resource" variant="ok">
    <strong>Your config.</strong> The HCL you wrote — what you <em>want</em> to
    exist.
  </KwCard>
  <KwCard heading="Actual" variant="warn">
    <strong>The real world.</strong> What's actually deployed right now, read back
    by a <code>refresh</code>.
  </KwCard>
  <KwCard heading="State" kind="state" variant="ok">
    <strong>The record.</strong> What OpenTofu <em>last</em> built — the map from
    config addresses to real resource IDs.
  </KwCard>
</div>

<div v-click class="mt-6 space-y-2">
  <div class="flex items-center gap-3">
    <KwChip variant="ok">desired</KwChip><span>vs</span>
    <KwChip variant="state">state</KwChip><span>vs</span>
    <KwChip variant="warn">actual</KwChip>
    <span class="kw-muted text-sm">— every <code>plan</code> reconciles all three</span>
  </div>
</div>

<div v-click class="mt-5 kw-muted text-sm">

A `plan` is the **reconcile**: compare *desired* to *state* to spot config
changes, and *state* to *actual* to spot **drift** someone made by hand. No
state, no diff — every apply would be a blind re-create.

</div>

<!--
Say: State is one of three things a plan juggles. Desired is your config — what you
want. Actual is the real world, read back by a refresh. State is what OpenTofu last
built: the map from config addresses like random_pet.service to real resource IDs.
Click: a plan reconciles all three. Click again: it compares desired to state to
find what you changed in config, and state to actual to find drift — changes someone
made by hand outside OpenTofu. Without state there's no diff at all; every apply
would be a blind from-scratch create. State is the memory that makes idempotency and
drift-detection possible. (~4 min)
Then: "Watch that reconcile happen field by field."
-->

---
layout: two-cols-code
heading: 'The reconcile, step by step'
---

````md magic-move
```console
# 1. desired (config) — what you wrote
resource "random_pet" "service" {
  length = 2
}
```

```console
# 2. state — what OpenTofu last built
random_pet.service:
  id = "crack-parrot"   # recorded last apply
```

```console
# 3. actual — refresh reads the real world
random_pet.service: Refreshing state... [id=crack-parrot]
# real == state == desired  →  nothing to do
```

```console
# 4. drift! someone edited service.txt by hand
local_file.service_name: Refreshing state...
  ~ content = "edited by hand" -> "service = crack-parrot"
    # plan reconciles ACTUAL back to your config
```
````

::right::

<div class="mt-4">
  <KwCard heading="Match" kind="state" variant="ok">
    When <strong>desired == state == actual</strong>, the plan is a
    <strong>no-op</strong>. That's the idempotent steady state.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="Drift" variant="warn">
    When <strong>actual ≠ state</strong>, the refresh caught a hand-change. The
    plan proposes to <strong>reconcile reality back</strong> to your config.
  </KwCard>
  </div>
</div>

<!--
Say: The reconcile as a four-step morph. One: desired, the config you wrote. Two:
state, what OpenTofu recorded last apply — the pet's id crack-parrot. Three: the
refresh reads actual and it matches state and desired, so there's nothing to do —
the no-op. Four: the drift case — someone edited service.txt by hand, so actual no
longer matches state, the refresh catches it, and the plan proposes to reconcile
ACTUAL back to your config — it always steers reality toward what you declared, not
the other way. State is the fixed reference point both comparisons pivot on. The
values here are illustrative; you'll see real ones in the lab. (~5 min)
Then: "Where does that state file actually live? Backends."
-->

---

<span class="kw-kicker">Where state lives</span>

# Backends — local vs remote

<div class="kw-cols-2 mt-4">
  <KwCard heading="local (default)" kind="state" variant="ok">
    A <code>terraform.tfstate</code> file <strong>on your disk</strong>. Zero
    setup — perfect for learning. But it lives on <em>one</em> machine and has
    <strong>no locking</strong> across people.
  </KwCard>
  <KwCard heading="remote" kind="state" variant="warn">
    State in <strong>shared storage</strong> — S3, GCS, an HTTP backend,
    Postgres. Enables <strong>team access</strong>, at-rest encryption on the
    server, and <strong>locking</strong>.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

You switch backends by editing the `backend {}` block and running
`tofu init -migrate-state` — OpenTofu **copies** the state to the new location
and re-points the working dir. You migrate a **local path** exactly this way in
the lab (no cloud required).

</div>

<!--
Say: State has to live somewhere — that's the backend. The default is local: a
terraform.tfstate file on your disk, zero setup, great for learning, but it sits on
one machine and offers no locking when two people share it. Remote backends put
state in shared storage — S3, GCS, an HTTP backend, Postgres — which unlocks team
access, server-side at-rest encryption, and locking. Click: you switch backends by
editing the backend block and running tofu init -migrate-state; OpenTofu copies the
state across and re-points the directory. We can't stand up S3 here, so the lab
migrates between two LOCAL paths with the exact same mechanic. (~4 min)
Then: "Remote backends unlock the thing local can't do safely: locking."
-->

---
layout: statement
kicker: 'Why remote backends matter'
---

Two applies at once, on shared state, is **corruption**.

**Locking:** a remote backend takes a **lock** for the duration of an
`apply`, so a second run **waits** instead of racing. Local state has no lock
across machines — fine solo, dangerous in a team.

<!--
Say: This is the load-bearing reason teams go remote. If two people run apply against
the same state at the same time, their writes interleave and the state file corrupts —
you can lose track of real resources. A remote backend takes a lock for the duration
of an apply, so the second run blocks and waits its turn instead of racing. Locking
is a property of the backend, not the CLI: S3 uses a lock file or DynamoDB, Postgres
uses an advisory lock. Local state has no cross-machine lock — perfectly fine when
you're solo, genuinely dangerous the moment a second person shares it. (~2 min)
Then: "Now the tools for reading and surgically editing state."
-->

---
layout: code-annotated
heading: 'Inspecting state — list, show, mv, rm'
lab: labs/day-1/04-state.md
---

```console {none|1-4|5|6|7|all}
$ tofu state list
local_file.service_name
random_password.db
random_pet.service
$ tofu state show random_pet.service
$ tofu state mv  random_pet.service random_pet.svc
$ tofu state rm  random_pet.service
```

::notes::

<CodeNote at="1" label="state list" variant="ok">
  Every resource address OpenTofu is tracking. Your inventory — start here.
</CodeNote>

<CodeNote at="2" label="state show &lt;addr&gt;">
  The recorded attributes of <strong>one</strong> resource. <code>sensitive</code>
  fields print as <code>(sensitive value)</code> — the CLI redacts them.
</CodeNote>

<CodeNote at="3" label="state mv" variant="warn">
  <strong>Rename in state</strong> without destroy/recreate — e.g. after you
  rename a resource in config. State-only; touches nothing real.
</CodeNote>

<CodeNote at="4" label="state rm" variant="danger">
  <strong>Forget</strong> a resource — remove it from state <em>without</em>
  destroying it. The next <code>plan</code> then wants to <strong>recreate</strong>
  it. Sharp edge — you break→fix this in the lab.
</CodeNote>

<!--
Say: Four subcommands for reading and surgically editing state — never hand-edit the
JSON. state list is your inventory: every address OpenTofu tracks; always start here.
state show dumps one resource's recorded attributes, and note that sensitive fields
print as (sensitive value) — the CLI redacts them, which matters in a second. state mv
renames a resource in state without a destroy-recreate — you run it after renaming a
resource in config so OpenTofu keeps the same real object. state rm is the sharp one:
it forgets a resource — drops it from state without destroying the real thing — so the
next plan wants to recreate it. That gap is your break-fix in the lab. These are
illustrative invocations; the lab runs each against a real state. (~5 min)
Then: "state show redacts the secret — but what's actually in the file?"
-->

---
layout: code-annotated
heading: 'The plaintext secret — CLI hides it, the file does not'
lab: labs/day-1/04-state.md
---

```console {none|1-2|4-5|7-9|all}
$ tofu state show random_password.db | grep result
    result = (sensitive value)          # CLI redacts

$ grep -o '"result": "[^"]*"' terraform.tfstate
"result": "MUH-Ud?RTW\u0026ven+_OcSC"        # plaintext on disk!

$ jq -r '.resources[]|select(.type=="random_password")
         |.instances[0].attributes.result' terraform.tfstate
MUH-Ud?RTW&ven+_OcSC
```

::notes::

<CodeNote at="1" label="the CLI is polite" variant="ok">
  <code>state show</code> honours <code>sensitive</code> — the password prints as
  <code>(sensitive value)</code>. Reassuring, and <strong>misleading</strong>.
</CodeNote>

<CodeNote at="2" label="the file is not" variant="danger">
  <code>terraform.tfstate</code> is <strong>plaintext JSON</strong>. The resolved
  password sits there as a literal string — <code>grep</code> finds it instantly.
</CodeNote>

<CodeNote at="3" label="anyone with the file" variant="danger">
  Backups, CI artifacts, a laptop, a git slip — anyone who reads the file reads
  the secret. This is the risk S05 closes.
</CodeNote>

<!--
Say: This is the section's payload and the setup for S05. A random_password is marked
sensitive, so state show politely prints result = (sensitive value) — reassuring, and
completely misleading. The file on disk is plaintext JSON: the RESOLVED password is a
literal string in terraform.tfstate, and a one-line grep pulls it straight out. jq
does the same. The CLI redaction protects your terminal scrollback; it does nothing for
the file. And that file ends up in backups, CI artifacts, a stolen laptop, or an
accidental git commit — anyone who reads it reads your secret. Hedge the value: yours
will be different. This exposure is exactly what S05, state encryption, exists to
close. (~5 min)
Then: "You'll grep that secret out with your own eyes in Lab 04, then encrypt it in
S05."
-->

---
layout: lab
lab: labs/day-1/04-state.md
duration: 20 min
env: 'mock ✓ (no docker)'
---

# Lab 04 — read and steer state

`apply` a config with a **generated DB password**, then inspect its state:
`state list`, `state show` (watch the secret get redacted), and — the payoff —
**`grep` the plaintext secret out of `terraform.tfstate`**. Migrate the state to
a new local path with `tofu init -migrate-state`, then **break** it with
`state rm` and reconcile with `apply`.

Every task and question has a `<details>` spoiler; panic reset is `tofu destroy`
plus `rm` — nothing cloud, nothing to leak.

<!--
Say: Set up the lab and its payoff moment. You apply a three-resource config that
includes a generated, sensitive DB password. Then you inspect state: state list for
the inventory, state show to watch the CLI redact the password, and the payoff — grep
the same password out of the raw terraform.tfstate as plaintext, the "oh, it really is
sitting there" moment. Then you migrate the state to a new local path with tofu init
-migrate-state — the real backend mechanic, cloud-free — and finally the break-fix:
state rm forgets a resource, plan wants to recreate it, and apply reconciles. Every
task and question has a spoiler; panic reset is destroy plus rm. (~20 min, matches the
lab duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: State — recap
story: 'State is the memory that makes a plan a diff — and a plaintext secret store until you encrypt it.'
next: 'Next: State encryption'
---

- **State** is the map from config to reality — the memory a `plan` reconciles
  against *desired* and *actual* to detect changes and **drift**.
- **Backends** hold it: `local` (a disk file, no locking) vs `remote` (shared,
  with **locking** so concurrent applies can't corrupt it). Switch with
  `tofu init -migrate-state`.
- **`tofu state`** reads and steers it: `list`, `show`, `mv` (rename), `rm`
  (forget → next `plan` recreates).
- **The risk:** `terraform.tfstate` is **plaintext JSON**. A `sensitive` value is
  redacted by the CLI but sits in the file as a literal — `grep` finds it.
- That plaintext secret is **exactly** what **S05 — state encryption** closes.

<!--
Say: Pull the threads together. State is the map from config to reality — the memory a
plan reconciles against desired and actual to catch both config changes and hand-made
drift. Backends hold it: local is a disk file with no locking; remote is shared storage
with locking so two applies can't corrupt each other, and you migrate with tofu init
-migrate-state. The tofu state subcommands read and steer it — list, show, mv to rename,
rm to forget. And the risk that motivates everything next: terraform.tfstate is plaintext
JSON, a sensitive value is redacted in the CLI but sits in the file as a literal string a
grep pulls straight out. (~2 min)
Then: transition into S05 — state encryption, which encrypts that file client-side.
-->
