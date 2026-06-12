#!/usr/bin/env bash
# Asserts representative CLI outputs flow through the wrapper as valid
# hook-protocol JSON: context injection for recall, decision-block for check.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)" && . "$HERE/_common.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

STUB="$TMP/strata"
export STRATA_MEMORY_BIN="$STUB"

make_stub() {
  cat >"$STUB" <<EOF
#!/bin/sh
cat >/dev/null
printf '%s\n' '$1'
EOF
  chmod +x "$STUB"
}

log "== recall reply shape"
make_stub '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"<strata-memory>candidates</strata-memory>"}}'
run_hook recall "$HERE/fixtures/user-prompt-submit.json"
assert_json_valid "recall reply" "$RUN_HOOK_STDOUT"
assert_jq_field "recall " '.hookSpecificOutput.hookEventName' "UserPromptSubmit" "$RUN_HOOK_STDOUT"
if [ -n "$(printf '%s' "$RUN_HOOK_STDOUT" | jq -r '.hookSpecificOutput.additionalContext')" ]; then
  ok "recall carries additionalContext"
else
  fail "recall missing additionalContext"
fi

log "== check block shape"
make_stub '{"decision":"block","reason":"reconcile memory docs"}'
run_hook check "$HERE/fixtures/stop.json"
assert_json_valid "check reply" "$RUN_HOOK_STDOUT"
assert_jq_field "check " '.decision' "block" "$RUN_HOOK_STDOUT"
assert_jq_field "check " '.reason' "reconcile memory docs" "$RUN_HOOK_STDOUT"

log "== noop shape"
make_stub '{}'
run_hook observe "$HERE/fixtures/post-tool-use-mcp-read.json"
assert_json_valid "observe reply" "$RUN_HOOK_STDOUT"
assert_jq_field "observe " '. | length' "0" "$RUN_HOOK_STDOUT"

summarize
