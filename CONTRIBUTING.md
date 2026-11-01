# Contributing to HardFOC

This applies to every repository in the `hardfoc` org unless that repository
has its own `CONTRIBUTING.md`. Detailed engineering standards (layering,
coding style, testing requirements) live in the development handbook.

## Branches and pull requests

- `main` is the only long-lived branch. Do not push to it directly.
- Branch from `main` with a short descriptive name: `feat/<topic>`,
  `fix/<topic>`, `docs/<topic>`, `chore/<topic>`.
- Open a pull request to `main` early. Keep it to one change; prefer under
  about 400 lines of diff and split larger work into a series of PRs.
- Fill in the PR template: what changed, why, and how you verified it.
- PRs are squash-merged. The PR title becomes the commit subject on `main`,
  so write it as a commit subject.

## Commit messages

- Subject in the imperative mood, under about 72 characters, no trailing
  period: `Add BMP581 FIFO read`, not `Added FIFO` or `fifo stuff`.
- Optional body after a blank line explaining why the change is needed, not a
  restatement of the diff.

## CI gate

Every PR must pass the repository's CI before merge. Depending on the repo
this includes C++ lint and static analysis, ESP32 example builds, host tests,
Markdown and YAML lint, and docs link checks. Do not merge with a red or
skipped required check; fix the cause or explain in the PR why a check is
wrong and fix the check.

If your change affects behaviour on hardware, say in the PR which board you
ran it on (Vortex V1, Flux V1, or a dev kit) and what you observed.

## How changes flow through submodules

The stack is composed with Git submodules, each pinned to a commit or tag:

```text
hf-*-driver, hf-internal-interface-wrap, hf-pincfg ──► hf-core-drivers ──┐
hf-utils-general, hf-utils-rtos-wrap, hf-utils-canopen ──► hf-core-utils ─┤
                                                                          ▼
                       hardfoc-<board> (hal/) ◄── hf-hal-<board> (lib/core) ◄── hf-core
```

A change to a lower layer reaches a product in steps, one PR per repo, each
merged before the next is opened:

1. Change the driver or library (for example `hf-bmp581-driver`) and merge.
   Tag a release if the change is meant for consumers.
2. In `hf-core-drivers` (or `hf-core-utils`), bump the submodule pin to that
   commit or tag.
3. In `hf-core`, bump the `hf-core-drivers` / `hf-core-utils` pin and update
   any handler that uses the changed API.
4. In the board HAL (`hf-hal-vortex-v1`, `hf-hal-flux-v1`), bump `lib/core`.
5. In the product (`hardfoc-vortex-v1`, `hardfoc-flux-v1`), bump the HAL pin.

A pin bump is its own PR. In its description, link the PR or release being
pulled in and note any build-setting or API changes. Never point a submodule
at an unmerged branch, and never edit code inside a submodule checkout of a
parent repo; make the change in the submodule's own repo first.

## Documentation

Update the README and `docs/` in the same PR as the code they describe. Public
headers carry Doxygen comments.

## Code of conduct and security

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md),
not in issues.
