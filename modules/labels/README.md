# `labels` module

Emits a **validated 12-key labelling map** implementing one estate-wide tagging
taxonomy. Companion to the [`naming`](../naming) module: `naming` gives every
resource a predictable name, `labels` gives every resource a predictable,
machine-queryable set of tags for cost allocation, policy, and inventory.

See [ADR 0004 — Labelling convention](../../docs/decisions/0004-labelling-convention.md)
for the rationale and the full key table.

## The taxonomy

| Key | Required | Notes |
|-----|:--------:|-------|
| `environment` | yes | prod / dev / staging / … |
| `criticality` | yes | low, medium, high, critical, business-critical |
| `project` | yes | application / project slug |
| `service` | yes | component within the project |
| `owner` | yes | owning team (email-ish) |
| `cost-center` | yes | chargeback code |
| `managed-by` | (defaulted) | defaults to `opentofu` |
| `compliance` | optional | e.g. soc2, iso27001, gdpr |
| `data-classification` | optional | public, internal, confidential, pii, phi, pci |
| `primary-contact` | optional | human contact (email-ish) |
| `secondary-contact` | optional | human contact (email-ish) |
| `iac-source-url` | optional | http(s) link to IaC source |

Optional keys default to `null` and are **dropped** from the output map, so tags
never carry empty strings.

## Usage

```hcl
module "labels" {
  source = "../../modules/labels"

  environment = "prod"
  criticality = "high"
  project     = "crmapp"
  service     = "web"
  owner       = "platform-team@example.com"
  cost_center = "CC-1234"

  # optional
  data_classification = "confidential"
  iac_source_url      = "https://git.example.com/infra/estate"

  additional_labels = {
    team = "payments"
  }
}

resource "aws_s3_bucket" "web" {
  bucket = "..."
  tags   = module.labels.tags # alias of .labels
}
```

`labels` and `tags` are the same map — `tags` is an alias so AWS resources read
naturally, while cloud-neutral consumers use `labels`.

## Testing

```sh
tofu init -backend=false
tofu test   # command = plan, no cloud needed
```

<!-- BEGIN_TF_DOCS -->
<!-- Regenerate with: terraform-docs -c .terraform-docs.yml . -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Deployment environment. | `string` | n/a | yes |
| criticality | Business criticality (low/medium/high/critical/business-critical). | `string` | n/a | yes |
| project | Project / application slug. | `string` | n/a | yes |
| service | Service / component within the project. | `string` | n/a | yes |
| owner | Owning team (email-ish). | `string` | n/a | yes |
| cost_center | Cost centre / billing code. | `string` | n/a | yes |
| managed_by | Managing tool. | `string` | `"opentofu"` | no |
| compliance | Optional compliance regime. | `string` | `null` | no |
| data_classification | Optional data sensitivity class. | `string` | `null` | no |
| primary_contact | Optional primary contact (email-ish). | `string` | `null` | no |
| secondary_contact | Optional secondary contact (email-ish). | `string` | `null` | no |
| iac_source_url | Optional http(s) link to IaC source. | `string` | `null` | no |
| additional_labels | Free-form extra labels merged on top. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| labels | The composed taxonomy map (cloud-neutral name). |
| tags | Alias of `labels`, for AWS `tags = ...`. |
<!-- END_TF_DOCS -->
