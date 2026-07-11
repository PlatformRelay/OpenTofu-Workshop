# Lab 05 — Encrypt your state (S05)

| | |
| --- | --- |
| **Section** | S05 — State encryption *(red line: author → **protect** → test)* |
| **Environment** | `localstack ✓` · `mock ✓` · `real-aws (optional)` — this lab needs neither; it uses the `local` provider only |
| **Estimated time** | 25 min |

## Objective

Take a project with **plaintext** local state, turn on OpenTofu's client-side
`encryption` block (PBKDF2), migrate the existing state with a `fallback`, and
**prove the file on disk is ciphertext**. Then flip `enforced = true` and watch a
plaintext read get rejected.

## Prerequisites

- `tofu` ≥ 1.8 (`task setup` installs it). Check: `tofu version`.
- `jq` for inspecting state (optional but used in a spoiler).

## Files used

- `main.tf` — a tiny project (one `random_password`, written to disk) that puts a
  secret **into state**. Carried forward: S06 extends the same folder.
- `terraform.tfstate` — the state file you'll encrypt.

---

## Step 1 — Make a secret land in state

Create the working folder and a project whose state will contain a secret:

```bash
mkdir -p ~/tofu-labs/05-encryption && cd ~/tofu-labs/05-encryption
cat > main.tf <<'EOF'
terraform {
  required_providers {
    random = { source = "hashicorp/random" }
  }
}

# A generated secret — the kind of value that ends up in state as plaintext.
resource "random_password" "db" {
  length = 20
}
EOF

tofu init
tofu apply -auto-approve
```

**Task:** Find the generated password inside the plaintext state file.

<details><summary>Solution / expected output</summary>

```console
$ tofu state pull | jq '.resources[0].instances[0].attributes.result'
"S3cr3t-...-plaintext"
```

The secret is sitting in `terraform.tfstate` in the clear. Anyone who reads the
file reads the password.
</details>

---

## Step 2 — Turn on encryption (and hit the migration wall)

Add an `encryption` block and try to plan:

```bash
cat > encryption.tf <<'EOF'
variable "state_passphrase" {
  type      = string
  sensitive = true
}

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
  }
}
EOF

export TF_VAR_state_passphrase="correct-horse-battery-staple"
tofu plan
```

**Task:** What error do you get, and why?

<details><summary>Solution / expected output</summary>

```console
│ Error: Encountered unexpected encryption method
│ The state file already exists as plaintext, but the configuration now
│ requires it to be encrypted.
```

OpenTofu won't silently re-encrypt existing plaintext state — you must give it an
explicit one-time path from plaintext to ciphertext. That's the `fallback` block.
</details>

---

## Step 3 — Migrate with a `fallback`

Add an `unencrypted` method as a **fallback** so the next run can *read* plaintext
and *write* ciphertext:

```bash
cat > encryption.tf <<'EOF'
variable "state_passphrase" {
  type      = string
  sensitive = true
}

terraform {
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "secure" {}
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
# aes_gcm needs its key wired — set it via the method's keys arg:
```

> **Note:** `method "aes_gcm" "secure" {}` needs `keys = key_provider.pbkdf2.passphrase`.
> Put it back — it was dropped above only to keep the diff readable.

**Task:** Fix the `aes_gcm` method to reference the key, then `apply`.

<details><summary>Solution / expected output</summary>

The `aes_gcm` block must be:

```hcl
method "aes_gcm" "secure" {
  keys = key_provider.pbkdf2.passphrase
}
```

Then:

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
$ jq . terraform.tfstate
parse error: Invalid numeric literal at line 1, column 10

$ head -c 120 terraform.tfstate
{"encrypted_data":"aQh9...base64-ciphertext...","encryption_version":"v0"}
```

The secret is gone from plaintext — the file is an encrypted envelope. `tofu`
still reads it transparently because it has the passphrase.
</details>

---

## Step 5 — Ban plaintext with `enforced`

Once migrated, remove the fallback and add `enforced = true`:

```bash
# In encryption.tf: delete the two `fallback { ... }` lines and the
# `method "unencrypted" "migrate" {}` line, then add `enforced = true`
# just inside `encryption {`.
```

**Task:** With `enforced = true`, what happens if a teammate clones the repo
without the passphrase and runs `tofu plan`?

<details><summary>Solution / expected output</summary>

```console
$ unset TF_VAR_state_passphrase
$ tofu plan
│ Error: No key provider could produce a key ... encryption is enforced
```

`enforced = true` refuses to read or write plaintext at all. No passphrase → no
access. That's the guarantee you want in a shared repo.
</details>

## Expected observations

- A generated secret lands in **plaintext** state by default.
- `encryption` (PBKDF2) needs a one-time `fallback` to migrate existing state.
- After migration the on-disk file is an **encrypted envelope**, not JSON.
- `enforced = true` rejects any plaintext read/write.

## Cleanup / panic reset

```bash
cd ~/tofu-labs/05-encryption
export TF_VAR_state_passphrase="correct-horse-battery-staple"
tofu destroy -auto-approve
cd ~ && rm -rf ~/tofu-labs/05-encryption
```

No cloud resources are created in this lab, so there is nothing to bill or leak.

## Stretch (optional)

- Swap the `pbkdf2` key provider for `aws_kms` pointed at LocalStack's KMS
  (`task lab:up` first) and re-migrate — same `fallback` trick, a real key.
- Rotate the passphrase: put the old key in `fallback`, the new key in the primary
  method, `apply` once, then drop the fallback.
