#!/usr/bin/env bash
# Drives the real `strata memory` hook verbs through the wrapper with an
# isolated state dir. Skips cleanly when the strata CLI is not installed
# or does not yet ship the memory verbs.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)" && . "$HERE/_common.sh"

if ! command -v strata >/dev/null 2>&1; then
  log "strata CLI not installed; skipping live smoke"
  exit 0
fi
if ! strata memory --help >/dev/null 2>&1; then
  log "installed strata CLI predates the memory verbs; skipping live smoke"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Isolate all memory state: with a fresh STRATA_AGENT_DIR no binding can
# resolve, so verb behavior is deterministic regardless of the host machine.
export STRATA_AGENT_DIR="$TMP/agent"

log "== preflight (unbound repo) injects bind guidance"
run_hook preflight "$HERE/fixtures/session-start.json"
if [ "$RUN_HOOK_EXIT" -eq 0 ]; then
  ok "preflight exits 0"
else
  fail "preflight exited $RUN_HOOK_EXIT"
fi
assert_json_valid "preflight reply" "$RUN_HOOK_STDOUT"
case "$RUN_HOOK_STDOUT" in
*"strata memory init"*) ok "preflight points at strata memory init" ;;
*) fail "preflight missing bind guidance: $RUN_HOOK_STDOUT" ;;
esac

log "== recall (unbound repo) is a silent noop"
run_hook recall "$HERE/fixtures/user-prompt-submit.json"
if [ "$RUN_HOOK_EXIT" -eq 0 ]; then
  ok "recall exits 0"
else
  fail "recall exited $RUN_HOOK_EXIT"
fi
assert_jq_field "recall " '. | length' "0" "$RUN_HOOK_STDOUT"

log "== observe and check (no ledger) are silent noops"
for pair in "observe:post-tool-use-mcp-read" "check:stop"; do
  verb="${pair%%:*}"
  fixture="${pair##*:}"
  run_hook "$verb" "$HERE/fixtures/$fixture.json"
  if [ "$RUN_HOOK_EXIT" -eq 0 ]; then
    ok "$verb exits 0"
  else
    fail "$verb exited $RUN_HOOK_EXIT"
  fi
  assert_jq_field "$verb " '. | length' "0" "$RUN_HOOK_STDOUT"
done

summarize
