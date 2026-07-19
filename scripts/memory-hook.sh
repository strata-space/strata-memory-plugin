#!/bin/sh
# memory-hook.sh <verb>: stateless wrapper: stdin (host hook JSON) is
# inherited by `strata memory <verb>`, whose stdout is the hook reply.
#
# Fail-open contract: a missing CLI or a CLI failure always exits 0 with no
# output, so the host continues unaffected. Two exceptions, both `preflight`
# only and both emitted at most once (marker file in the plugin data dir):
# no CLI installed emits an install nudge; a CLI too old to carry the memory
# verbs emits an upgrade nudge. The CLI owns all time budgets; this wrapper
# adds none.
set -u

# Minimum strata CLI version that ships the `strata memory` verbs. An older
# install is present on PATH but silently lacks the subcommand, so the whole
# loop no-ops with no signal — preflight nudges to upgrade instead.
MIN_CLI_VERSION="3.3.0"

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

plugin_data_dir() {
  printf '%s\n' "${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/strata-memory}}"
}

# emit_once <marker-name> <json>: print json to stdout the first time only,
# so a persistent condition nudges once instead of on every session start.
emit_once() {
  _dir=$(plugin_data_dir)
  _marker="$_dir/$1"
  [ -f "$_marker" ] && return 0
  mkdir -p "$_dir" 2>/dev/null && : >"$_marker" 2>/dev/null
  printf '%s\n' "$2"
}

# version_below <current> <floor>: exit 0 (true) when current < floor. Both
# are dotted triples (e.g. 3.6.0); missing or non-numeric components count as
# 0. Equal or newer exits 1.
version_below() {
  awk -v cur="$1" -v flo="$2" 'BEGIN {
    nc = split(cur, c, ".");
    split(flo, f, ".");
    for (i = 1; i <= 3; i++) {
      cc = (i <= nc ? c[i] : 0) + 0;
      ff = f[i] + 0;
      if (cc < ff) exit 0;
      if (cc > ff) exit 1;
    }
    exit 1;
  }'
}

if ! strata_bin=$(find_strata); then
  if [ "$verb" = "preflight" ]; then
    emit_once install-nudge-shown '{"systemMessage":"Strata Memory is installed but the strata CLI was not found. Install it with: brew install --cask strata-space/tap/strata - then run: strata login && strata memory init"}'
  fi
  exit 0
fi

if [ "$verb" = "preflight" ]; then
  # A present-but-outdated CLI lacks `strata memory` entirely and would fail
  # silently. Nudge to upgrade once, but only when the version is positively
  # below the floor — an unparseable version fails open (delegate as normal).
  ver=$("$strata_bin" --version 2>/dev/null | awk 'NR==1 {print $2}')
  case "$ver" in
  [0-9]*.[0-9]*.[0-9]*)
    if version_below "$ver" "$MIN_CLI_VERSION"; then
      emit_once version-nudge-shown "{\"systemMessage\":\"Strata Memory: strata $ver is too old for the memory loop (needs $MIN_CLI_VERSION+). Upgrade with: brew upgrade --cask strata-space/tap/strata\"}"
      exit 0
    fi
    ;;
  esac
fi

# stdin passes through untouched (this wrapper never reads it); the CLI's
# hook verbs are fail-open by contract and print hook-protocol JSON.
"$strata_bin" memory "$verb"
exit 0
