---
name: strata-memory-init
description: >
  Set up Strata Memory for the current repository: install the strata CLI if
  missing, sign in, pick a Space, and bind it as the agent's long-term memory.
  Use for "set up strata memory", "bind a Space as memory", "make this repo
  remember things between sessions", "connect my agent to a memory Space", or
  when the session-start guidance says no Space is bound. Requires the strata
  CLI (installed here with consent if absent).
---

# Set up Strata Memory

Goal: this repository ends bound to a Strata Space so the plugin's hooks run
the memory loop (recall on every prompt, update contract, stop-time nudge).

Hard rules:

- Every privileged or mutating command below MUST be shown verbatim and
  confirmed `[y/N]` before you run it. If declined, stop and say what remains
  undone
- MUST NOT create a Space silently. Binding targets a Space the user names
- MUST NOT run `strata memory init` from a non-interactive shell. It prompts
  on stdin; use the list-then-bind flow below instead

## 1. CLI present?

```bash
command -v strata && strata --version
```

If missing, offer (consent-gated):

```bash
brew install --cask strata-space/tap/strata
```

No Homebrew on Linux: hand off to the `strata` plugin's `strata-spaces`
skill, which owns the verified tarball install path. The memory verbs need
CLI 3.3.0 or newer; older installs upgrade via the same brew command.

## 2. Signed in?

```bash
strata status --json
```

`"status": "logged_out"` (or expired): have the user run `strata login`
(opens a browser; on headless hosts add `--no-browser`).

## 3. Pick a Space and bind

List what the user can access and present the options in conversation:

```bash
strata spaces --json
```

Ask which Space should be this repository's memory, and at which scope:

- just me: `strata memory bind <spaceId>`
- whole team: `strata memory bind <spaceId> --scope project`, then remind the
  user to commit `.strata/memory.json` (never commit it yourself unless asked)

Both commands are mutating: show verbatim, confirm, then run. Optional
strictness override: `--strictness off|nudge-once|strict` (default
nudge-once).

## 4. Verify

```bash
strata memory status --json
```

Confirm `binding.spaceId` matches. Tell the user recall is live from their
next prompt: candidate memory documents will appear in a `<strata-memory>`
block, and the stop-time nudge fires when session work changes files but no
relied-upon memory document was updated.

Out of scope: diagnosing a broken loop (use `strata-memory-status`), writing
memory content, unbinding (`strata memory unbind`).
