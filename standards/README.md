# HardFOC engineering standard

The rules every HardFOC repository follows: how each layer is shaped, what it may depend on, how errors, threads
and time work, how code is named and formatted, and how repositories are governed, documented and released.

This directory is the single source of truth. Repository docs, templates, CI configuration and AI agents link here
instead of restating it. When a repository and this standard disagree, the standard wins, and the repository gets
an issue.

## How to read it

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT** and **MAY** mean what
[RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) says they mean. A MUST is checked in review or CI. A SHOULD
can be broken for a reason that the PR states.

Each rule applies to new code at once. Existing code converges through the order of work in the
[design review](adr/README.md#where-the-decisions-came-from): a repository that does not meet a rule yet is
tracked by an issue, not exempted.

## Contents

### Layer contracts

| Page | Covers |
| --- | --- |
| [Layers](layers.md) | The stack, what each layer promises and depends on, allowed and forbidden includes |
| [Driver](driver.md) | `hf-<chip>-driver`: port, `Result<T>`, `Error`, lifecycle, config, memory, build, tests |
| [Library](library.md) | `hf-internal-interface-wrap`, `hf-utils-rtos-wrap`, `hf-utils-general`, `hf-utils-canopen`, `hf-pincfg` |
| [Handler](handler.md) | `hf-core/handlers/<chip>`: one handler family, adapters, `VisitDriver`, diagnostics |
| [Board HAL](hal.md) | `hf-hal-<board>`, the shared `hf-hal-common` and `bsp_bind/<family>` |
| [Product](product.md) | `hardfoc-<board>` applications |

### Cross-layer rules

| Page | Covers |
| --- | --- |
| [Errors](errors.md) | `hf::Status`, `hf::Result<T>` and the mapping at each layer boundary |
| [Threading and timing](threading-and-timing.md) | One lock, one clock, one delay; the 1 kHz FreeRTOS tick |
| [Naming and style](naming-and-style.md) | Names, units, namespaces, include roots, and the org [`.clang-format`](config/.clang-format) and [`.clang-tidy`](config/.clang-tidy) |

### Process

| Page | Covers |
| --- | --- |
| [Repository governance](repo-governance.md) | Branches, PRs, labels, CODEOWNERS, rulesets, required checks, security, new repositories |
| [Release](release.md) | SemVer 0.x, release candidates, `prepare-release`, changelog rules, bottom-up release order |
| [Documentation](docs.md) | The page set, the Contract page, Doxygen settings, README sections |
| [AI agents](agents.md) | How agents work in HardFOC repositories: `AGENTS.md`, skills, definition of done |

### Records and checklists

| Page | Covers |
| --- | --- |
| [Architecture decision records](adr/README.md) | Why the rules are what they are, one decision per record |
| [New driver](checklists/new-driver.md) | Copyable checklist for a new `hf-<chip>-driver` |
| [New handler](checklists/new-handler.md) | Copyable checklist for a new handler in `hf-core` |
| [New board HAL](checklists/new-board-hal.md) | Copyable checklist for a new `hf-hal-<board>` |
| [Release](checklists/release.md) | Copyable checklist for one repository's release |

## Using the standard in a repository

- Link the standard from the repository's `CONTRIBUTING.md` (or rely on the org default) and from its `AGENTS.md`.
- Copy [`config/.clang-format`](config/.clang-format) and [`config/.clang-tidy`](config/.clang-tidy) into
  `_config/` unchanged. A repository MUST NOT carry local edits to them; propose the change here. All other tool
  configuration lives in `_config/` too, and the root follows [ADR-0011](adr/0011-repository-root-layout.md).
- When a PR deviates from a MUST, say so in the PR description, name the rule, and link the issue that tracks the
  fix. A reviewer can refuse the deviation.
- Start new repositories from the checklists; they are the standard condensed into steps.

## Changing the standard

The standard changes by pull request to `hardfoc/.github`, like code.

1. A change that alters a decision gets a new ADR in [`adr/`](adr/README.md) (or supersedes an existing one) in
   the same PR.
2. The PR updates every page the change touches, including the checklists and the configs.
3. Once it merges, open issues in the repositories that no longer comply.

Editorial fixes (wording, links, examples that do not change a rule) need no ADR.

## Fixed decisions

These were decided with the owner on 3 November 2026 and are not reopened without a superseding ADR:

| Decision | Record |
| --- | --- |
| Drivers keep their own `<chip>::Error` and `Result<T>`; handlers map them to `hf::Status` / `hf::Result<T>` | [ADR-0001](adr/0001-error-model.md) |
| One lifecycle: I/O-free constructor, `Initialize()` with a chip-ID check, `EnsureInitialized()` | [ADR-0002](adr/0002-lifecycle.md) |
| Drivers are templates on a CRTP port; no virtual calls below the handler | [ADR-0003](adr/0003-crtp-ports.md) |
| No heap after start-up; none at all in drivers | [ADR-0004](adr/0004-no-heap.md) |
| A shared `hf-hal-common` repository for what the board HALs have in common | [ADR-0005](adr/0005-hf-hal-common.md) |
| FreeRTOS runs at 1 kHz everywhere | [ADR-0006](adr/0006-freertos-1khz-tick.md) |
| Submodules pinned to release tags, with a manifest | [ADR-0007](adr/0007-submodule-pinning-and-tags.md) |
| One naming scheme, enforced by `clang-tidy` | [ADR-0008](adr/0008-naming.md) |
| GPL-3.0 in every repository | [ADR-0009](adr/0009-gpl-3-0.md) |
| C++20 in every repository | [ADR-0010](adr/0010-cpp20.md) |
| The root holds only required and first-read files; tool configuration in `_config/`, no symlinks; one root `CMakeLists.txt` for CMake and ESP-IDF; platform code only in `examples/<platform>/` | [ADR-0011](adr/0011-repository-root-layout.md) |
