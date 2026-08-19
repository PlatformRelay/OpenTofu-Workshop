# Lab 05 — Encrypt your state (S05)

| | |
| --- | --- |
| **Section** | S05 — State encryption *(red line: author → **protect** → test)* |
| **Environment** | `localstack ✓` · `mock ✓` · `real-aws (optional)` — this lab needs neither; it uses the `random` provider only |
| **Estimated time** | 25 min |

## Objective

Take the project you have been growing all day — now with **plaintext** local
state — and turn on OpenTofu's client-side
`encryption` block (PBKDF2), migrate the existing state with a `fallback`, and
**prove the file on disk is ciphertext**. Then flip `enforced = true` to ban any
unencrypted fallback, and confirm the state is inaccessible without the passphrase.

You run **tracked files**, not heredocs — what you apply is exactly what CI
verified. The config lives in this repo at `labs/day-1/05-state-encryption/`:

- `main.tf` — the project so far: the spine (`variable "service"`,
  `variable "environment"`, `local_file.manifest`, `output "manifest_path"`) plus
  the `random_password.session` whose generated value lives **only in state** — no
  file records it. That is the value encryption has to protect.
- `encryption.tf` — the OpenTofu `encryption` block (PBKDF2 → AES-GCM). This is
  the exact block S05 teaches; the slide and this file are drift-checked to stay
  byte-identical.

## Prerequisites

- `tofu` ≥ 1.8 (`task setup` installs it). Check: `tofu version`.
- `jq` for inspecting state (optional but used in a spoiler).
- Run everything **from the repo clone** — no Docker, no cloud.

## Files used

All tracked in `labs/day-1/05-state-encryption/` — you run them, you do not paste
them:

- `main.tf` — the plaintext-secret project: the spine plus
  `random_password.session`.
- `terraform.tfvars` — the auto-loaded `service` object and `environment`, carried
  forward from stage 6.
- `encryption.tf` — the client-side `encryption` block.
- `variables.tf` — declares the `state_passphrase` variable the block consumes.
- `.gitignore` — keeps the state/`.terraform`/`out/` you generate out of version
  control.

### Continuity — stage 7 of the `service-manifest` project

**Carried forward from stage 6** (`labs/day-1/04-state/`): all four spine
addresses — `variable "service"`, `variable "environment"`, `local_file.manifest`
and `output "manifest_path"` — plus the auxiliary `random_password.session`.
That matters here more than anywhere: the state you are about to encrypt is
**your own project's state**, holding the secret stage 6 grepped out of it in
plaintext.

**Deliberately retired here — three auxiliary blocks from stage 6, whose teaching
job is done:**

- `random_pet.env` — it existed at stage 6 to give `state list` a third entry to
  `show`, `mv` and `rm`. State surgery is taught; a smaller resource set makes the
  before/after of the encrypted envelope easier to read.
- `output "db_password"` — it made the point that `sensitive` redacts the CLI and
  not the file. That point is stage 6's; this stage *fixes* it instead of
  demonstrating it.
- the explicit `backend "local"` block — backend migration is taught; this lab
  migrates the state's **encryption**, not its location, and an explicit backend
  would confuse the two.

**Introduced here, and auxiliary:** `variable "state_passphrase"` (in
`variables.tf`, so Step 1 can move it aside) and the `encryption` block itself.

The lab drives these files through four stages by editing `encryption.tf`
**temporarily** (plaintext → migration → enforced) and then resetting it. The
tracked file is always the migrated, un-enforced canonical config.

---

## Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/05-state-encryption
ls
```

**Task:** Confirm the config files are already present — you author nothing.

<details><summary>Solution / expected output</summary>

```console
$ ls
encryption.tf  main.tf  terraform.tfvars  variables.tf
```

`main.tf`, `encryption.tf`, `variables.tf` and `terraform.tfvars` are tracked in
the repo. Everything below runs against these exact files.
</details>

---

## Step 1 — Make a secret land in state (plaintext first)

To see the *problem*, start from plaintext state. Temporarily move the encryption
block **and** its variable aside (a required, defaultless variable would otherwise
block a non-interactive apply), then `init` + `apply` so a secret lands in the
clear:

```bash
mv encryption.tf encryption.tf.off
mv variables.tf variables.tf.off
tofu init
tofu apply -auto-approve
```

**Task:** Find the generated password inside the plaintext state file.

<details><summary>Solution / expected output</summary>

```console
$ tofu state pull \
  | jq -r '.resources[] | select(.type=="random_password")
           | .instances[0].attributes.result'
S3cr3t-...-plaintext
```

The secret is sitting in `terraform.tfstate` in the clear. Anyone who reads the
file reads the password. Note *what* is exposed: your project's own state — the
same `local_file.manifest` and `random_password.session` you have been carrying
since stage 6, not a throwaway demo's.
</details>

---

## Step 2 — Turn on encryption (and hit the migration wall)

Bring the encryption block back and try to plan. This is the config S05 teaches —
`cat` it so you can read exactly what you're turning on:

<!-- source: labs/day-1/05-state-encryption/encryption.tf -->
```hcl
terraform {
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "secure" {
      keys = key_provider.pbkdf2.passphrase
    }
    state {
      method = method.aes_gcm.secure
      # enforced = true  # reject plaintext state
    }
    plan {
      method = method.aes_gcm.secure
      # enforced = true  # reject plaintext plan
    }
  }
}
```

```bash
mv encryption.tf.off encryption.tf
mv variables.tf.off variables.tf
cat encryption.tf
export TF_VAR_state_passphrase="correct-horse-battery-staple"
tofu plan -lock=false   # -lock=false so the encryption error shows plainly, not wrapped in a lock message
```

**Task:** What error do you get, and why?

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -lock=false
Error: error loading state: encountered unencrypted payload without unencrypted method configured
```

OpenTofu won't silently re-encrypt existing plaintext state — you must give it an
explicit one-time path from plaintext to ciphertext. That's the `fallback` block.
</details>

---

## Step 3 — Migrate with a `fallback`

Add an `unencrypted` method as a **fallback** so the next run can *read* plaintext
and *write* ciphertext. This is a **one-time** edit — you'll revert it in Step 5,
which is why it isn't the tracked default. Drop the fallback lines into
`encryption.tf` in place:

```bash
# Add a fallback method + wire it into state{} and plan{}. Applied once, then removed.
# (variables.tf still holds state_passphrase — we only edit encryption.tf here.)
cat > encryption.tf <<'EOF'
terraform {
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "secure" {
      keys = key_provider.pbkdf2.passphrase
    }
    method "unencrypted" "migrate" {}

    state {
      method = method.aes_gcm.secure
      fallback { method = method.unencrypted.migrate }
    }
    plan {
      method = method.aes_gcm.secure
      fallback { method = method.unencrypted.migrate }
    }
  }
}
EOF

tofu apply -auto-approve
```

**Task:** Confirm the apply succeeds by reading old plaintext through the fallback.

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

The apply reads the old plaintext state through the fallback and writes the new
state **encrypted**.
</details>

---

## Step 4 — Prove it's ciphertext

**Task:** Show that `terraform.tfstate` is no longer readable JSON.

<details><summary>Solution / expected output</summary>

```console
$ jq 'keys' terraform.tfstate
[
  "encrypted_data",
  "encryption_version",
  "lineage",
  "meta",
  "serial"
]

$ jq -r '.encrypted_data' terraform.tfstate | head -c 48
NfQ8k1p...base64-ciphertext...          # single opaque blob (illustrative)
```

The file is still valid JSON, but the `resources` array (which held the plaintext
password, and the manifest's recorded content) is gone — replaced by one `encrypted_data` envelope. `tofu` reads it
transparently because it has the passphrase; without it, the payload is opaque.
</details>

---

## Step 5 — Ban plaintext with `enforced`

Migration done — drop the fallback and turn on `enforced`. Restore the tracked
canonical config (fallback gone) and uncomment the `enforced = true` line:

```bash
git checkout -- encryption.tf          # back to the tracked, fallback-free config
sed -i.bak 's/# enforced = true/enforced = true/' encryption.tf && rm -f encryption.tf.bak
tofu apply -auto-approve                # re-encrypt under enforced; no fallback needed
```

**Task:** With `enforced = true`, what happens if a teammate clones the repo
without the passphrase and runs `tofu plan`?

<details><summary>Solution / expected output</summary>

```console
$ unset TF_VAR_state_passphrase
$ tofu plan -input=false
Error: Unable to compute static value

  on encryption.tf line 2, in terraform:
   2:   encryption {

encryption.key_provider.pbkdf2.passphrase depends on var.state_passphrase
which is not available
```

Without the passphrase, OpenTofu can't build the PBKDF2 key provider, so it can't
decrypt the state at all — and with `enforced = true` there is no unencrypted
fallback to slip through. No passphrase → no access. (Interactively, `tofu plan`
would *prompt* for the passphrase; `-input=false` turns that into the hard error
above — the non-interactive form a CI teammate would hit.)
</details>

## Expected observations

- A generated secret lands in **plaintext** state by default — and so does every
  attribute of every resource in your project.
- `encryption` (PBKDF2) needs a one-time `fallback` to migrate existing state.
- After migration the on-disk file is an **encrypted envelope** — still valid JSON,
  but the resource data is one opaque `encrypted_data` blob.
- `enforced = true` bans any unencrypted fallback; without the passphrase the
  encrypted state can't be read at all.

## Cleanup / panic reset

Destroy the (local-only) resources and restore the tracked files to a pristine
state — no residue, `git status` clean:

```bash
cd labs/day-1/05-state-encryption
export TF_VAR_state_passphrase="correct-horse-battery-staple"
git checkout -- encryption.tf                          # restore canonical config first
tofu destroy -auto-approve                             # tear down the project
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.* out \
  encryption.tf.off variables.tf.off encryption.tf.bak
git status --short labs/day-1/05-state-encryption      # expect: no output
```

No cloud resources are created in this lab, so there is nothing to bill or leak.
The generated state/`.terraform` are gitignored; the panic reset leaves the
tracked files exactly as CI verified them.

## Stretch (optional)

- Swap the `pbkdf2` key provider for `aws_kms` pointed at LocalStack's KMS
  (`task lab:up` first) and re-migrate — same `fallback` trick, a real key.
- Rotate the passphrase: put the old key in `fallback`, the new key in the primary
  method, `apply` once, then drop the fallback.
