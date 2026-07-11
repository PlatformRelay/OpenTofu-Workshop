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

---
layout: statement
kicker: 'The problem'
---

`terraform.tfstate` stores **resolved values** — passwords, keys, tokens — in
**plaintext JSON**. So does every plan file.

Anyone who reads the file reads your secrets.

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
