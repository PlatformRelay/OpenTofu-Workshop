#!/usr/bin/env bash
# variant/ovh/scripts/teardown.sh — destroy every OVH variant root that holds
# local state, in dependency order (twins/examples first, bootstrap last).
#
#   task ovh:teardown                          # interactive confirmation per root
#   task ovh:teardown -- --auto-approve        # non-interactive (CI/nightly)
#   task ovh:teardown -- --include-imported    # also destroy import/ roots
#
# The confirm style is setup/lib.sh's `confirm` (gum when present, read
# otherwise, and a non-interactive default of "no" so a pipe cannot destroy
# anything by accident). Nothing in the variant uses prevent_destroy: a
# workshop wants destroy to work.
#
# Safety rules, in order of importance:
#   - An `import/` root adopted a bucket the LEARNER created (Lab 10 Part B).
#     Destroying it deletes that real bucket, so those roots are skipped unless
#     --include-imported is passed. Release them from state instead.
#   - The bootstrap root holds the budget alert and the S3 credentials the other
#     roots need to finish their own destroys. If any earlier root failed, the
#     bootstrap root is NOT destroyed: fix the failure, then re-run.
#   - Every failure is counted and the script exits non-zero if there was one.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=setup/lib.sh
. "$REPO_ROOT/setup/lib.sh"

AUTO=0
INCLUDE_IMPORTED=0
for arg in "$@"; do
  case "$arg" in
    -y | --yes | --auto-approve) AUTO=1 ;;
    --include-imported) INCLUDE_IMPORTED=1 ;;
    *)
      warn "teardown: ignoring unknown argument: $arg"
      ;;
  esac
done

# Dependency order: the twins and examples use the S3 credentials the bootstrap
# root creates, so destroy them first and the bootstrap last.
BOOTSTRAP="variant/ovh/bootstrap"
ORDER=(
  "variant/ovh/labs"
  "variant/ovh/examples"
  "variant/ovh/smoke"
  "$BOOTSTRAP"
)

states=()
for base in "${ORDER[@]}"; do
  [ -d "$base" ] || continue
  while IFS= read -r state; do
    [ -n "$state" ] || continue
    states+=("$state")
  done < <(find "$base" -type f -name 'terraform.tfstate' -not -path '*/.terraform/*' 2>/dev/null | sort)
done

found=0
failed=()
skipped_imported=()
for state in ${states[@]+"${states[@]}"}; do
  root="${state%/terraform.tfstate}"
  found=1

  case "$root" in
    */import)
      if [ "$INCLUDE_IMPORTED" -ne 1 ]; then
        warn "$root: skipped — it adopted a bucket YOU created; destroying it deletes that real bucket."
        note "  Release it from state instead: tofu -chdir=$root state rm aws_s3_bucket.adopted"
        note "  (or add a removed { from = aws_s3_bucket.adopted  lifecycle { destroy = false } } block and apply)."
        note "  To destroy it anyway, re-run with --include-imported."
        skipped_imported+=("$root")
        continue
      fi
      ;;
  esac

  if [ "$root" = "$BOOTSTRAP" ] && [ "${#failed[@]}" -gt 0 ]; then
    warn "$root: NOT destroyed — ${#failed[@]} earlier root(s) failed to destroy."
    note "  The bootstrap root holds the budget alert and the S3 credentials the"
    note "  failed roots need to finish their cleanup. Fix those first, then re-run."
    failed+=("$root (skipped: earlier failures)")
    continue
  fi

  if [ "$AUTO" -eq 1 ]; then
    printf '%s\n' "Destroying $root …"
  elif ! confirm "Destroy resources in $root?"; then
    note "skipping $root"
    continue
  fi
  # Best-effort init first: a root with state but no .terraform/ (after
  # `git clean -Xfd`, or a copied state dir) otherwise fails "module not yet
  # installed". An init failure surfaces as the destroy failure below.
  tofu -chdir="$root" init -input=false >/dev/null 2>&1 || true
  # -input=false: a root with a required variable (bootstrap's alert_email, the
  # import root's adopted_bucket_name) or a changed TF_VAR_state_passphrase must
  # fail loudly here, not hang on a prompt.
  if tofu -chdir="$root" destroy -auto-approve -input=false -no-color; then
    ok "$root: destroyed"
  else
    bad "$root: tofu destroy FAILED (see the error above; export any required TF_VAR_* and re-run)"
    failed+=("$root")
  fi
done

if [ "$found" -eq 0 ]; then
  note "No variant root holds local state — nothing to tear down."
fi

printf '\n== OVH teardown summary ==\n'
if [ "${#skipped_imported[@]}" -gt 0 ]; then
  for r in "${skipped_imported[@]}"; do
    warn "kept (adopted bucket, not destroyed): $r"
  done
fi
if [ "${#failed[@]}" -gt 0 ]; then
  for r in "${failed[@]}"; do
    bad "failed: $r"
  done
  note "List what is still billed: aws s3 ls --endpoint-url https://s3.<region>.io.cloud.ovh.net"
  note "(or OVH Manager → Public Cloud → Object Storage)."
  exit 1
fi
ok "teardown complete"
