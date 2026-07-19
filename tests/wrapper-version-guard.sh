#!/usr/bin/env bash
# Asserts the preflight CLI-version guard: a present-but-outdated strata CLI
# (below MIN_CLI_VERSION) nudges to upgrade exactly once instead of silently
# no-oping; a current CLI delegates normally; the guard is preflight-only so
# other verbs still reach an old CLI.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)" && . "$HERE/_common.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

STUB="$TMP/strata"
export STRATA_MEMORY_BIN="$STUB"

# make_stub <version>: a fake strata that reports <version> for `--version`
# and, for any other invocation, drains stdin and prints a marker preflight
# reply so a delegated call is distinguishable from the guard's own output.
make_stub() {
  cat >"$STUB" <<EOF
#!/bin/sh
if [ "\$1" = "--version" ]; then printf 'strata %s\n' "$1"; exit 0; fi
cat >/dev/null
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"stub-delegated"}}'
EOF
  chmod +x "$STUB"
}

log "== outdated CLI nudges to upgrade, exactly once, without delegating"
export CLAUDE_PLUGIN_DATA="$TMP/data-old"
make_stub "3.2.0"
run_hook preflight "$HERE/fixtures/session-start.json"
if [ "$RUN_HOOK_EXIT" -eq 0 ]; then
  ok "outdated-CLI preflight exits 0"
else
  fail "outdated-CLI preflight exited $RUN_HOOK_EXIT"
fi
assert_json_valid "upgrade nudge" "$RUN_HOOK_STDOUT"
assert_jq_field "upgrade nudge " '.systemMessage | type' "string" "$RUN_HOOK_STDOUT"
case "$RUN_HOOK_STDOUT" in
*"brew upgrade"*) ok "nudge mentions brew upgrade" ;;
*) fail "nudge missing upgrade instructions: $RUN_HOOK_STDOUT" ;;
esac
case "$RUN_HOOK_STDOUT" in
*stub-delegated*) fail "outdated CLI must not delegate preflight" ;;
*) ok "outdated CLI did not delegate preflight" ;;
esac

run_hook preflight "$HERE/fixtures/session-start.json"
if [ -z "$RUN_HOOK_STDOUT" ]; then
  ok "second upgrade nudge is silent"
else
  fail "upgrade nudge repeated: $RUN_HOOK_STDOUT"
fi

log "== current CLI delegates preflight to the memory verb"
export CLAUDE_PLUGIN_DATA="$TMP/data-new"
make_stub "3.9.0"
run_hook preflight "$HERE/fixtures/session-start.json"
assert_jq_field "delegated preflight " \
  '.hookSpecificOutput.additionalContext' "stub-delegated" "$RUN_HOOK_STDOUT"

log "== guard is preflight-only: an outdated CLI still reaches other verbs"
export CLAUDE_PLUGIN_DATA="$TMP/data-recall"
make_stub "3.2.0"
run_hook recall "$HERE/fixtures/user-prompt-submit.json"
assert_jq_field "outdated-CLI recall " \
  '.hookSpecificOutput.additionalContext' "stub-delegated" "$RUN_HOOK_STDOUT"

summarize
