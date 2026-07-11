# 0006 — Local-first lab environment (LocalStack)

**Status:** Accepted

## Context

This is an open-source workshop: every learner must be able to run every lab on
their own machine with **no proprietary access, no cloud account, and no bill**.
Yet the labs should teach *real* provider resources, not toys — and Part 2's story
(native `tofu test`) is strongest when it needs no cloud at all.

## Decision

Labs are **local-first**, in three tiers:

1. **`mock ✓`** — unit tests with `mock_provider` + `command = plan`. No Docker,
   no network. The default for module tests and CI's fast lane.
2. **`localstack ✓`** — realistic **AWS** resource types (`aws_s3_bucket`,
   `aws_dynamodb_table`, `aws_iam_role`, …) against **LocalStack** on `:4566`.
   Brought up with `task lab:up`; the `aws` provider is pointed at LocalStack via
   `endpoints` + `skip_*` flags and dummy `test`/`test` credentials.
3. **`real-aws (optional)`** — an appendix toggle (`use_localstack = false`) for
   learners who want to run against a real account. Never required.

Pure-logic bits use `local` / `null` / `random` / `tls` providers.

## Consequences

- Anyone can complete the workshop offline-ish with just `tofu` + Docker.
- CI runs the unit lane everywhere and the LocalStack lane as a service container.
- Naming/short-name maps default to an **AWS** profile to match the labs; a GCP
  profile ships as an alternate (see 0005).
- Panic reset is always safe: `task lab:down` + `tofu destroy`.
