# ADR-0007: Submodules pinned to release tags, with a manifest

- Status: Accepted
- Date: 2026-11-03

## Context

The stack is composed with Git submodules, each pinned to a commit. Nothing had been tagged, declared versions
conflicted (20 drivers at 1.0.0, HALs at 1.1.0, Vortex at 2.0.0, core libraries at nothing), and a board could not
report which versions it ran. The ESP-IDF component registry was considered: it cannot host the private Flux
product, 21 of 23 drivers are not IDF components, the HALs include `hf-core` through CMake, and the host and STM32
builds need a non-IDF path.

## Decision

- Keep submodules, and pin them to release tag commits (`vX.Y.Z`, or `vX.Y.Z-rc.N` during a wave).
- Each repository has independent SemVer starting at `0.1.0`; `hf-core-drivers`, `hf-core-utils` and `hf-core`
  are the bill of materials.
- `hf-core`, the HALs and the products carry `version_lock.txt` (`REF_<repo>=vX.Y.Z@<sha>`), checked in CI: a
  warning on PRs to `main`, a failure on `release/*` and tag pushes, plus a check that the tag is on `main`.
- Firmware reports the tag and SHA of every submodule.
- Releases go bottom-up, each layer re-pinned to the tags below it.

## Consequences

- A product release names exactly what it contains, all the way down.
- Moving a layer forward is a pin PR per repository; a bump bot opens them for the aggregates.
- Private repositories are not protected by tag rulesets on the current plan; the CI pin and ancestry checks are
  their only safeguard.
- The registry can be revisited for outside users once 0.x settles.
