#!/usr/bin/env bash
# Asserts the wrapper passes stdin to the CLI byte-identically, relays the
# CLI's stdout untouched, and coerces a CLI failure into exit 0 (fail open).

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)" && . "$HERE/_common.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

STUB="$TMP/strata"
cat >"$STUB" <<EOF
#!/bin/sh
# Stub strata: record argv and stdin, emit canned hook JSON.
printf '%s\n' "\$*" >"$TMP/argv"
cat >"$TMP/stdin-capture"
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"stub"}}'
EOF
chmod +x "$STUB"
export STRATA_MEMORY_BIN="$STUB"

FIXTURE="$HERE/fixtures/user-prompt-submit.json"

log "== stdin and argv reach the CLI"
run_hook recall "$FIXTURE"
if [ "$RUN_HOOK_EXIT" -eq 0 ]; then
  ok "wrapper exits 0"
else
  fail "wrapper exited $RUN_HOOK_EXIT"
fi
if cmp -s "$FIXTURE" "$TMP/stdin-capture"; then
  ok "stdin reached the CLI byte-identical"
else
  fail "stdin was altered in transit"
fi
if [ "$(cat "$TMP/argv")" = "memory recall" ]; then
  ok "CLI invoked as: strata memory recall"
else
  fail "unexpected argv: $(cat "$TMP/argv")"
fi
assert_jq_field "relayed stdout " '.hookSpecificOutput.additionalContext' "stub" "$RUN_HOOK_STDOUT"

log "== CLI failure is coerced to exit 0"
cat >"$STUB" <<'EOF'
#!/bin/sh
cat >/dev/null
exit 7
EOF
chmod +x "$STUB"
run_hook check "$HERE/fixtures/stop.json"
if [ "$RUN_HOOK_EXIT" -eq 0 ]; then
  ok "CLI exit 7 became wrapper exit 0"
else
  fail "wrapper leaked CLI exit code: $RUN_HOOK_EXIT"
fi

summarize
