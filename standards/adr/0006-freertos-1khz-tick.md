# ADR-0006: FreeRTOS runs at 1 kHz everywhere

- Status: Accepted
- Date: 2026-11-03

## Context

ESP-IDF defaults to a 100 Hz tick. rtos-wrap rounds a nonzero delay up to one tick, so at 100 Hz a 1 ms wait
becomes 10 ms, which breaks datasheet timing in drivers and the CANopen 1 kHz loop on Vortex. Some projects had set
1000 Hz and some had not.

## Decision

- Every HardFOC ESP-IDF project (products, HALs, `hf-core`, every driver's `examples/esp32`) sets
  `CONFIG_FREERTOS_HZ=1000` in `sdkconfig.defaults` (and in a committed `sdkconfig`, while any remain).
- Milliseconds are converted with `pdMS_TO_TICKS()` or rtos-wrap helpers, never as raw tick counts; tick deadlines
  are compared by signed subtraction.
- Other RTOS backends use a 1 kHz kernel tick as well.

## Consequences

- One millisecond means one millisecond on every board and example.
- Ten times as many tick interrupts as the ESP-IDF default, a small and fixed CPU cost.
- `pdMS_TO_TICKS()` overflows above about 71 minutes and the tick counter wraps after about 49.7 days; code that
  waits that long uses `hf_time::MonotonicUs()` instead.
- Already applied across the org before this record was written.
