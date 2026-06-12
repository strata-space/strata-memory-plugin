# Security policy

## Reporting a vulnerability

Email **security@strata.space** with a description of the issue, reproduction
steps, and the impact you observed. Please do not open a public GitHub issue
for security reports. We aim to acknowledge within 3 business days.

## Scope

This repository ships lifecycle hooks that run on every agent prompt, a
wrapper script that executes the `strata` CLI, and skills that can install
software with user consent. Reports we are particularly interested in:

- A path by which hook stdin (attacker-influenced session IDs, prompts, or
  tool payloads) causes the wrapper or CLI to write outside the plugin's
  state directory or execute unintended commands.
- A path by which the `strata-memory-init` skill executes a privileged
  command **without** the documented explicit per-command consent prompt.
- A path by which the hooks block, delay, or break the user's prompt flow
  when the backend is unavailable (a fail-open violation with
  denial-of-service impact).
- A path by which recall injects content the authenticated Strata user is
  not authorized to read.
- A path by which the stop-time nudge can be made to loop without bound.

## Out of scope

- Vulnerabilities in the `strata` CLI itself: report those at the CLI
  repository.
- Vulnerabilities in third-party MCP bridges such as `mcp-remote`.
- Vulnerabilities in Claude Code or Codex themselves: report those to their
  vendors.
