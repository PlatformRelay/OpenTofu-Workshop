#!/usr/bin/env bats
# An UNQUOTED heredoc (<<STUB, not <<'STUB') expands `...` and $(...) while the
# stub is being written. A backtick-quoted word in a comment inside one runs as
# a command: verify-selftest.sh's lock-race stub printed "armed: command not
# found", "mv: missing file operand" and slept 3s inside a green run. Quote the
# delimiter or escape the backtick (\`).

load helpers

setup() {
  setup_mocks
}

@test "no unescaped backtick inside an unquoted heredoc in tracked shell scripts" {
  cd "$ROOT"
  local hits
  hits="$(for f in scripts/*.sh setup/*.sh; do
    awk -v F="$f" '
      !d && match($0, /<<-?[A-Za-z_]+[ \t]*$/) {
        tag = substr($0, RSTART, RLENGTH); sub(/<<-?/, "", tag); gsub(/[ \t]/, "", tag); d = 1; next
      }
      d {
        t = $0; sub(/^\t+/, "", t)
        if (t == tag) { d = 0; next }
        s = $0; gsub(/\\`/, "", s)
        if (s ~ /`/) print F ":" NR ": " $0
      }' "$f"
  done)"
  [ -z "$hits" ] || { printf '%s\n' "$hits"; false; }
}
