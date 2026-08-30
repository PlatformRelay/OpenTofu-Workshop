# Lab 05 — Encrypt your state (S05)

| | |
| --- | --- |
| **Section** | S05 — State encryption *(red line: author → **protect** → test)* |
| **Environment** | `localstack ✓` · `mock ✓` · `real-aws (optional)` — Steps 0–5 need neither Docker nor cloud (`random` provider only); optional Step 6 uses LocalStack's KMS |
| **Estimated time** | 25 min core path · +10 min optional Step 6 (KMS) |

## Objective

Take the project you have been growing all day — now with **plaintext** local
state — and turn on OpenTofu's client-side
`encryption` block (PBKDF2), migrate the existing state with a `fallback`, and
**prove the file on disk is ciphertext**. Then flip `enforced = true` to ban any
unencrypted fallback, and confirm the state is inaccessible without the passphrase.
Optional Step 6 then swaps the passphrase for the production-shaped key path: an
`aws_kms` key provider against LocalStack's KMS, migrated with the same
`fallback` mechanism you just learned.

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

- `tofu` ≥ 1.9 (`task setup` installs it). Check: `tofu version`.
- `jq` for inspecting state (optional but used in a spoiler).
- Docker — **optional Step 6 only**, for LocalStack's KMS. Check: `docker version`.
- Run everything **from the repo clone** — Steps 0–5 need no Docker and no cloud.

## Files used

All tracked in `labs/day-1/05-state-encryption/` — you run them, you do not paste
them:

- `main.tf` — the plaintext-secret project: the spine plus
  `random_password.session`.
- `terraform.tfvars` — the auto-loaded `service` object and `environment`, carried
  forward from stage 6.
- `encryption.tf` — the client-side `encryption` block.
- `variables.tf` — declares the `state_passphrase` variable the block consumes.
- `encryption-kms.tf.off` — the KMS variant of the encryption block (optional
  Step 6 copies it over `encryption.tf`; the `.off` suffix keeps it inert until
  then).
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
`variables.tf`, so Step 1 can move it aside), the `encryption` block itself, and —
for optional Step 6 — the tracked KMS variant `encryption-kms.tf.off` with its
own `kms_key_id` variable.

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
encryption-kms.tf.off  encryption.tf  main.tf  terraform.tfvars  variables.tf
```

`main.tf`, `encryption.tf`, `variables.tf`, `terraform.tfvars` and the optional
Step 6 KMS variant `encryption-kms.tf.off` are tracked in the repo. Everything
below runs against these exact files.
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

---

## Step 6 — Optional: swap the passphrase for a real key (LocalStack KMS)

*Optional — needs Docker. Skip straight to Expected observations if you have no
Docker; nothing later depends on this step.*

A passphrase is a lab device. Production hands key custody to a key service —
`aws_kms`, `gcp_kms`, or `openbao` — and this step does exactly that against
LocalStack's KMS: create a key, switch the primary `key_provider`, and migrate
with the **same `fallback` mechanism Step 3 taught**, this time from one
*encrypted* method to another.

The variant config is tracked as `encryption-kms.tf.off` — `cat` it before
activating; the fence below is drift-checked against the file:

<!-- source: labs/day-1/05-state-encryption/encryption-kms.tf.off -->
```hcl
# KMS variant of encryption.tf — Step 6 activates it with `cp`, and
# `git checkout -- encryption.tf` reverts it (this file itself never changes).
# Primary key from AWS KMS (LocalStack in the lab); the PBKDF2 passphrase stays
# on as the fallback so one apply can READ passphrase-encrypted state and WRITE
# it re-keyed under KMS — Step 3's migration mechanism, pointed at a real key.

variable "kms_key_id" {
  type        = string
  description = "KMS key id for state encryption (Step 6 exports TF_VAR_kms_key_id)."
}

terraform {
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    key_provider "aws_kms" "workshop" {
      kms_key_id = var.kms_key_id
      key_spec   = "AES_256"
      region     = "us-east-1"

      # LocalStack has no real IAM/STS; skip that handshake (same rationale as
      # examples/naming-labels-demo). The endpoint itself comes from
      # AWS_ENDPOINT_URL, exported in Step 6.
      skip_credentials_validation = true
    }
    method "aes_gcm" "kms" {
      keys = key_provider.aws_kms.workshop
    }
    method "aes_gcm" "passphrase" {
      keys = key_provider.pbkdf2.passphrase
    }
    state {
      method = method.aes_gcm.kms
      fallback { method = method.aes_gcm.passphrase }
    }
    plan {
      method = method.aes_gcm.kms
      fallback { method = method.aes_gcm.passphrase }
    }
  }
}
```

### 6a — Bring up LocalStack and create a key

KMS is already in the compose file's `SERVICES` list. The `awslocal` CLI ships
inside the container, so `docker exec` works without installing anything (if you
have `awslocal` on your PATH, call it directly instead):

```bash
task lab:up                                   # start LocalStack on :4566
cd labs/day-1/05-state-encryption
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566
KEY_ID=$(docker exec opentofu-workshop-localstack \
  awslocal kms create-key --description "lab05 state key" \
  --query KeyMetadata.KeyId --output text)
echo "$KEY_ID"
```

**Task:** Confirm you got a key id back.

<details><summary>Solution / expected output</summary>

```console
$ echo "$KEY_ID"
090770fe-ae7e-4620-a95e-abc73be09880
```

A UUID (yours differs). LocalStack accepts any credentials — `test`/`test` is
convention — and `AWS_ENDPOINT_URL` is how the `aws_kms` key provider will find
the emulator instead of real AWS.
</details>

### 6b — Activate the variant and hit the wrong-key wall (break → fix)

Copy the variant over `encryption.tf`, but wire in a **deliberately wrong** key
id first — see what a bad key reference actually looks like before trusting the
real one:

```bash
cp encryption-kms.tf.off encryption.tf        # activate; revert = git checkout
export TF_VAR_state_passphrase="correct-horse-battery-staple"   # still the fallback
export TF_VAR_kms_key_id="00000000-0000-0000-0000-000000000000" # wrong on purpose
tofu plan -input=false -lock=false
```

**Task:** Read the error. Which side failed — reading the old state, or keying
the new one?

<details><summary>Solution / expected output</summary>

Verbatim OpenTofu 1.12.5 transcript against LocalStack 4.9.2 (request IDs vary):

```console
$ tofu plan -input=false -lock=false
Error: Unable to fetch encryption key data

key_provider.aws_kms.workshop failed with error: failed to generate key:
operation error KMS: GenerateDataKey, https response error StatusCode: 400,
RequestID: c77e98d0-bcf3-4985-8fc4-d277a60f703b, NotFoundException: Key
'arn:aws:kms:us-east-1:000000000000:key/00000000-0000-0000-0000-000000000000'
does not exist
```

The **new primary** failed: OpenTofu asked KMS to `GenerateDataKey` under the
key id you gave it, and KMS has no such key. The pbkdf2 `fallback` is unharmed —
your state is still readable the moment the primary is fixed. That is the same
protection it gave in Step 3, now guarding a key-service typo instead of a
plaintext migration.
</details>

### 6c — Fix the key id and migrate

```bash
export TF_VAR_kms_key_id="$KEY_ID"
tofu apply -auto-approve
```

**Task:** Confirm the apply re-keys the state under KMS.

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

Zero resource changes — exactly like Step 3, the only thing that changed hands
is the **key**: the apply read the passphrase-encrypted state through the
fallback and wrote it back encrypted under the KMS data key.
</details>

### 6d — Verify: ciphertext on disk, and the passphrase is now powerless

```bash
jq 'keys' terraform.tfstate
jq -r '.meta | keys[]' terraform.tfstate
export TF_VAR_state_passphrase="definitely-not-the-passphrase"
tofu state pull \
  | jq -r '.resources[] | select(.type=="random_password")
           | .instances[0].attributes.result'
```

**Task:** The file must still be an encrypted envelope — but which provider does
its metadata name now, and why does a *wrong passphrase* no longer lock you out?

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

$ jq -r '.meta | keys[]' terraform.tfstate
key_provider.aws_kms.workshop

$ tofu state pull \
  | jq -r '.resources[] | select(.type=="random_password")
           | .instances[0].attributes.result'
S3cr3t-...-your-generated-value
```

Same opaque envelope as Step 4 — but the metadata now names
`key_provider.aws_kms.workshop`, and the decrypt succeeded even though the
exported passphrase is wrong: key custody genuinely moved from the passphrase to
KMS. (The variable still has to be *set* because the fallback block references
it; its value no longer matters for reading KMS-keyed state.)

> **The key IS the state now.** The compose file runs LocalStack with
> `PERSISTENCE: "0"`, so a container restart discards the key — after that, this
> state is *permanently undecryptable* (re-run the plan and KMS answers
> `NotFoundException` for your key id). Harmless here — everything the lab
> manages is a local file and the panic reset below removes the state — but it
> is the real production lesson: protect and back up KMS keys like the state
> they unlock.
</details>

**Before you leave the step:** destroy *now*, while `encryption.tf` still holds
the KMS config that can read this state — the canonical passphrase config you
will restore in Cleanup cannot:

```bash
tofu destroy -auto-approve
```

---

## Expected observations

- A generated secret lands in **plaintext** state by default — and so does every
  attribute of every resource in your project.
- `encryption` (PBKDF2) needs a one-time `fallback` to migrate existing state.
- After migration the on-disk file is an **encrypted envelope** — still valid JSON,
  but the resource data is one opaque `encrypted_data` blob.
- `enforced = true` bans any unencrypted fallback; without the passphrase the
  encrypted state can't be read at all.
- (Step 6) The **same `fallback` mechanism** migrates between *keys*, not just
  from plaintext: primary `aws_kms`, fallback pbkdf2, one apply — and key
  custody moves to the key service. Lose the KMS key, lose the state.

## Cleanup / panic reset

Destroy the (local-only) resources and restore the tracked files to a pristine
state — no residue, `git status` clean. The destroy runs **first**, while
`encryption.tf` still matches whatever stage your state is in — the canonical
config restored by `git checkout` cannot read every stage's state (KMS-keyed
state after Step 6, or Step 1's plaintext). If it fails anyway — wrong shell,
key gone — that is harmless: everything this lab manages is local, and the `rm`
line removes it:

```bash
cd labs/day-1/05-state-encryption
export TF_VAR_state_passphrase="correct-horse-battery-staple"
tofu destroy -auto-approve || true                     # under the config you last applied with
git checkout -- encryption.tf                          # back to the canonical passphrase config
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.* out \
  encryption.tf.off variables.tf.off encryption.tf.bak
git status --short labs/day-1/05-state-encryption      # expect: no output
```

If you ran Step 6, finish with:

```bash
task lab:down          # stop LocalStack; PERSISTENCE=0 discards the KMS key with it
```

No cloud resources are created in this lab, so there is nothing to bill or leak.
The generated state/`.terraform` are gitignored; the panic reset leaves the
tracked files exactly as CI verified them.

## Stretch (optional)

- Rotate the passphrase: put the old key in `fallback`, the new key in the primary
  method, `apply` once, then drop the fallback — the Step 3/Step 6 migration
  mechanism, applied a third way.
