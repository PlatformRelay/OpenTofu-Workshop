# Capstone stretch — Terramate orchestration

**Optional.** The capstone base path under `examples/capstone/` is a single
OpenTofu root and does **not** need Terramate. This stretch is for learners who
have completed Day 3 (S20–S23) and want to orchestrate the colony as stacks.

## Edge criterion

`task verify` and the unit `tofu test` lane must stay green when Terramate is
**absent**. Do not move the runnable root into stacks unless you keep a
Terramate-free path.

## When Terramate is present

```sh
command -v terramate >/dev/null \
  || { printf '%s\n' "terramate not found — run: task setup"; exit 1; }

# From the workshop root, after task setup:
cd examples/capstone/stretch
terramate list
# Then follow Day-3 labs (S21–S23) to split storage vs messaging into stacks
# with after/before ordering — reuse patterns from labs/day-3/23-orchestration/.
```

## Suggested stack split (learner exercise)

| Stack | Owns | Depends on |
|-------|------|------------|
| `storage` | S3 artifacts + DynamoDB index | — |
| `messaging` | SQS work queue | `storage` (tags / naming inputs shared via globals) |

Scaffolding below is a **pointer**, not a second runnable estate — keep the
parent `examples/capstone/*.tf` as the source of truth until you deliberately
split it.
