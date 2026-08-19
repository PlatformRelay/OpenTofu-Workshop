# Lab 05 — Encrypt your state (S05) — solutions

Use this companion after attempting the participant lab. Compare state and meaning
rather than copying ephemeral resource names, IDs, or timestamps literally.

## Guided solutions

Work from the tracked workdir `labs/day-1/05-state-encryption/` unless a step says otherwise.

### Step 0 — Enter the tracked workdir

```bash
cd labs/day-1/05-state-encryption
ls
```

**Task:** Confirm the config files are already present — you author nothing.

---

<details><summary>Solution / expected output</summary>

```console
$ ls
encryption.tf  main.tf  terraform.tfvars  variables.tf
```

`main.tf`, `encryption.tf`, `variables.tf` and `terraform.tfvars` are tracked in
the repo. Everything below runs against these exact files.

</details>

---

### Step 1 — Make a secret land in state (plaintext first)

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

---

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

### Step 2 — Turn on encryption (and hit the migration wall)

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

---

<details><summary>Solution / expected output</summary>

```console
$ tofu plan -lock=false
Error: error loading state: encountered unencrypted payload without unencrypted method configured
```

OpenTofu won't silently re-encrypt existing plaintext state — you must give it an
explicit one-time path from plaintext to ciphertext. That's the `fallback` block.

</details>

---

### Step 3 — Migrate with a `fallback`

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

---

<details><summary>Solution / expected output</summary>

```console
$ tofu apply -auto-approve
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

The apply reads the old plaintext state through the fallback and writes the new
state **encrypted**.

</details>

---

### Step 4 — Prove it's ciphertext

**Task:** Show that `terraform.tfstate` is no longer readable JSON.

---

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

### Step 5 — Ban plaintext with `enforced`

Migration done — drop the fallback and turn on `enforced`. Restore the tracked
canonical config (fallback gone) and uncomment the `enforced = true` line:

```bash
git checkout -- encryption.tf          # back to the tracked, fallback-free config
sed -i.bak 's/# enforced = true/enforced = true/' encryption.tf && rm -f encryption.tf.bak
tofu apply -auto-approve                # re-encrypt under enforced; no fallback needed
```

**Task:** With `enforced = true`, what happens if a teammate clones the repo
without the passphrase and runs `tofu plan`?

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

## Expected state / output

- A generated secret lands in **plaintext** state by default — and so does every
  attribute of every resource in your project.
- `encryption` (PBKDF2) needs a one-time `fallback` to migrate existing state.
- After migration the on-disk file is an **encrypted envelope** — still valid JSON,
  but the resource data is one opaque `encrypted_data` blob.
- `enforced = true` bans any unencrypted fallback; without the passphrase the
  encrypted state can't be read at all.

Representative console output from the inline spoilers above applies when your
toolchain versions match the lab pin.

## Explanation

OpenTofu reconciles declared configuration against stored state on every plan and
apply, so the commands above succeed only when the tracked HCL, provider plugins,
and backend settings match what the lab authored. Each step therefore wires inputs
(outputs, variables, modules, or data sources) before the resources that consume
them, because the graph must be acyclic at evaluation time.

When a step reads remote or emulated cloud APIs (LocalStack or mock providers), the
provider block binds credentials and endpoints first; resources then call those APIs
and persist returned attributes into state. That is why init/plan/apply ordering
matters and why re-running apply without changes reports zero additions.

## Troubleshooting and recovery

If a step fails mid-lab, prefer the documented panic reset before editing tracked files by hand:

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

Re-enter `labs/day-1/05-state-encryption/` and replay from the failing step once the environment is clean. For provider or module download errors, run `tofu init -upgrade` in the workdir and retry `tofu plan`.

## Stretch solution

### Commands / manifest

- Swap the `pbkdf2` key provider for `aws_kms` pointed at LocalStack's KMS
- Rotate the passphrase: put the old key in `fallback`, the new key in the primary

Example verification from the workdir:

```bash
cd labs/day-1/05-state-encryption
tofu plan
```

### Expected state / output

When the stretch applies cleanly, `tofu plan` afterward shows no further changes and stretch-specific outputs appear in state as described in the spoiler blocks above.

### Explanation

Stretch tasks extend the same exercise with additional constraints or outputs; they
remain optional because they reuse the core method and only deepen the analysis once
the guided path already converged.
