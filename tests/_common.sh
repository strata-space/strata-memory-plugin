#!/usr/bin/env bash
# Shared helpers for tests/*.sh smoke runners.
#
# Each smoke script sources this file and uses the helpers to assert load-
# bearing primitives. Scripts run on a clean VM (ubuntu-latest / macos-latest)
# and exit non-zero on the first failed assertion.

# RUN_HOOK_STDOUT / RUN_HOOK_EXIT are this module's output contract: set by
# run_hook and read by the sourcing smoke scripts, so they read as unused here.
# shellcheck disable=SC2034
set -euo pipefail

PASS=0
FAIL=0

log() { printf '%s\n' "$*" >&2; }

ok() {
  PASS=$((PASS + 1))
  printf '  ok   %s\n' "$1" >&2
}

fail() {
  FAIL=$((FAIL + 1))
  printf '  FAIL %s\n' "$1" >&2
}

assert_cmd_present() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 on PATH"
  else
    fail "$1 NOT on PATH"
  fi
}

assert_file_exists() {
  if [ -e "$1" ]; then
    ok "exists: $1"
  else
    fail "missing: $1"
  fi
}

assert_jq_field() {
  local source_label="$1" path="$2" expected="$3" json="$4"
  local actual
  actual=$(printf '%s\n' "$json" | jq -r "$path" 2>/dev/null || printf '')
  if [ "$actual" = "$expected" ]; then
    ok "$source_label$path = $expected"
  else
    fail "$source_label$path = $actual (expected $expected)"
  fi
}

assert_json_valid() {
  local label="$1" text="$2"
  if printf '%s\n' "$text" | jq empty >/dev/null 2>&1; then
    ok "$label is valid JSON"
  else
    fail "$label is NOT valid JSON: $text"
  fi
}

# run_hook <verb> <fixture-file> : pipe a fixture into the wrapper and
# capture stdout + exit code into RUN_HOOK_STDOUT / RUN_HOOK_EXIT.
# Callers set STRATA_MEMORY_BIN to control which binary the wrapper finds.
RUN_HOOK_STDOUT=""
RUN_HOOK_EXIT=0
run_hook() {
  local verb="$1" fixture="$2"
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  set +e
  RUN_HOOK_STDOUT=$(CLAUDE_PLUGIN_ROOT="$repo_root" \
    "$repo_root/scripts/memory-hook.sh" "$verb" <"$fixture")
  RUN_HOOK_EXIT=$?
  set -e
}

summarize() {
  printf '\n%d passed, %d failed\n' "$PASS" "$FAIL" >&2
  [ "$FAIL" -eq 0 ]
}
