# Threading and timing

One lock, one clock and one delay above the platform bind, and one tick rate everywhere. Decision for the tick:
[ADR-0006](adr/0006-freertos-1khz-tick.md).

## Who may call the RTOS

| Code | RTOS access |
| --- | --- |
| Drivers | None. Drivers do not lock, sleep or create tasks; they wait only through the port's delay hooks. |
| utils-general, utils-canopen, pincfg | None. |
| interface-wrap `base/` | None. `mcu/<family>/` classes MAY use the SDK's own primitives internally. |
| rtos-wrap | The only code that includes RTOS headers (`os/os_freertos.h`, `os_cmsis.h`, `os_threadx.h`, `os_none.h`). |
| Handlers, HALs, products | rtos-wrap only. |
| `bsp_bind/<family>/`, product `platform/` | MAY use the SDK and RTOS directly for start-up and family-specific work. |

Raw `xTaskCreate`, `xSemaphoreTake`, `vTaskDelay`, `std::mutex` or `std::thread` above the bind is a defect.

rtos-wrap selects its backend with exactly one of `HF_RTOS_FREERTOS`, `HF_RTOS_CMSIS`, `HF_RTOS_THREADX` or
`HF_RTOS_NONE` (host tests and bare-metal). Code above it MUST work on all four; anything backend-specific stays
inside rtos-wrap.

## One lock

- The only mutex above the bind is `RtosMutex`, taken with `MutexLockGuard` (`RtosUniqueLock<RtosMutex>`):

  ```cpp
  #include "hf/rtos/RtosMutex.h"

  hf::Result<float> Bmp581Handler::ReadPressurePa() noexcept {
    MutexLockGuard lock(mutex_);
    // ...
  }
  ```

- Other mutex families (`PlatformMutexBackend`, per-HAL mutex wrappers, the CANopen driver's private lock) are
  retired; the CANopen lock moves to rtos-wrap.
- Locks are held for the duration of one call. No lock is held across a `DelayMs()` longer than the operation
  requires, across a callback into other code, or across a call into another handler.
- Lock order: handler mutex, then bus mutex. Managers call handlers without holding their own lock when they can;
  when they cannot, the order is manager, handler, bus.
- ISRs never take a mutex. They set an `OsEventFlags` bit or give a `SignalSemaphore` and return.

## One clock

- The only time source above the bind is `hf_time::MonotonicUs()` (`hf/iiw/HfTime.h`): microseconds since boot,
  64-bit, monotonic, safe from any task and from ISRs.
- `esp_timer_get_time()`, `xTaskGetTickCount()`, `HAL_GetTick()` and `std::chrono::steady_clock` are not used above
  the bind. The bind's `MonotonicMicros()` returns the same counter and exists so the host bind can drive a fake
  clock in tests.
- Durations are `uint32_t` or `uint64_t` with a unit suffix (`timeout_ms`, `period_us`). Deadlines are compared
  by subtraction, never with `>`:

  ```cpp
  const uint64_t deadline_us = hf_time::MonotonicUs() + timeout_us;
  while (static_cast<int64_t>(hf_time::MonotonicUs() - deadline_us) < 0) { /* poll */ }
  ```

## Delays

| Delay | Call | Behaviour |
| --- | --- | --- |
| 1 ms and longer | `os_delay_msec(ms)` (rtos-wrap) | Blocks the task; rounds a nonzero delay up to at least one tick |
| Under 1 ms | `hf::DelayUs(us)` (`hf-core/handlers/common`) | Busy-waits on `hf_time::MonotonicUs()`; no RTOS call |
| In a driver | the port's `DelayUs()` / `DelayMs()` hooks | Implemented by the adapter with the two rows above |

- `hf::DelayUs()` with 1000 µs or more rounds up to whole milliseconds and calls `os_delay_msec()`, so a datasheet
  minimum of 2.5 ms never becomes 2 ms.
- Busy-waits longer than 100 µs SHOULD be avoided in tasks above idle priority; restructure as a poll with a
  millisecond delay.
- `hf::DelayUs()` and `hf::DelayMs()` MUST NOT test `ESP_PLATFORM` or any MCU macro; the MCU-specific part is in
  `hf_time` and rtos-wrap.

## The 1 kHz tick

Every HardFOC ESP-IDF project runs FreeRTOS at 1000 Hz: products, board HALs, `hf-core` and every driver's
`examples/esp32` project. ESP-IDF's default of 100 Hz turns a 1 ms wait into 10 ms, and rtos-wrap's millisecond
helpers assume at least 1 kHz.

- Set `CONFIG_FREERTOS_HZ=1000` in `sdkconfig.defaults`. A project that still commits a full `sdkconfig` (the
  standard phases these out) sets it there too, because a committed `sdkconfig` overrides the defaults files.
- Convert milliseconds with `pdMS_TO_TICKS()` (inside rtos-wrap) or the rtos-wrap helpers. Never pass a raw tick
  count that assumes a rate.
- At 1 kHz, `pdMS_TO_TICKS()` overflows its 32-bit arithmetic above about 71 minutes, and the tick counter wraps
  after about 49.7 days: compare tick deadlines with `(int32_t)(now - deadline) > 0`.
- `hf-espidf-project-tools/setup_basic.sh` writes the setting into new projects. CI SHOULD fail a build whose
  effective `CONFIG_FREERTOS_HZ` is not 1000.
- CMSIS-RTOS2 and ThreadX builds SHOULD use a 1 kHz kernel tick as well, so timing behaves the same on STM32.

## Tasks

- Tasks are created through rtos-wrap (`BaseThread`, `BaseThreadsManager`) by the product or a HAL manager, never by
  a handler or a driver.
- Stack sizes and priorities are named constants in one header per product (`<board>::app::kTaskConfig`), not
  literals at the call site.
- Core affinity is a product decision, in that header. HAL code does not assume a dual-core MCU.
- Work that must happen at a fixed rate uses `PeriodicTimer` or a task loop on `os_delay_msec()` with drift
  correction, not a chain of delays.

## What crosses tasks

- Data shared between tasks is either protected by one `RtosMutex`, passed through an `OsQueue`, or published with
  `SeqlockSnapshot` for one writer and many readers.
- Callbacks from handlers into the product run in the caller's task. A callback that must reach another task posts
  to a queue.
