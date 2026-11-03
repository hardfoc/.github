# Checklist: new board HAL

Copy this list into the tracking issue for a new `hf-hal-<board>-v<n>`. [hal.md](../hal.md) is the contract.

```markdown
### Repository
- [ ] Created from the HAL template (or the hf-hal-flux-v1 shell), named `hf-hal-<board>-v<n>`; metadata, settings and rulesets applied
- [ ] Submodules `lib/core` (hf-core) and `lib/common` (hf-hal-common), both pinned to release tags; `version_lock.txt` checked in CI
- [ ] Board pin map added to `hf-pincfg` as `HARDFOC_BOARD_<BOARD>` (its own PR, released first)
- [ ] `CODEOWNERS`, `AGENTS.md`, `CLAUDE.md`, `.claude/skills/verify/` and `bump-pin/`; GPL-3.0; org clang configs

### Structure
- [ ] `board/<board>/`: bus table, chip list, pincfg selection; data only
- [ ] `bsp_bind/<family>/` implements the `hf::hal::bind` interface for the MCU; `bsp_bind/host/` with fakes and a settable clock
- [ ] The bind stores every object statically, sized by `kMax*` constants; `Create*` / `Destroy*` by slot
- [ ] Common managers come from `hf-hal-common`; only board-specific managers live here, each deriving from `ManagerBase`
- [ ] Managers reach chips only through handler APIs or `VisitDriver()`; no driver includes
- [ ] Every fallible manager method returns `hf::Status`; `GetLastError()`; no local error enum
- [ ] Facade `<board>::Hal` derives from `FacadeBase`; start-up order fixed and documented; fail-closed; safety-relevant managers not optional
- [ ] No ESP-IDF, FreeRTOS or `mcu/<family>/` includes outside `bsp_bind/`; rtos-wrap for locks and delays; `hf_time::MonotonicUs()` for time
- [ ] No allocation after start-up; start-up allocations allowlisted

### CI, tests and docs
- [ ] The `hf-hal-common` lints (boundary, driver access, allocation, lock) run and pass
- [ ] Host build with the host bind; tests for start-up order, fail-closed with a failure injected into each manager, diagnostics
- [ ] `examples/esp32` build for the board's MCU with `CONFIG_FREERTOS_HZ=1000`
- [ ] HAL page set with the board card, pin map, manager table, start-up order and `docs/contract.md`
- [ ] Bench list for first bring-up written in the tracking issue
```
