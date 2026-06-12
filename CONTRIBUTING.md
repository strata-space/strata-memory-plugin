# Contributing

This repo is packaging only: the memory loop's logic lives in the `strata`
CLI (`strata memory ...`), built in the Strata monorepo. Changes here touch
manifests, the hooks file, the wrapper script, skills, and tests.

## Setup

You need `jq`, `shellcheck`, and bash. The live smoke additionally uses the
`strata` CLI (3.3.0+) when present, and skips cleanly when it is not.

## Checks

Run what CI runs:

```sh
jq empty .claude-plugin/plugin.json .codex-plugin/plugin.json hooks/hooks.json .mcp.json
shellcheck -x scripts/*.sh tests/*.sh
bash tests/hooks-json-valid.sh
bash tests/wrapper-fail-open.sh
bash tests/wrapper-passthrough.sh
bash tests/wrapper-protocol-shape.sh
bash tests/live-cli-smoke.sh
```

When changing wrapper or hook behavior, update the matching test in the same
PR; the tests replay the documented contracts (fail-open, stdin passthrough,
matcher coverage), and drift between docs and tests is treated as a bug.

## Commit style and releases

Use [Conventional Commits](https://www.conventionalcommits.org). release-please
turns them into the CHANGELOG and version bumps; both host manifests
(`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`) are bumped in
lockstep and CI fails if they diverge. Merging the release PR tags
`strata-memory--v<version>` and publishes the GitHub release.

## Conduct and security

Be kind. Security reports go to security@strata.space (see SECURITY.md), not
public issues.
