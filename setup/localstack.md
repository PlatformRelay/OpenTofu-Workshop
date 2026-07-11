# LocalStack in this workshop

Every lab is **local-first**: instead of a real AWS account, the labs target
[LocalStack](https://www.localstack.cloud/), an AWS emulator that runs in
Docker. No cloud account, no credentials, no bill.

## Start / stop

```sh
task lab:up      # start LocalStack, wait until healthy on :4566
task lab:down    # stop LocalStack and wipe its volumes (clean slate)
```

Health/readiness lives at <http://localhost:4566/_localstack/health>.

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
- **`Connection refused`** — LocalStack isn't up yet; wait for the health check
  or re-run `task lab:up`.
- **State looks stale** — `task lab:down` wipes volumes; `PERSISTENCE=0` means
  every restart is a clean slate.
