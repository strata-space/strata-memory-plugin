#!/usr/bin/env bash
# Asserts hooks/hooks.json is valid, wires all four lifecycle events through
# scripts/memory-hook.sh, and uses matchers that compile as extended regexes.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)" && . "$HERE/_common.sh"

HOOKS_FILE="$HERE/../hooks/hooks.json"

log "== hooks.json validity"
if jq empty "$HOOKS_FILE" >/dev/null 2>&1; then
  ok "hooks.json parses"
else
  fail "hooks.json does not parse"
fi

log "== all four lifecycle events wired"
for event in SessionStart UserPromptSubmit PostToolUse Stop; do
  if jq -e ".hooks.${event} | length > 0" "$HOOKS_FILE" >/dev/null; then
    ok "$event present"
  else
    fail "$event missing"
  fi
done

log "== every command routes through the dispatcher shim"
commands=$(jq -r '.hooks[][].hooks[].command' "$HOOKS_FILE")
while IFS= read -r cmd; do
  # The single quotes are intentional: match the literal ${CLAUDE_PLUGIN_ROOT}
  # token in the command string, not an expansion of it.
  # shellcheck disable=SC2016
  case "$cmd" in
  *'${CLAUDE_PLUGIN_ROOT}/scripts/memory-hook.sh'*)
    ok "command uses shim: $cmd"
    ;;
  *)
    fail "command bypasses shim: $cmd"
    ;;
  esac
done <<<"$commands"

log "== verbs map to the CLI's hook verbs"
for verb in preflight recall observe check; do
  if printf '%s\n' "$commands" | grep -q "memory-hook.sh\" ${verb}\$"; then
    ok "verb wired: $verb"
  else
    fail "verb not wired: $verb"
  fi
done

log "== matchers compile under grep -E"
matchers=$(jq -r '.hooks[][] | select(.matcher != null) | .matcher' "$HOOKS_FILE")
while IFS= read -r matcher; do
  if printf 'probe\n' | grep -E "$matcher" >/dev/null 2>&1 || [ $? -eq 1 ]; then
    ok "matcher compiles: $matcher"
  else
    fail "matcher does not compile: $matcher"
  fi
done <<<"$matchers"

log "== expected tool names hit the PostToolUse matchers"
read_matcher=$(jq -r '.hooks.PostToolUse[0].matcher' "$HOOKS_FILE")
for tool in read_document mcp__strata__read_document \
  mcp__plugin_strata-memory_strata__read_document; do
  if printf '%s\n' "$tool" | grep -Eq "$read_matcher"; then
    ok "matches read tool: $tool"
  else
    fail "read matcher misses: $tool"
  fi
done
shell_matcher=$(jq -r '.hooks.PostToolUse[1].matcher' "$HOOKS_FILE")
for tool in Bash shell local_shell; do
  if printf '%s\n' "$tool" | grep -Eq "$shell_matcher"; then
    ok "matches shell tool: $tool"
  else
    fail "shell matcher misses: $tool"
  fi
done

log "== hooks add no timeout overrides (the CLI owns budgets)"
if jq -e '[.hooks[][].hooks[] | has("timeout")] | any' "$HOOKS_FILE" >/dev/null; then
  fail "hooks.json sets a timeout; budgets belong to the CLI"
else
  ok "no timeout fields"
fi

summarize
