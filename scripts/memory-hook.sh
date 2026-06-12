#!/bin/sh
# memory-hook.sh <verb>: stateless wrapper: stdin (host hook JSON) is
# inherited by `strata memory <verb>`, whose stdout is the hook reply.
#
# Fail-open contract: a missing CLI or a CLI failure always exits 0 with no
# output, so the host continues unaffected. The only exception is `preflight`
# with no CLI installed, which emits a one-time install nudge (marker file in
# the plugin data dir). The CLI owns all time budgets; this wrapper adds none.
set -u

verb="${1:-}"
[ -n "$verb" ] || exit 0

find_strata() {
  # Test/user override first, then PATH, then common install locations
  # (GUI-launched hosts often lack `brew shellenv` in PATH).
  if [ -n "${STRATA_MEMORY_BIN:-}" ]; then
    if [ -x "${STRATA_MEMORY_BIN}" ]; then
      printf '%s\n' "${STRATA_MEMORY_BIN}"
      return 0
    fi
    return 1
  fi
  if command -v strata >/dev/null 2>&1; then
    command -v strata
    return 0
  fi
  for candidate in /opt/homebrew/bin/strata /usr/local/bin/strata \
    /home/linuxbrew/.linuxbrew/bin/strata "$HOME/.local/bin/strata"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if ! strata_bin=$(find_strata); then
  if [ "$verb" = "preflight" ]; then
    data_dir="${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/strata-memory}}"
    marker="$data_dir/install-nudge-shown"
    if [ ! -f "$marker" ]; then
      mkdir -p "$data_dir" 2>/dev/null && : >"$marker" 2>/dev/null
      printf '%s\n' '{"systemMessage":"Strata Memory is installed but the strata CLI was not found. Install it with: brew install --cask strata-space/tap/strata - then run: strata login && strata memory init"}'
    fi
  fi
  exit 0
fi

# stdin passes through untouched (this wrapper never reads it); the CLI's
# hook verbs are fail-open by contract and print hook-protocol JSON.
"$strata_bin" memory "$verb"
exit 0
