---
layout: section-cover
image: /covers/placeholder-section.svg
day: Day 1
section: '05'
tier: recommended
---

# State encryption

Your state file is a plaintext database of everything you built — including
secrets. OpenTofu can encrypt it before it ever touches disk.

<!--
Say: Frame the section with the hook — your state file is a plaintext database of
everything you built, secrets included, and OpenTofu can encrypt it client-side
before it ever touches disk. This is one of the smallest configs with the biggest
payoff, and it's an OpenTofu-only headline feature. (~1 min)
Then: "Let's make the problem concrete first" — into what's actually in that file.
-->

---
layout: statement
kicker: 'The problem'
---

`terraform.tfstate` stores **resolved values** — passwords, keys, tokens — in
**plaintext JSON**. So does every plan file.

Anyone who reads the file reads your secrets.

<!--
Say: Land the core problem hard. terraform.tfstate is plaintext JSON, and it holds
RESOLVED values — a generated DB password or provider token is sitting there as a
literal string, not a reference. Every saved plan file has the same exposure.
Bottom line: anyone who can read the file can read your secrets. (~2 min)
Then: "Let's be specific about the three things that leak."
-->

---

<span class="kw-kicker">Why it matters</span>

# What leaks through state

<div class="kw-cols-3 mt-4">
  <KwCard heading="Secrets" kind="state" variant="danger">
    <strong>Resolved.</strong> DB passwords, generated keys, and provider tokens
    land in state as literal strings.
  </KwCard>
  <KwCard heading="Topology" kind="state" variant="warn">
    <strong>Mapped.</strong> Every resource, ID, and relationship — a blueprint
    of your estate for an attacker.
  </KwCard>
  <KwCard heading="Plans too" kind="encryption" variant="warn">
    <strong>Same risk.</strong> A saved plan file contains the same resolved
    values. Encrypt both.
  </KwCard>
</div>

<div v-click class="mt-6 kw-muted text-sm">

Remote backends encrypt <em>in transit</em> and <em>at rest on the server</em> —
but the file is still plaintext the moment `tofu` writes or reads it locally.

</div>

<!--
Say: Three leak vectors. Secrets — resolved passwords, keys, tokens as literals.
Topology — every resource, ID, and relationship is a blueprint of the estate for
an attacker. Plans too — a saved plan carries the same resolved values, so encrypt
both. Then defuse the common objection with the click reveal: remote backends
encrypt in transit and at rest on the server, but the file is still plaintext the
instant tofu reads or writes it locally — that local window is what client-side
encryption closes. (~3 min)
Then: "Here's the block that fixes all of this."
-->

---
layout: code-annotated
heading: The encryption block — client-side, OpenTofu-native
lab: labs/day-1/05-state-encryption.md
---

```hcl {none|1-2|3-5|6-8|9-10|12|all}
terraform {
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "secure" {
      keys = key_provider.pbkdf2.passphrase
    }
    state { method = method.aes_gcm.secure }
    plan  { method = method.aes_gcm.secure }

    # enforced = true  # reject any plaintext state/plan
  }
}
```

::notes::

<CodeNote at="1" label="encryption {}">
  A top-level OpenTofu block since <strong>1.7</strong>. No Terraform equivalent
  — this is a headline differentiator.
</CodeNote>

<CodeNote at="2" label="key_provider &quot;pbkdf2&quot;">
  Derives a key from a passphrase. Cloud-free — ideal for a lab. Production
  swaps in <code>aws_kms</code>, <code>gcp_kms</code>, or <code>openbao</code>.
</CodeNote>

<CodeNote at="3" label="method &quot;aes_gcm&quot;" variant="ok">
  Authenticated encryption over the derived key. State and plan become ciphertext.
</CodeNote>

<CodeNote at="4" label="state + plan" variant="warn">
  Wire the method into <strong>both</strong>. A plan leaks as much as state.
</CodeNote>

<CodeNote at="5" label="enforced" variant="danger">
  Flip on to <strong>reject</strong> any unencrypted read/write — no accidental
  plaintext once you've migrated.
</CodeNote>

<!--
Say: This is the whole feature in one block. Walk the clicks: encryption {} is a
top-level OpenTofu block (1.7+) with no Terraform equivalent; a key_provider
derives the key (PBKDF2 from a passphrase here, cloud-free for the lab); a method
does authenticated AES-GCM; then wire that method into BOTH state and plan —
stress that a plan leaks the same resolved values as state. The commented
enforced = true is the safety flip we return to after migrating. (~6 min)
Then: "But you already have plaintext state on disk — how do you migrate without
locking yourself out?" — leads into the fallback slide.
-->

---
layout: two-cols-code
heading: Migrating existing state
---

````md magic-move
```console
$ tofu plan
╷
│ Error: can not read plaintext state,
│ encryption is enforced
```

```hcl
encryption {
  # ...key_provider + method as before...

  method "unencrypted" "migrate" {}

  state {
    method = method.aes_gcm.secure
    fallback { method = method.unencrypted.migrate }
  }
}
```

```console
$ tofu apply     # reads plaintext via fallback,
                 # writes ciphertext going forward
$ # then remove the fallback block — done.
```
````

::right::

<div class="mt-4">
  <KwCard heading="fallback" kind="encryption">
    <strong>Read old, write new.</strong> The <code>fallback</code> block lets a
    one-time run read plaintext (or an old key) while writing with the new method.
  </KwCard>
  <div class="mt-3">
  <KwCard heading="Key rotation" kind="encryption" variant="ok">
    <strong>Same trick.</strong> Put the old key in <code>fallback</code>, the new
    key in the primary method, apply once, then drop the fallback.
  </KwCard>
  </div>
</div>

<!--
Say: The obvious worry: "I already have plaintext state — won't enforced lock me
out?" Walk the magic-move. First, plan errors: can't read plaintext, encryption is
enforced. The fix is a fallback block pointing at method.unencrypted.migrate —
that lets ONE apply read the old plaintext while writing ciphertext going forward;
then you delete the fallback and you're done. Point at the right rail: the exact
same fallback trick is how you rotate keys — old key in fallback, new key primary,
apply once, drop it. (~4 min)
Then: "So where does Terraform stand on this?"
-->

---
layout: comparison
heading: State encryption — OpenTofu vs Terraform
leftHeading: OpenTofu
rightHeading: Terraform
leftBadge: '1.7+'
rightBadge: 'n/a'
---

- **Client-side** state *and* plan encryption, built in
- Key providers: PBKDF2 · AWS KMS · GCP KMS · OpenBao · external
- `fallback` for migration + key rotation
- `enforced = true` bans plaintext

::right::

- No built-in client-side state encryption
- Relies on backend at-rest encryption (server-side)
- Plaintext on the local disk during every run
- Third-party wrappers only

<!--
Say: This is the differentiator slide. OpenTofu (1.7+) has built-in client-side
encryption of state AND plan, multiple key providers (PBKDF2, AWS KMS, GCP KMS,
OpenBao, external), fallback for migration and rotation, and enforced = true to
ban plaintext. Terraform has none of it client-side — it leans on backend at-rest
encryption, leaves plaintext on the local disk every run, and needs third-party
wrappers. This is the concrete reason a security-conscious team picks OpenTofu.
(~2 min)
Then: "Now do it yourself — Lab 05."
-->

---
layout: lab
lab: labs/day-1/05-state-encryption.md
duration: 25 min
env: 'localstack ✓ · mock ✓ · real-aws (optional)'
---

# Lab 05 — encrypt your state

Start from a plaintext local state, add a PBKDF2 `encryption` block, migrate with
a `fallback`, and **prove the file on disk is ciphertext** with `cat` and `jq`.
Then flip `enforced = true` and watch a plaintext read get rejected.

Every task has a `<details>` spoiler; panic reset is `task lab:down`.

<!--
Say: Set up the lab and its payoff moment. Start from plaintext state, add the
PBKDF2 encryption block, migrate with a fallback, then actually cat and jq the file
to see it's ciphertext — that "oh, it really is scrambled" moment is the point.
Finally flip enforced = true and watch a plaintext read get rejected on purpose.
Every task has a spoiler; panic reset is task lab:down. (~25 min, matches the lab
duration)
Then: regroup for the recap.
-->

---
layout: recap
heading: State encryption — recap
story: 'State is a plaintext secret store — until you make it ciphertext.'
next: 'Next: Variables, validation & types'
---

- State **and** plan files hold resolved secrets in plaintext by default.
- OpenTofu's `terraform { encryption }` (1.7+) encrypts them **client-side** —
  no Terraform equivalent.
- **PBKDF2** for labs; **KMS/OpenBao** for production.
- `fallback` migrates and rotates keys; `enforced = true` bans plaintext.
- This ties into **S08** — the naming/labelling demo ships with encryption on.

<!--
Say: Pull the five threads together — state and plan hold resolved secrets in
plaintext by default; OpenTofu's terraform { encryption } (1.7+) fixes it
client-side with no Terraform equivalent; PBKDF2 for labs, KMS/OpenBao for prod;
fallback migrates and rotates; enforced = true bans plaintext. Call forward: the
flagship naming/labelling demo in S08 ships with encryption already on, so this
isn't a one-off — it's the baseline. (~2 min)
Then: transition into Variables, validation & types.
-->

