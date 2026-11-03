# ADR-0005: A shared `hf-hal-common` repository

- Status: Accepted
- Date: 2026-11-03

## Context

The Vortex and Flux HALs started as copies and drifted: six managers are near-copies, the facades are near-clones,
the two platform binds use different shapes and verbs, each HAL's lint misses the other's rules, and their
`ManagerError` enums differ in values, width and namespace. Keeping them aligned by hand was the alternative;
the drift shows it does not hold.

## Decision

- Create `hf-hal-common` (namespace `hf::hal`) holding `ManagerBase`, `FacadeBase` with ordered, fail-closed
  start-up and one `CollectDiagnostics()`, the six common managers (NVS, LED, GPIO, ADC, temperature, comms), one
  `PlatformBind` interface (starting from Flux's shape), and the merged lints.
- A board HAL keeps only its board config, its bind and its board-specific managers.
- `hf-hal-common` is a submodule of each HAL, pinned to a release tag.
- Flux moves first (it is closer to the target), then Vortex.

## Consequences

- A fix to a common manager lands once.
- A third board starts from `hf-hal-common` and the new-board checklist instead of a copy.
- One more repository to release, between `hf-core` and the HALs in the release order.
- Both HALs change their public manager APIs to `hf::Status`, which the products absorb in the same wave.
