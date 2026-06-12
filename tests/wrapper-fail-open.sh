#!/usr/bin/env bash
# Asserts the wrapper's fail-open contract when the strata CLI is absent:
# every verb exits 0; recall/observe/check stay silent; preflight emits the
# install nudge exactly once.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)" && . "$HERE/_common.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export STRATA_MEMORY_BIN="$TMP/does-not-exist"
export CLAUDE_PLUGIN_DATA="$TMP/plugin-data"

log "== silent verbs exit 0 with empty stdout"
for verb in recall observe check; do
  run_hook "$verb" "$HERE/fixtures/user-prompt-submit.json"
  if [ "$RUN_HOOK_EXIT" -eq 0 ]; then
    ok "$verb exits 0 without CLI"
  else
    fail "$verb exited $RUN_HOOK_EXIT"
  fi
  if [ -z "$RUN_HOOK_STDOUT" ]; then
    ok "$verb stdout empty"
  else
    fail "$verb produced output: $RUN_HOOK_STDOUT"
  fi
done

log "== preflight nudges exactly once"
run_hook preflight "$HERE/fixtures/session-start.json"
if [ "$RUN_HOOK_EXIT" -eq 0 ]; then
  ok "preflight exits 0 without CLI"
else
  fail "preflight exited $RUN_HOOK_EXIT"
fi
assert_json_valid "first preflight nudge" "$RUN_HOOK_STDOUT"
case "$RUN_HOOK_STDOUT" in
*"brew install"*) ok "nudge mentions the brew install" ;;
*) fail "nudge missing install instructions: $RUN_HOOK_STDOUT" ;;
esac
assert_jq_field "nudge " '.systemMessage | type' "string" "$RUN_HOOK_STDOUT"

run_hook preflight "$HERE/fixtures/session-start.json"
if [ -z "$RUN_HOOK_STDOUT" ]; then
  ok "second preflight is silent (marker honored)"
else
  fail "second preflight nudged again: $RUN_HOOK_STDOUT"
fi

log "== missing verb argument exits 0"
set +e
"$HERE/../scripts/memory-hook.sh" </dev/null >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  ok "no-arg invocation exits 0"
else
  fail "no-arg invocation exited $rc"
fi

summarize
