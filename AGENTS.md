# strata-memory-plugin

Dual-host coding-agent plugin (Claude Code + Codex) that turns a Strata Space
into the agent's long-term memory. All loop logic lives in the `strata` CLI
(`strata memory preflight|recall|observe|check`, built in the Strata
monorepo); this repo ships only packaging: two manifests, one hooks file, one
wrapper script, two skills, smoke tests. No build step, no package manager

## Layout

- `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json`: host manifests.
  Versions MUST stay in lockstep (release-please bumps both via extra-files;
  CI asserts equality)
- `hooks/hooks.json`: one shared file for both hosts. SessionStart →
  preflight, UserPromptSubmit → recall, PostToolUse → observe, Stop → check
- `scripts/memory-hook.sh`: the only host-coupled code. POSIX sh dispatcher,
  verb as `$1`
- `.mcp.json`: registers the Strata MCP server (mirror of the sibling
  `strata` plugin)
- `skills/`: `strata-memory-init` (consent-gated onboarding),
  `strata-memory-status` (read-only diagnosis)
- `tests/`: fixture-driven smoke runners, sourced from `tests/_common.sh`

## Load-bearing constraints

- Fail open, always. The wrapper MUST exit 0 on every path: missing CLI,
  CLI crash, missing verb. A hook that exits non-zero or hangs wedges the
  user's prompt flow. The CLI owns all time budgets; hooks.json MUST NOT set
  `timeout` fields and the wrapper MUST NOT add one
- stdin passthrough: the wrapper MUST NOT read stdin; the CLI child inherits
  it. `tests/wrapper-passthrough.sh` asserts byte-identical delivery
- One dispatcher: every hooks.json command routes through
  `${CLAUDE_PLUGIN_ROOT}/scripts/memory-hook.sh <verb>`. Codex aliases
  `CLAUDE_PLUGIN_ROOT`, so no per-host fork. If host hook schemas ever
  diverge, split into per-host hooks files referenced from each manifest and
  keep the shim shared
- The only output the wrapper itself may produce is the one-time
  CLI-missing install nudge on `preflight` (marker file in the plugin data
  dir)
- PostToolUse matchers deliberately over-match (`(mcp__.*__)?read_document`,
  `Bash|shell|local_shell`); the CLI's `observe` early-exits on non-Strata
  input. Narrowing a matcher MUST keep `tests/hooks-json-valid.sh`'s
  tool-name coverage green
- Endpoint literal: the MCP URL in `.mcp.json` is the only hardcoded
  environment URL. When the stable customer-facing alias lands, update it
  and bump the version
- Skills are executed by the model at runtime: privileged or mutating
  commands MUST be shown verbatim and consent-gated `[y/N]`
  (`strata-memory-init`); diagnosis MUST stay read-only
  (`strata-memory-status`). Treat SKILL.md edits like runbook changes
- Minimum CLI: the memory verbs ship in strata CLI 3.3.0. The README states
  it; preflight enforces it at runtime by failing open with the install
  nudge

## Commands

```bash
shellcheck -x scripts/*.sh tests/*.sh   # CI gates on this first
bash tests/hooks-json-valid.sh          # hooks wiring + matcher coverage
bash tests/wrapper-fail-open.sh         # missing-CLI contract
bash tests/wrapper-passthrough.sh       # stdin/stdout fidelity, exit-0 coercion
bash tests/wrapper-protocol-shape.sh    # hook-protocol JSON shapes
bash tests/live-cli-smoke.sh            # real CLI; skips when absent or pre-3.3
```

Test conventions: `set -euo pipefail`, source `_common.sh` via the `HERE=`
idiom, `mktemp -d` + `trap … EXIT`, end with `summarize`. Isolate real-CLI
state with `STRATA_AGENT_DIR=$tmp`; force wrapper paths with
`STRATA_MEMORY_BIN`

## Release

release-please on main: Conventional Commits drive the version; merging the
release PR tags `strata-memory--v<version>`. One-time repo setup:
`RELEASE_PLEASE_TOKEN` secret + "Allow GitHub Actions to create and approve
pull requests". The plugin version is independent of the CLI's SemVer
