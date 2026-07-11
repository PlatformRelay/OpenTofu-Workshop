# Lab 00 — Set up & first apply (S00)

| | |
| --- | --- |
| **Section** | S00 — Welcome & setup *(red line: **arrive** → author → test → scale)* |
| **Environment** | `localstack ✓` · `mock ✓` |
| **Estimated time** | 20 min |

## Objective

Get the toolchain working, run your first `tofu apply` against the `local`
provider, then bring up LocalStack and create your first **AWS** resource
(`aws_s3_bucket`) — proof the whole loop works before we go deep.

## Prerequisites

- Docker running (for LocalStack). Check: `docker info`.
- The repo cloned, with a terminal in its root.

## Files used

- `hello.tf` — a one-resource `local_file` project.
- `bucket.tf` — a LocalStack-backed `aws_s3_bucket`.

---

## Step 1 — Install the toolchain

```bash
task setup
```

**Task:** Confirm `tofu` is at least 1.8.

<details><summary>Solution / expected output</summary>

```console
$ tofu version
OpenTofu v1.10.3
```

If `task` is missing, `setup/bootstrap.sh` runs the same checks directly:
`bash setup/bootstrap.sh`.
</details>

---

## Step 2 — Your first plan & apply (no cloud)

```bash
mkdir -p ~/tofu-labs/00-setup && cd ~/tofu-labs/00-setup
cat > hello.tf <<'EOF'
resource "local_file" "hello" {
  content  = "hello, opentofu"
  filename = "${path.module}/hello.txt"
}
EOF

tofu init
tofu plan
tofu apply -auto-approve
```

**Task:** What did `apply` create, and where is the state?

<details><summary>Solution / expected output</summary>

```console
$ cat hello.txt
hello, opentofu

$ ls
hello.tf  hello.txt  terraform.tfstate
```

`apply` created `hello.txt` and recorded it in `terraform.tfstate`. The plan is
the diff between your config and that state.
</details>

---

## Step 3 — Bring up LocalStack

```bash
task lab:up          # or: docker compose up -d localstack
```

**Task:** Confirm LocalStack is healthy on port 4566.

<details><summary>Solution / expected output</summary>

```console
$ curl -s localhost:4566/_localstack/health | jq '.services.s3'
"available"
```

</details>

---

## Step 4 — Your first AWS resource (emulated)

```bash
cat > bucket.tf <<'EOF'
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints { s3 = "http://localhost:4566" }
}

resource "aws_s3_bucket" "first" {
  bucket = "my-first-tofu-bucket"
}
EOF

tofu init
tofu apply -auto-approve
```

**Task:** List the bucket through LocalStack to prove it exists.

<details><summary>Solution / expected output</summary>

```console
$ aws --endpoint-url http://localhost:4566 s3 ls
2026-07-11 10:00:00 my-first-tofu-bucket
```

(`awslocal s3 ls` is the shorthand if you installed it.) You just created a real
AWS resource type — with no account and no bill.
</details>

## Expected observations

- `tofu` runs `init → plan → apply` the same way for every provider.
- The `local` provider needs nothing; LocalStack gives you AWS shapes for free.
- State is written locally (we'll encrypt it in Lab 05).

## Cleanup / panic reset

```bash
cd ~/tofu-labs/00-setup && tofu destroy -auto-approve
task lab:down        # stop LocalStack
cd ~ && rm -rf ~/tofu-labs/00-setup
```

## Stretch (optional)

- Re-run `tofu apply` — note it reports "0 to add" (desired state already met).
- Add a `random_pet` resource and watch the plan show exactly one addition.
