# Local toolchain & LocalStack

Get from a fresh laptop to a lab-ready environment. Labs use
[`mock_provider`](https://opentofu.org/docs/cli/test/) or
[LocalStack](https://localstack.cloud) — an AWS emulator on your machine. You need
**no cloud account and incur no cloud bill**.

## One command: `task setup`

From the repository root:

```bash
task setup
```

That runs `setup/bootstrap.sh` (detects tools, prints versions, guides installs)
and `pnpm install` for the decks. It is safe to rerun and never installs without
confirmation. The report has three tiers:

1. **Required** — OpenTofu, Node, pnpm, Task. Missing or below the floor: exit 1.
2. **Day-1 LocalStack route** — Labs 00 (Steps 3–4), 08 (Step 4) and 10, plus
   the optional LocalStack steps of Labs 04 and 05, need LocalStack. Ready when
   the Docker daemon answers (`docker info`; an installed but stopped Docker
   does not count) or when `kubectl` has a current context whose API answers
   (the Docker-free `task lab:up:k8s` route). Neither: setup still finishes
   (exit 0, so `pnpm install` runs) but prints `LocalStack route NOT READY`
   and names the blocked labs. Fix it before Lab 00 Step 3.
3. **Day-2/3 tools** — an advisory naming the labs they affect.

`task preflight:strict` (`BOOTSTRAP_STRICT=1 bash setup/bootstrap.sh`) turns
tiers 2 and 3 into a failure (exit code 3); the facilitator runs it the evening
before each day. `task setup` never runs strict.

No Task? The bootstrap script alone is enough for the CLI tools:

```bash
bash setup/bootstrap.sh
corepack enable && corepack prepare pnpm@11.9.0 --activate
pnpm install --frozen-lockfile
```

## Prerequisites by workshop day

| Scope | Tools |
| --- | --- |
| Decks and Day 1 (required) | OpenTofu ≥1.9, Node.js ≥20, pnpm, Task |
| Day 1 LocalStack labs (00, 08, 10) | Docker with the daemon running — or the Docker-free route: `task lab:up:k8s` |
| Day 2 static analysis | TFLint |
| Day 2 security and policy | Trivy, Checkov, Conftest |
| Day 3 scale labs | Terramate |
| Optional Terratest (S18) | Docker (container lane) — or host Go ≥1.25 |

### One floor, one pin, honest spoilers

- **Floor** — what the labs require: OpenTofu **≥1.9**, enforced by
  `task setup` and the repo's verify gate. One documented exception: Lab 04's
  *optional* S3 stretch needs ≥1.10 (`use_lockfile`) and says so inline.
- **Pin** — what CI and the container lane actually run: **1.10.3**, from
  [`versions.env`](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/versions.env),
  the single pin file. The pin satisfies the floor (and the Lab 04 stretch).
- **Spoilers** — each lab's pasted output states the OpenTofu version that
  actually produced it, which may be newer than the pin (1.12.x captures are
  common). Version banners in *your* output will show *your* version; every
  behaviour the labs assert holds on any tofu at or above the floor.

`gum`, `awslocal`, and the AWS CLI improve the local experience but are optional.
Go is **not** installed by default. Terratest is container-first — see the
[README](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/README.md)
and [ADR 0011](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/docs/decisions/0011-toolchain-lanes.md).

## LocalStack for labs

Start the emulator before any lab marked for LocalStack:

```bash
task lab:up          # Docker Compose → http://localhost:4566
# Docker-free alternative (kind / existing kube context):
task lab:up:k8s
```

Health check: <http://localhost:4566/_localstack/health>

Stop and wipe volumes (clean slate — `PERSISTENCE=0`):

```bash
task lab:down
# or: task lab:down:k8s
```

Full troubleshooting (image pin **4.9.2**, panic reset, k8s path):
[setup/localstack.md](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/setup/localstack.md)
on GitHub.

## Next steps

| Goal | Link |
| --- | --- |
| First lab | [Lab 00: setup](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/00-setup.md) |
| All labs by day | [Labs index](labs.md) |
| Serve the 3-day deck | [Run the slides locally](run-slides.md) (`task dev:3day`) |
| Facilitate | [Facilitator runbook](facilitator-runbook.md) |
