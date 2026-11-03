# ADR-0008: One naming scheme, enforced by `clang-tidy`

- Status: Accepted
- Date: 2026-11-03

## Context

Drivers used PascalCase, camelCase and snake_case for methods; units were written `_mA`, `_ma`, `Ma`, `Mv`, `Ua`
or as a `Unit` enum; some drivers declared symbols at global scope or named their class `Device` or `Driver`; and
repositories carried diverging `.clang-format` files (column limit 100 in most, 120 in `hf-core` and the HALs) and
`.clang-tidy` files with no naming rules.

## Decision

- Namespaces: `<chip>` for drivers, `hf` for libraries and `hf-core`, `hf::hal` for the shared HAL, `<board>` for
  board code, `<board>::app` for products.
- Types, functions and public methods PascalCase; private methods camelBack; variables and parameters snake_case;
  private members `snake_case_`; constants `kPascalCase`; macros `UPPER_CASE`; units as suffixes; `Read*` for calls
  that touch the bus. Datasheet names may stay `UPPER_CASE`.
- One include root per repository (`hf/iiw/BaseSpi.h`).
- One org `.clang-format` (LLVM base, 100 columns) and one `.clang-tidy` with `readability-identifier-naming`, kept
  in `hardfoc/.github/standards/config/` and copied unchanged into each repository's `_config/`.

## Consequences

- Names are predictable across the stack, and a reviewer no longer argues style.
- Private helpers stay camelBack, which the reference drivers (pca9685, ads9324) already use, so they pass with
  few findings.
- `hf-core`, both HALs and tmc5160 reformat once to 100 columns.
- Public API renames (camelCase methods in tmc9660 and vortex-driver, unit spellings) are breaking changes and land
  with the v0.1 API work.
