# Strata Memory

**Your coding agent forgets everything between sessions. Point it at a
[Strata](https://strata.space) Space and it stops forgetting.**

`strata-memory` is a plugin for [Claude Code](https://code.claude.com) and
[Codex](https://developers.openai.com/codex) that turns a Strata Space (your
design notes, conventions, gotchas, runbooks) into the agent's long-term
memory:

1. **Recall, on every prompt.** The plugin hybrid-searches (keyword +
   semantic) the bound Space on your prompt and injects the matching
   documents as candidates: title, document ID, snippet, score. The agent
   reads the ones that are genuinely relevant and ignores the rest.
2. **A standing contract.** Alongside the candidates, once per session: *if
   you rely on one of these documents and your work changes a fact in it,
   update that document before you finish.* The agent writes back through
   the normal Strata edit surface (MCP `edit_document`, or
   `strata api documents edit`).
3. **A gentle nudge.** When the agent stops after changing files without
   updating any memory document it relied on, the plugin blocks the stop
   once and asks it to reconcile. Strictness is configurable; uncertain
   signals always resolve to "allow".

Recall is fail-open by design: a slow or unreachable backend can never block
or delay your prompt. The hooks run the `strata` CLI under tight internal
time budgets and silently no-op on any failure.

## Requirements

- A [Strata](https://strata.space) account and a Space with the documents
  you want remembered
- The `strata` CLI, version 3.3.0 or newer:

  ```sh
  brew install --cask strata-space/tap/strata
  ```

## Install

### Claude Code

```
/plugin marketplace add strata-space/marketplace
/plugin install strata-memory@strata-space
```

### Codex

Add the marketplace source and enable the plugin (or install it from the
Codex app's plugin directory):

```toml
# ~/.codex/config.toml
[plugins."strata-memory@strata-space"]
marketplace = "github:strata-space/marketplace"
```

Then run `/plugins` in Codex and install `strata-memory`.

## Quickstart

```sh
strata login
cd your-repo
strata memory init        # pick a Space interactively, or:
strata memory bind space_01ABC...            # just you
strata memory bind space_01ABC... --scope project   # whole team (commits .strata/memory.json)
```

Start a session in that repository. Relevant memory documents appear in a
`<strata-memory>` block as you prompt; `strata memory status` shows the
resolved binding at any time. The bundled skills walk through setup
(`strata-memory-init`) and diagnosis (`strata-memory-status`) in
conversation.

## How it works

The plugin wires four lifecycle hooks into thin wrappers around
`strata memory <verb>`:

| Hook | Verb | What it does |
| --- | --- | --- |
| SessionStart | `preflight` | Verifies auth + binding, seeds the session ledger with a git baseline, warns when semantic search is degraded, injects a compact Space index |
| UserPromptSubmit | `recall` | Searches the Space on your prompt; injects deduplicated candidates plus the once-per-session update contract; records each candidate's document version |
| PostToolUse | `observe` | Marks candidates the agent actually read (MCP `read_document`, or `strata api documents get`) |
| Stop | `check` | Nudges (at most once per session by default) when files changed but no relied-upon document's version moved |

Write-back detection is transport-agnostic: any edit path that goes through
Strata bumps the document version, so the stop check works whether the agent
edited via MCP or the CLI.

State lives with the CLI, not the plugin: bindings in the platform data dir
(shared across hosts), one ledger per session, garbage-collected after seven
days. A committed `.strata/memory.json` (project scope) wins over a personal
binding.

## Configuration

Per-binding config (set at bind time, or edit the binding file):

| Key | Default | Meaning |
| --- | --- | --- |
| `strictness` | `nudgeOnce` | `off` (never block), `nudgeOnce` (block at most once per session), `strict` (keep nudging, capped) |
| `topK` | 5 | Max candidate documents injected per prompt |
| `minScore` | 0 | Drop candidates below this RRF score |
| `recallTimeoutMs` | 2000 | Hard wall-clock budget for recall |
| `injectIndex` | true | Inject a compact Space index at session start |

Environment overrides (`STRATA_MEMORY_STRICTNESS`, `STRATA_MEMORY_TOP_K`,
`STRATA_MEMORY_MIN_SCORE`, `STRATA_MEMORY_RECALL_TIMEOUT_MS`,
`STRATA_MEMORY_INJECT_INDEX`) beat the binding file.

## Privacy

Recall sends your prompt text to Strata's search API for the bound Space.
Results are scoped to what your Strata user may read; the agent can only
retrieve and edit documents you have access to. The update contract
instructs agents to never write secrets or raw transcripts into memory.

## Troubleshooting

Ask your agent to run the `strata-memory-status` skill, or check by hand:

```sh
strata memory status --json   # binding, scope, config, ledger count
strata status --json          # auth state
```

Recall not injecting anything? Short or acknowledgement prompts are skipped
by design, and documents already surfaced in the session are not repeated.
No binding resolves? The binding key is the git repo root; bind from inside
the repository.

Installing this alongside the [`strata`
plugin](https://github.com/strata-space/strata-claude-plugin) is supported:
both bundle the same MCP server registration, which the hosts namespace per
plugin (you will see the Strata tools twice).

## Development

```sh
shellcheck -x scripts/*.sh tests/*.sh
bash tests/hooks-json-valid.sh
bash tests/wrapper-fail-open.sh
bash tests/wrapper-passthrough.sh
bash tests/wrapper-protocol-shape.sh
bash tests/live-cli-smoke.sh   # skips without the strata CLI
```

Releases are cut by release-please from Conventional Commits; both host
manifests version-bump in lockstep.

## License

[MIT](./LICENSE)
