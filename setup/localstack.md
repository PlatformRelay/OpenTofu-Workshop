# LocalStack in this workshop

Every lab is **local-first**: instead of a real AWS account, the labs target
[LocalStack](https://www.localstack.cloud/), an AWS emulator that runs in a
local container — via Docker Compose **or** a local Kubernetes cluster (no
Docker required, see below). No cloud account, no credentials, no bill.

> **Version pin.** The workshop pins `localstack/localstack:4.9.2` — the last
> LocalStack **community** release that boots without a license. The 2026
> CalVer images (`:latest`, `:stable` since ~2026-07) exit on startup
> demanding a `LOCALSTACK_AUTH_TOKEN`. Bump the pin deliberately, everywhere
> at once (`.github/workflows/ci.yml`, `setup/localstack-k8s.yaml`,
> `docker-compose.yml`).

## Start / stop

```sh
task lab:up      # start LocalStack, wait until healthy on :4566
task lab:down    # stop LocalStack and wipe its volumes (clean slate)
```

Health/readiness lives at <http://localhost:4566/_localstack/health>.

## No Docker? LocalStack on Kubernetes (kind + podman)

Docker is **not** a hard requirement. If you run podman (or any local
Kubernetes cluster — kind, minikube, k3d, a dev cluster), LocalStack runs as
a Deployment instead ([`setup/localstack-k8s.yaml`](./localstack-k8s.yaml)),
with the same pinned image, services, and clean-slate semantics:

```sh
# One-time: a kind cluster on the podman runtime (skip if you have a cluster)
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name opentofu-workshop

task lab:up:k8s     # apply + wait ready + port-forward :4566 (background)
task lab:down:k8s   # stop the port-forward + delete namespace/deployment
```

`lab:up:k8s` port-forwards the Service to `localhost:4566`, so **everything
downstream is identical** — the same provider config, the same `awslocal`
commands, the same endpoint. The Docker-free integration gate is:

```sh
task verify:integration:k8s   # unit lane + every examples/* integration tftest
```

Cleanup when you're done for the day:

```sh
kind delete cluster --name opentofu-workshop
```

## The `awslocal` wrapper

`awslocal` is a thin wrapper around the AWS CLI that automatically points at
`http://localhost:4566`, so you never pass `--endpoint-url` by hand.

Install:

```sh
pipx install awscli-local      # or: pip install awscli-local
```

Use it exactly like `aws`:

```sh
awslocal s3 mb s3://demo-bucket
awslocal s3 ls
awslocal dynamodb list-tables
awslocal sqs list-queues
awslocal iam list-users
```

### No `awslocal`? Use plain `aws`

Set the dummy credentials and endpoint from `.env.example`, then add
`--endpoint-url`:

```sh
cp .env.example .env
set -a; . ./.env; set +a
aws --endpoint-url http://localhost:4566 s3 ls
```

## Pointing OpenTofu at LocalStack

The AWS provider is configured to send requests to LocalStack. A typical lab
provider block looks like this (dummy creds + endpoint overrides + the flags
that skip real-AWS-only preflight calls):

```hcl
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3       = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    iam      = "http://localhost:4566"
    sqs      = "http://localhost:4566"
    sns      = "http://localhost:4566"
    kms      = "http://localhost:4566"
    logs     = "http://localhost:4566"
  }
}
```

Enabled services: **s3, dynamodb, iam, sqs, sns, kms, logs** (see
`docker-compose.yml`). Need another? Add it to `SERVICES` and re-run
`task lab:up`.

## Troubleshooting

- **`task lab:up` times out** — is Docker running? Check `docker compose logs localstack`.
  No Docker at all? Use the Kubernetes path above (`task lab:up:k8s`).
- **`task lab:up:k8s` times out** — check `kubectl -n opentofu-workshop logs deploy/localstack`
  and that your kube context points at the intended cluster (`kubectl config current-context`).
- **LocalStack exits demanding `LOCALSTACK_AUTH_TOKEN`** — you're on a 2026 CalVer
  image; use the pinned community `4.9.2` (see the version-pin note above).
- **`Connection refused`** — LocalStack isn't up yet; wait for the health check
  or re-run `task lab:up`.
- **State looks stale** — `task lab:down` wipes volumes; `PERSISTENCE=0` means
  every restart is a clean slate.
