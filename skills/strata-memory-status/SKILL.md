---
name: strata-memory-status
description: >
  Diagnose the Strata Memory loop and map each failure to a concrete next
  step: CLI presence and version, sign-in state, which Space is bound and at
  what scope, effective strictness and recall config, session-ledger state,
  and degraded semantic search. Use for "is strata memory working", "why is
  recall not injecting documents", "why did the agent get nudged at stop",
  "which Space is my memory", or "memory candidates stopped appearing".
  Read-only: it routes to a fix, never remediates.
---

# Diagnose Strata Memory

Read-only contract: probe and report. MUST NOT install the CLI, run
`strata login`, bind or unbind, or edit any state file. Every finding maps to
a user action or a hand-off to `strata-memory-init`.

Work the layers in order; stop at the first failure and report it with its
fix.

## 1. CLI

```bash
command -v strata && strata --version
```

- Missing: fix is `strata-memory-init` (it owns consent-gated install)
- Version below 3.3.0: memory verbs do not exist; fix is
  `brew install --cask strata-space/tap/strata` (user runs it)

## 2. Auth

```bash
strata status --json
```

`logged_out` or expired token: fix is the user running `strata login`. Note:
hooks fail open, so an expired login looks like "recall silently stopped",
not an error.

## 3. Binding and config

```bash
strata memory status --json
```

- `binding: null`: no Space bound for this repository; fix is
  `strata-memory-init`. Remember the key is the git repo root: launching the
  agent from a different repo than the one bound is the common surprise
- `binding.scope`: `project` comes from committed `.strata/memory.json` and
  wins over a personal binding; if the team binding looks wrong, that file is
  what to inspect
- `config.strictness`: `off` means the stop nudge never fires; `strict` keeps
  nudging (capped) until a memory document changes version
- `sessionLedgers`: 0 after a session ran means hooks are not firing; verify
  the plugin is enabled in this host and the session was restarted after
  install

## 4. Loop behavior

- No `<strata-memory>` block on prompts: short or acknowledgement prompts are
  skipped by design; documents already surfaced this session are not
  re-injected; otherwise check layers 1 to 3
- A session-start message about degraded semantic search means the backend
  fell back to keyword-only ranking: recall still works, quality is reduced,
  nothing to fix client-side
- Stop nudge fired: expected when files changed but no relied-upon memory
  document was updated. The agent should either update the document or state
  that no documented fact changed; the nudge is capped per session
- MCP connectivity problems (read_document or edit_document failing) belong
  to the `strata` plugin's `strata-doctor` skill
