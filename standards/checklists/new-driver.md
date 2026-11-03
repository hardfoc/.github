# Checklist: new driver

Copy this list into the tracking issue or the first PR of a new `hf-<chip>-driver`. Each item links the rule it
checks; [driver.md](../driver.md) is the contract.

```markdown
### Repository
- [ ] Created from the driver template (or the hf-ads9324-driver shell), public, named `hf-<chip>-driver`
- [ ] Entry added to `org/org-metadata.json` and applied; merge settings, security and rulesets applied
- [ ] `CODEOWNERS`, `AGENTS.md`, `CLAUDE.md` (`@AGENTS.md`), `.claude/skills/verify/SKILL.md`
- [ ] `LICENSE` is GPL-3.0; `_config/.clang-format` and `_config/.clang-tidy` copied unchanged from the standard

### Code
- [ ] Everything in `namespace <chip>`; class `<chip>::<CHIP>`; umbrella header `inc/<chip>.hpp`, implementation `src/<chip>.ipp`
- [ ] Port base `<chip>::<Bus>Interface<Derived>` and concept `<chip>::<Bus>Port`; required hooks not declared in the base
- [ ] Hooks PascalCase, `noexcept`, `bool`, raw bytes only; the driver never configures the bus
- [ ] Optional hooks detected with `requires` in one helper; a missing delay hook fails to compile
- [ ] `enum class Error : uint8_t` with the base set at values 0 to 9, chip-specific values from 16, each one returned somewhere; `ToString()`
- [ ] `Result<T>` / `Result<void>` with `ok()` and `[[nodiscard]]` on every fallible call
- [ ] Every port failure propagates; no getter returns a stale or zero value after a failed read
- [ ] `noexcept` constructor with no I/O; `Initialize(const Config& = {})` resets, checks the chip ID, applies config
- [ ] `EnsureInitialized()`, `IsInitialized()`, `Deinitialize()`; every I/O call returns `NotInitialized` before init
- [ ] `Config` struct with unit-suffixed fields and datasheet defaults; Kconfig only through `inc/<chip>_kconfig.hpp`
- [ ] No heap, exceptions, RTTI, `std::function`, `std::string`, `printf`, static mutable state; no locking, no RTOS
- [ ] Destructive operations take explicit data or confirmation; no default triggers them
- [ ] Names and units per the naming standard; `clang-tidy` clean on `inc/` and `src/`

### Build
- [ ] C++20; version only in `cmake/hf_<chip>_build_settings.cmake`; generated `<chip>_version.h`
- [ ] `EXPORT_NAME <chip>` and alias `hf::<chip>`; install rules for every header, the `.ipp` and the package config
- [ ] Options `HF_<CHIP>_BUILD_TESTS` and `HF_<CHIP>_ENABLE_WARNINGS`
- [ ] `idf_component.yml` at the root; `examples/esp32` with `app_config.yml` and `CONFIG_FREERTOS_HZ=1000` in `sdkconfig.defaults`
- [ ] CI at `@v1` ending in the `CI gate` job; `CI gate / gate` required once it has run

### Tests
- [ ] `tests/mock_<chip>.hpp` register model
- [ ] Host suite on gcc and clang with `-Werror -fno-exceptions -fno-rtti`: not-initialised, ID mismatch, bus failure on every path, argument checks, register traffic
- [ ] `tests/docs/` compiles every snippet on the site
- [ ] `tests/install_consumer/` builds against `find_package(hf_<chip>)`
- [ ] Version agreement test

### Docs
- [ ] The driver page set, including `docs/contract.md`
- [ ] Doxygen clean with `EXTRACT_ALL = NO` and warnings as errors on `inc/`
- [ ] Quickstart checks every return value; Porting shows a complete, compiled port
- [ ] README sections per the README standard; datasheet in `docs/datasheet/`
- [ ] `CHANGELOG.md` with `## [Unreleased]`

### Exceptions (only if they apply)
- [ ] MCU-bound: README and Contract page say so; no global-state C API in the public header
- [ ] Protocol client: remote identity check replaces the chip-ID check
```
