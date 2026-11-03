# Release

How HardFOC repositories are versioned, tagged and released, and the order a release wave follows. The v0.1 plan
of 3 November 2026 is the source; this page is the rule it produced.

## Versions

- **Independent SemVer per repository**, starting at `0.1.0`. Drivers change at different rates, so a lockstep
  version would force empty releases. The combination the boards run is captured by the aggregates and the
  manifests instead ([Pins and the manifest](#pins-and-the-manifest)).
- **0.x makes no API stability promise.** A breaking change bumps the minor (`0.1.0` → `0.2.0`); a fix or an
  addition bumps the patch (`0.1.0` → `0.1.1`). `1.0.0` is declared per repository, by ADR, when its API is meant
  to hold.
- **Declared versions reset to `0.1.0`** for the first tag. Nothing was tagged before, so the `1.0.0`, `1.1.0` and
  `2.0.0` some repositories declare harm no one. Repositories whose changelog already used a 0.x number keep it
  (dynamixel `0.5.0`, se050 `0.4.0`).
- **The CI tool repositories** (`hf-general-ci-tools`, `hf-espidf-ci-tools`) are the exception: they are already
  at `1.x` with a moving major tag (`v1`) that callers pin, and follow their own
  [versioning page](https://hardfoc.github.io/hf-general-ci-tools/latest/VERSIONING/).
- **One version source** per repository: `cmake/hf_<x>_build_settings.cmake`. `idf_component.yml`, the generated
  version header and any hand-written copy are derived or checked against it.

## Tags and release candidates

- Tags are `vX.Y.Z` on a commit that is on `main` (or on `release/x.y` for a maintenance release). Release
  candidates are `vX.Y.Z-rc.N`. The `release-tags` ruleset makes both immutable on public repositories.
- **A release is a named, immutable snapshot** that meets all of:
  - CI was green on that commit with the pinned ESP-IDF;
  - the changelog section for the version is complete;
  - it builds with `add_subdirectory()` and with `find_package(hf_<x>)` → `hf::<x>`;
  - the release notes state its bench status: the board and test list it ran on, or **CI-only**.
- Repositories that no board uses (ads9324, at25040, bmp581, dynamixel, isf15acp4, pf1550, se050, sfm,
  tmc5160 at the time of writing) can only be released as CI-only, and MAY skip the release candidate.
- A release candidate is promoted by tagging **the same commit** `vX.Y.Z`. If anything changed, the next candidate
  is `-rc.N+1`.

## Changelog

Every repository has a `CHANGELOG.md` in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) form:

```markdown
# Changelog

## [Unreleased]

### Breaking

- `Initialize()` now returns `Result<void>` instead of `bool`.

### Added

- `ReadFifoLevel()`.

### Fixed

- Bus errors during `ReadPressurePa()` were reported as `Ok` with a stale value.

## [0.1.0] - 2026-11-17
```

- `## [Unreleased]` is always the first section, and every PR that changes behaviour adds to it.
- Section headings are exactly `### Breaking`, `### Added`, `### Changed`, `### Deprecated`, `### Removed`,
  `### Fixed`, `### Security`, in that order, each only when it has entries.
- **Any breaking change is listed under `### Breaking`**, with what a caller has to change. A PR labelled
  `breaking` without a `### Breaking` entry is not merged.
- Released sections are `## [X.Y.Z] - YYYY-MM-DD` and are not edited afterwards except to fix links.
- Entries describe the effect for a user of the repository, not the commits.
- The release body is the changelog section, not generated notes.

## Release automation

These workflows come from `hf-general-ci-tools` v1.3.0 and `hf-espidf-ci-tools` v1.2.0, step 0 of the release
order. Until a repository has them, a maintainer does each step by hand and checks the same conditions.

| Workflow | Does |
| --- | --- |
| `prepare-release` (manual, input `version`) | Normalises changelog headings, rolls `## [Unreleased]` into `## [X.Y.Z] - <date>`, bumps every version declaration (build settings, every `idf_component.yml`, hand-written headers), and opens a `Release vX.Y.Z` PR. Merging it tags the merge commit. |
| `release.yml` (on a `v*` tag) | Fails if the tag does not match the declared version or the commit is not on `main` / `release/*`; creates the GitHub Release with the changelog section as the body; for products, attaches `.bin`, `.elf`, `sha256` and `sdkconfig` and fails if any is missing. |
| Docs publish (on a `v*` tag) | Publishes the versioned docs. A `-rc` tag publishes without moving the `latest` alias. |
| Pin check | Checks each submodule against a release tag and the manifest: warns on PRs to `main`, fails on `release/*` and tag pushes, and checks the tagged commit is on `main`. |
| Bump bot | Opens pin-bump PRs in the aggregates when a pinned repository tags a release. |

Tags that trigger other workflows are pushed with a GitHub App token, not the workflow token. Release workflows
call reusable workflows at `@v1`, never `@main`.

## Pins and the manifest

- Submodules stay, pinned to **tag commits**. The ESP-IDF component registry is not used for the boards (it cannot
  host private repositories, most drivers are not IDF components, and the host and STM32 builds need a non-IDF
  path). Decision: [ADR-0007](adr/0007-submodule-pinning-and-tags.md).
- `hf-core-drivers`, `hf-core-utils` and `hf-core` are the bill of materials: their release notes list the version
  of every repository they pin.
- `hf-core`, both HALs and both products carry a `version_lock.txt` manifest, one line per submodule:

  ```text
  REF_hf-core=v0.1.0@3f2a9c1e5b7d...
  REF_hf-hal-common=v0.1.0@9be0d4c7a1f2...
  ```

- The firmware reports the tag and SHA of every submodule it was built from.

## Release order

A release wave goes bottom-up. Each layer is re-pinned to the tags under it before it is tagged.

| Step | Repositories | Notes |
| --- | --- | --- |
| 0 | `hf-general-ci-tools`, `hf-espidf-ci-tools` | The release automation above, released first |
| 1 | Leaves, in parallel: `hf-utils-general`, `hf-utils-canopen`, `hf-utils-rtos-wrap`, `hf-pincfg`, `hf-internal-interface-wrap`, every driver | Drivers a board uses go through an rc; CI-only drivers MAY go straight to the release |
| 2 | Aggregates: `hf-core-utils`, `hf-core-drivers` | Release notes list each pinned version |
| 3 | `hf-core` | |
| 4 | `hf-hal-common`, then `hf-hal-vortex-v1` and `hf-hal-flux-v1` | After their bench lists pass |
| 5 | `hardfoc-vortex-v1`, `hardfoc-flux-v1` | Firmware releases with binaries; NVS or partition changes carry the erase or migration step |

## The stabilisation gate for a wave

1. **Hygiene PRs**: versions, changelog headings, install and export gaps, automation gaps.
2. **Tag `-rc.1` bottom-up** in the order above.
3. **Bench** on real boards: the bench lists from the merged PRs, on a Vortex V1 and a Flux V1.
4. **Promote** the same commits to `vX.Y.Z` if nothing failed, or cut `-rc.2` with the fixes.

The per-repository steps are in the [release checklist](checklists/release.md).
