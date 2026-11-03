# Architecture decision records

Why the HardFOC standard is what it is. Each record is one decision in the Context / Decision / Consequences form,
numbered in the order it was accepted. A record is never edited to change its decision; a new record supersedes
it, and the old one gets a `Superseded by ADR-NNNN` status.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-error-model.md) | Drivers keep `<chip>::Error` and `Result<T>`; handlers map to `hf::Status` | Accepted |
| [0002](0002-lifecycle.md) | One lifecycle: I/O-free constructor, `Initialize()`, `EnsureInitialized()` | Accepted |
| [0003](0003-crtp-ports.md) | Drivers are templates on a CRTP port constrained by a concept | Accepted |
| [0004](0004-no-heap.md) | No heap in drivers; none after start-up anywhere | Accepted |
| [0005](0005-hf-hal-common.md) | A shared `hf-hal-common` repository | Accepted |
| [0006](0006-freertos-1khz-tick.md) | FreeRTOS at 1 kHz everywhere | Accepted |
| [0007](0007-submodule-pinning-and-tags.md) | Submodules pinned to release tags, with a manifest | Accepted |
| [0008](0008-naming.md) | One naming scheme, enforced by `clang-tidy` | Accepted |
| [0009](0009-gpl-3-0.md) | GPL-3.0 in every repository | Accepted |
| [0010](0010-cpp20.md) | C++20 in every repository | Accepted |

## Format

```markdown
# ADR-NNNN: <decision as a short sentence>

- Status: Proposed | Accepted | Superseded by ADR-NNNN
- Date: YYYY-MM-DD

## Context

What forced a decision: the problem, the constraints, the options considered.

## Decision

What we do, stated as rules.

## Consequences

What gets better, what gets worse, and what has to change in which repositories.
```

A new record is added in the same PR as the change to the standard it explains.

## Where the decisions came from

Records 0001 to 0010 were accepted by the owner on 3 November 2026, after a read-only review of every repository at
`main` (23 drivers, 6 libraries, 2 HALs, 2 products) against one checklist: API shape, port, errors, start-up,
config, memory and threading, naming, build, tests and docs. The review found the repository shell, docs and CI
already uniform, and the C++ contracts not: 5 error models, 6 start-up styles, about 8 spellings of the same port
hooks, two handler families, two drifting HALs and about 45 error types.

The agreed order of work:

1. **Safety fixes** first, as small PRs (as5047u getters, Flux valve access through `VisitDriver()`, bno08x
   `Dfu()` image, pf1550 delay hook, the duplicate `Utility.h`, the `HfTime.h` include).
2. **Write it down**: this standard, the org clang configs, a driver template repository, `hf::Status` and
   `ToStatus()`.
3. **Drivers**, in parallel, each landing with its `hf-core` handler change.
4. **hf-core handlers** converge on one family, with shared adapter bases and per-library CMake targets.
5. **hf-hal-common**: extract the shared managers, facade base, bind interface and lints; port Flux, then Vortex.
6. **Products** go through the facade only.
7. **v0.1 release candidates**, then the STM32 compile job and bind.
