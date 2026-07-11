# `naming` module

Composes a **deterministic, validated resource name** from a small set of
inputs, so every resource in your estate follows one predictable convention.

```text
[resource_short]-[project]-[env_short]-[location]-[description]-[suffix]
```

Example: an `aws_s3_bucket` for project `crmapp` in `dev`, region token `euw1`,
role `web` becomes:

```text
s3-crmapp-d-euw1-web-a1f3
```

The `location`, `description`, and `suffix` components are optional and are
dropped cleanly (via `compact`) when omitted. When no `suffix` is supplied, a
random 4-hex-char suffix is generated for uniqueness.

## Why a module, not a naming spreadsheet

- **One source of truth.** The short-code map lives in code and is version
  controlled.
- **Fail closed.** Strict `validation` blocks reject bad inputs at plan time;
  output `precondition` blocks guarantee the final name is `< 64` chars and
  matches `[a-z0-9-]` — an invalid name can never reach a provider.
- **Swappable profiles.** `resource_short_names` is a *variable*, so you can
  drop in an entirely different cloud profile (e.g. a GCP map) without forking
  the module.

## Usage

```hcl
module "bucket_name" {
  source = "../../modules/naming"

  resource_type = "aws_s3_bucket"
  project       = "crmapp"
  environment   = "dev"
  location      = "euw1"
  description   = "web"
  # suffix omitted -> random 4-hex-char suffix
}

resource "aws_s3_bucket" "web" {
  bucket = module.bucket_name.name # -> "s3-crmapp-d-euw1-web-<hex>"
}
```

### Swapping in a different cloud profile

```hcl
module "gcs_name" {
  source = "../../modules/naming"

  resource_type = "google_storage_bucket"
  project       = "datalake"
  environment   = "prod"

  resource_short_names = {
    google_storage_bucket = "gcs"
    google_compute_instance = "gce"
    # ...
  }
}
```

## Testing

Native `tofu test` runs use `command = plan` — **no cloud, no credentials, no
state** required:

```sh
tofu init -backend=false
tofu test
```

> Note on the random suffix: `random_id` is *unknown at plan time*, so any test
> that asserts the full composed name passes an explicit `suffix` (which sets
> `random_id count = 0`). The random-path test asserts only the known short
> codes. The concrete random value is exercised by the `apply` integration test
> in `examples/naming-labels-demo`.

<!-- BEGIN_TF_DOCS -->
<!-- Regenerate with: terraform-docs -c .terraform-docs.yml . -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_type | Resource type to name (e.g. `aws_s3_bucket`). Must be a key in `resource_short_names`. | `string` | n/a | yes |
| project | Short project slug; 4-10 lowercase alphanumerics starting with a letter. | `string` | n/a | yes |
| environment | Deployment environment; must be a key in `environment_short_names`. | `string` | n/a | yes |
| location | Optional short location/region token (2-8 lowercase alphanumerics). | `string` | `null` | no |
| description | Optional role component (1-12 lowercase alphanumerics). | `string` | `null` | no |
| suffix | Optional explicit suffix; random 4-hex-char generated when null. | `string` | `null` | no |
| resource_short_names | Map of `resource_type -> short code`. Override to swap cloud profiles. | `map(string)` | AWS profile (~20 entries) | no |
| environment_short_names | Map of `environment -> short code`. | `map(string)` | `{prod=p, dev=d, ...}` | no |

## Outputs

| Name | Description |
|------|-------------|
| name | The composed, validated resource name. |
| resource_short | Short code resolved for `resource_type`. |
| environment_short | Short code resolved for `environment`. |
| suffix | The effective suffix (explicit or generated). |
<!-- END_TF_DOCS -->
