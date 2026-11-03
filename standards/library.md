# Library contract

What the libraries between the drivers and the board HALs provide: `hf-internal-interface-wrap`,
`hf-utils-rtos-wrap`, `hf-utils-general`, `hf-utils-canopen` and `hf-pincfg`, and how `hf-core` builds them.

## Every library

- **One CMake target per repository**, exported as `hf::<name>` for both `add_subdirectory()` and
  `find_package(hf_<name>)`:

  | Repository | Target | Include root |
  | --- | --- | --- |
  | `hf-internal-interface-wrap` | `hf::interface_wrap` | `hf/iiw/` |
  | `hf-utils-rtos-wrap` | `hf::rtos_wrap` | `hf/rtos/` |
  | `hf-utils-general` | `hf::utils_general` | `hf/utils/` |
  | `hf-utils-canopen` | `hf::utils_canopen` | `hf/canopen/` |
  | `hf-pincfg` | `hf::pincfg` | `hf/pincfg/` |

- **One include root**: every public header is reached as `#include "hf/<root>/<Header>.h"`. Two repositories
  MUST NOT ship headers that resolve to the same include path (the duplicate `Utility.h` in rtos-wrap and
  utils-general is the case this rule exists for).
- **No macros that leak**: no `MIN`, `MAX`, `ARRAY_SIZE` or similar in public headers. Use `std::min`,
  `std::size` or a `constexpr` function in the library's namespace.
- **Namespace** `hf` (or `hf::<area>`) for new code. Existing C-style APIs that the standard names (`os_*` in
  rtos-wrap, the `hf_*_t` types in interface-wrap) keep their names; new API is C++ in `hf`.
- **Versioned and released** like a driver: version in `cmake/hf_<name>_build_settings.cmake`, a generated
  version header, `CHANGELOG.md`, a release workflow ([release.md](release.md)).
- **Host tests** in `tests/host/` on gcc and clang, and compiled doc snippets in `tests/docs/`.
- **A Contract page** in the docs ([docs.md](docs.md#the-contract-page)).
- C++20, GPL-3.0, the org clang configs, no exceptions, no RTTI.

## hf-internal-interface-wrap

The MCU interfaces: abstract `Base*` peripheral classes and their implementations per MCU family.

| Part | Contains | May include |
| --- | --- | --- |
| `base/` | `BaseGpio`, `BaseAdc`, `BaseI2c`, `BaseSpi`, `BaseUart`, `BaseCan`, `BasePwm`, `BaseNvs`, `BasePeriodicTimer`, `BaseTemperature`, `BaseLogger`, `BasePio`, `BaseUsbSerialJtag`, `BaseWifi`, `BaseBluetooth`; `HardwareTypes.h`; `Status.h` | Standard headers only |
| `mcu/esp32/` | `Esp*` implementations on ESP-IDF | ESP-IDF |
| `mcu/stm32/` | `Stm*` implementations on the STM32 HAL | STM32Cube HAL |
| `mcu/host/` | `Host*` implementations for host builds and tests (`HostNvs`) | Standard headers |
| `utils/` | `HfTime.h` (`hf_time::MonotonicUs()`), memory helpers | Standard headers; selects the family backend by macro |

Rules:

- `Base*` classes are the one place above the bind with virtual functions: the bind creates the concrete object,
  and everything above holds a `Base*&`. This is the run-time boundary between portable code and the MCU.
- Each `Base*` keeps its `hf_<periph>_err_t` X-macro list and adds `hf::Status ToStatus(hf_<periph>_err_t)`
  following [errors.md](errors.md#interface-wrap-codes-to-hfstatus).
- `Initialize()` is idempotent and `EnsureInitialized()` lazy, as today; neither allocates after start-up.
- Exactly one family is compiled, chosen by `HF_MCU_FAMILY_ESP32`, `HF_MCU_FAMILY_STM32` or `HF_MCU_FAMILY_NONE`.
  Every family's sources MUST compile in CI, including STM32 (with stub SDK headers if needed).
- A header in `base/` or `utils/` MUST NOT include a file that does not exist on every family.

## hf-utils-rtos-wrap

The only RTOS access above the bind ([threading-and-timing.md](threading-and-timing.md)).

| Provides | Types |
| --- | --- |
| Locking | `RtosMutex`, `MutexLockGuard`, `CriticalGuard` |
| Delay and time in ticks | `os_delay_msec()`, `OsUtility` helpers |
| Tasks | `BaseThread`, `BaseThreadsManager` |
| Communication | `OsQueue`, `OsEventFlags`, `SignalSemaphore`, `SeqlockSnapshot` |
| Timers | `PeriodicTimer` |

Rules:

- One backend per build: `HF_RTOS_FREERTOS`, `HF_RTOS_CMSIS`, `HF_RTOS_THREADX` or `HF_RTOS_NONE`. The public API is
  the same on all four; the host tests run the FreeRTOS shim, CMSIS and none.
- Objects are statically allocated where the backend allows (FreeRTOS static API, ThreadX); a backend that
  allocates in the kernel (CMSIS-RTOS2) does so only at creation.
- No HardFOC dependency other than the selected RTOS.

## hf-utils-general

Platform-free helpers (`SoftwareVersion`, `VariableMonitor`, `TimestampedVariable`, ring buffers and the like).

- Headers and `.cpp` files; no RTOS, no vendor SDK, no global mutable state.
- A helper that needs a lock or a clock takes it as a parameter or template argument; it does not include
  rtos-wrap.
- One guide page per helper: purpose, a compiled example, complexity and memory.

## hf-utils-canopen

CANopen frame builders and CiA 402 helpers over a self-contained `CanFrame`.

- No dependency on interface-wrap or a CAN driver; the caller sends the frame.
- No allocation; frames are values.

## hf-pincfg

Header-only C++20 pin maps for HardFOC boards, as X-macro rows selected by one `HARDFOC_BOARD_*` macro.

- One header per board; `HARDFOC_BOARD_NONE` builds for tests.
- Rows name the function, the chip and the drive mode; MCU pin numbers appear only here and in the bind.
- Pin maps for boards that are not HardFOC boards do not belong here.

## hf-core build

`hf-core` gathers the drivers (through `hf-core-drivers`) and the libraries (through `hf-core-utils`) and adds the
handlers.

- `hf-core` links the library targets (`hf::interface_wrap`, `hf::rtos_wrap`, ...) and each enabled driver's
  `hf::<chip>` target. It does not copy file lists out of other repositories.
- `hf_core_build_settings.cmake` holds options and linking only.
- `HF_CORE_ENABLE_<CHIP>` and `HF_CORE_ENABLE_<FEATURE>` are the single set of feature switches. A switch compiles
  the handler and links its driver; nothing else turns a handler on.
- The RTOS backend is an `hf-core` option passed through to rtos-wrap: `HF_CORE_RTOS=FREERTOS|CMSIS|THREADX|NONE`.
- The logger (`handlers/logger/`) is the one logging API above the bind. It formats; drivers do not.
