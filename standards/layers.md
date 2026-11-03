# Layers

The HardFOC stack, what each layer promises to the one above, what it may depend on, and which includes are
allowed. The per-layer pages give the detail; this page is the contract between them.

## The stack

```text
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ Product app            hardfoc-<board>-v1            namespace <board>::app  │
 │   uses the HAL facade and managers, rtos-wrap, the hf-core logger            │
 ├──────────────────────────────────────────────────────────────────────────────┤
 │ Board HAL              hf-hal-<board>-v1             namespace <board>       │
 │   board config, board-specific managers, on top of hf-hal-common (hf::hal)   │
 │  ┌────────────────────────────────────────────────────────────────────────┐  │
 │  │ Platform bind      bsp_bind/<family>     the only code naming the MCU  │  │
 │  └────────────────────────────────────────────────────────────────────────┘  │
 ├──────────────────────────────────────────────────────────────────────────────┤
 │ hf-core handlers       hf-core/handlers/<chip>       namespace hf            │
 │   one handler per chip: lock, lifecycle, error mapping, VisitDriver          │
 ├──────────────────────────────────────────────────────────────────────────────┤
 │ MCU interfaces and utilities                                                 │
 │   hf-internal-interface-wrap (Base*, Esp*, Stm*, Host*), hf-utils-rtos-wrap, │
 │   hf-utils-general, hf-utils-canopen, hf-pincfg                              │
 ├──────────────────────────────────────────────────────────────────────────────┤
 │ Chip drivers           hf-<chip>-driver              namespace <chip>        │
 │   platform-free C++20 templates on a CRTP port                               │
 └──────────────────────────────────────────────────────────────────────────────┘
```

Dependencies point down only. A layer MUST NOT include, link or call anything above it, and the submodule graph
MUST stay acyclic: product → HAL → `hf-core` → `hf-core-drivers` / `hf-core-utils` → drivers and libraries.

Drivers and the MCU interfaces and utilities are both leaves: neither includes the other. They meet in the
handler, where an adapter implements a driver's port with `Base*` calls.

## What each layer promises and depends on

| Layer | Promises to the layer above | Depends on | Page |
| --- | --- | --- | --- |
| Chip driver | The chip's full feature set as typed calls returning `Result<T>`; no I/O before `Initialize()`; no heap, no platform code | The C++ standard library (freestanding subset) and its own port | [driver.md](driver.md) |
| MCU interfaces | `Base*` peripheral classes with the same behaviour on every MCU family; `ToStatus()` for every error type | The vendor SDK, only inside `mcu/<family>/` | [library.md](library.md) |
| rtos-wrap | The only mutex, delay, thread, queue and timer types; the same API on FreeRTOS, CMSIS-RTOS2, ThreadX and none | The selected RTOS, only inside `os/` | [library.md](library.md) |
| utils | Platform-free helpers and CANopen frame builders | The C++ standard library | [library.md](library.md) |
| Handler | A thread-safe, typed API per chip returning `hf::Result<T>`; `VisitDriver()` for the rest; diagnostics | Drivers, `Base*`, rtos-wrap, utils | [handler.md](handler.md) |
| Platform bind | `Base*` objects for the board's buses and pins, created and destroyed by slot; reset reason, restart, heap figures, LED strip | The MCU family's `Esp*` / `Stm*` / `Host*` classes and SDK | [hal.md](hal.md) |
| Board HAL | One facade with ordered, fail-closed start-up, one manager per board function, `hf::Status` everywhere, one `CollectDiagnostics()` | `hf-hal-common`, handlers, `Base*`, rtos-wrap, pincfg, its bind | [hal.md](hal.md) |
| Product | The board's behaviour: tasks, protocols, faults | The HAL facade and managers, rtos-wrap, the hf-core logger | [product.md](product.md) |

## Includes

Paths below use the one-root-per-repository layout from [naming-and-style.md](naming-and-style.md#include-roots-and-headers)
(`hf/iiw/...`, `hf/rtos/...`). Until a repository moves to it, the rule applies to the equivalent header.

| Code in | MAY include | MUST NOT include |
| --- | --- | --- |
| Driver (`inc/`, `src/`) | `<cstdint>`, `<cstddef>`, `<array>`, `<algorithm>`, `<type_traits>`, `<concepts>`, `<limits>`, `<cmath>`, `<cstring>`, `<span>`, `<utility>`, `<optional>`, `<bit>`; its own headers | Any HardFOC repository; any vendor SDK, RTOS or `esp_*` header; `<iostream>`, `<cstdio>`, `<string>`, `<functional>`, `<memory>`, `<vector>`, `<map>`, `<thread>`, `<mutex>` |
| interface-wrap `base/`, `utils/` | Standard headers; other `base/` headers; `HardwareTypes.h` | Any `mcu/<family>/` header; any vendor SDK or RTOS header |
| interface-wrap `mcu/<family>/` | Its family's SDK; `base/`; `utils/` | Another family's headers; rtos-wrap internals |
| rtos-wrap | Standard headers; the selected RTOS, only in `os/` and the `.cpp` files | interface-wrap `mcu/`; any HAL or driver |
| utils-general, utils-canopen, pincfg | Standard headers | Any RTOS, vendor SDK or other HardFOC repository |
| Handler (`hf-core/handlers/`) | Its driver's umbrella header; `hf/iiw/Base*.h`; rtos-wrap; utils; `handlers/common/` | `mcu/<family>/` headers; vendor SDK or RTOS headers; HAL or product headers |
| Platform bind (`bsp_bind/<family>/`) | Everything below it, including `Esp*` / `Stm*` / `Host*` and the SDK | Product headers; another family's bind |
| HAL outside `bsp_bind/` | `hf-hal-common`; handlers; `hf/iiw/Base*.h`; rtos-wrap; pincfg; the bind's interface header | Vendor SDK, `esp_*`, FreeRTOS headers; `mcu/<family>/`; driver headers (drivers are reached through `VisitDriver()`) |
| Product outside `platform/` | The HAL's public API headers (facade and managers); rtos-wrap; the hf-core logger | Handlers; drivers; `Base*`; `mcu/<family>/`; vendor SDK or raw FreeRTOS |
| Product `platform/` | The vendor SDK, for start-up, partitions, OTA and the console | Handlers and drivers |

Tests and `examples/` may include whatever they exercise; the rules apply to library code.

### How the rules are enforced

- **Drivers**: the host test build compiles every header with `-fno-exceptions -fno-rtti` and no platform include
  paths, so a forbidden include fails to compile.
- **HALs**: the boundary lint (`tools/lint/lint_hal_boundary.sh`, moving to `hf-hal-common`) rejects SDK, RTOS and
  driver includes outside `bsp_bind/`, and calls that reach a driver without `VisitDriver()`.
- **Products**: the same lint, run over everything outside `platform/`.
- **Everyone**: reviewers check the table above; a new exception is a change to this page.

## Layer skips are defects

Code that reaches past the layer below it is a defect even when it works, because the skipped layer's lock,
lifecycle or error mapping no longer applies. Fix it by adding the missing call to the layer that was skipped.
Examples found in the November 2026 review:

- A manager calling a driver through a handler's `GetDriver()`, which bypasses the handler lock.
- An application calling an `Esp*` class or raw FreeRTOS instead of the facade and rtos-wrap.
- Middleware including a handler header.
