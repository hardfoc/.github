# Handler contract

What every handler in `hf-core/handlers/<chip>/` provides. A handler turns one platform-free driver into a
thread-safe, `hf::Status`-speaking object that a board HAL can own. There is one handler family; the "rich" and
"bus" families found in the November 2026 review converge on this shape.

## Files and names

```text
hf-core/handlers/<chip>/
├── <Chip>Handler.h / .cpp      the handler: class hf::<Chip>Handler
├── Hal<Bus><Chip>Comm.h / .cpp  the adapter: implements the driver's port with Base* calls, plus ToStatus()
└── <Chip><Periph>Wrapper.h      optional: presents part of the chip as a Base* (BaseAdc, BaseGpio, ...)
```

- Handlers live in `namespace hf`: `hf::Bmp581Handler`, `hf::Tmc9660Handler`.
- Adapters are named `Hal{Bus}{Chip}Comm`: `HalSpiTmc9660Comm`, `HalUartTmc9660Comm`, `HalI2cBmp581Comm`.
- Each handler compiles only when its switch is on: `HF_CORE_ENABLE_<CHIP>` (the single feature switch,
  [library.md](library.md#hf-core-build)).
- Includes use one style: `#include "hf/iiw/BaseI2c.h"`, `#include "bmp581.hpp"`, `#include "hf/rtos/RtosMutex.h"`.

## Shape

```cpp
namespace hf {

struct Bmp581HandlerConfig {
  uint8_t address = 0x47;
  bmp581::Config driver{};
};

struct Bmp581Diagnostics {
  DiagnosticsHeader header;          // always first
  uint32_t fifo_overflows = 0;       // chip-specific counters follow
};

class Bmp581Handler {
public:
  Bmp581Handler(BaseI2c& i2c, const Bmp581HandlerConfig& config = {},
                RtosMutex* bus_mutex = nullptr) noexcept;   // stores references; no I/O
  Bmp581Handler(const Bmp581Handler&) = delete;
  Bmp581Handler& operator=(const Bmp581Handler&) = delete;

  Result<void> EnsureInitialized() noexcept;   // builds the driver in place, runs its Initialize()
  Result<void> Deinitialize() noexcept;
  [[nodiscard]] bool IsInitialized() const noexcept;

  Result<float> ReadPressurePa() noexcept;     // the typed API: each call locks, maps, counts

  template <typename Fn>
  Status VisitDriver(Fn&& fn) noexcept;        // fn(bmp581::BMP581<HalI2cBmp581Comm>&) -> Status

  [[nodiscard]] Bmp581Diagnostics GetDiagnostics() const noexcept;

private:
  using Driver = bmp581::BMP581<HalI2cBmp581Comm>;

  HalI2cBmp581Comm comm_;
  std::optional<Driver> driver_;   // in place: no heap
  Bmp581HandlerConfig config_;
  mutable RtosMutex mutex_;
  RtosMutex* bus_mutex_;
  Bmp581Diagnostics diag_{};
};

} // namespace hf
```

## Rules

### Construction and lifecycle

- The constructor MUST NOT touch hardware, create the driver or allocate. It stores references to `Base*`
  interfaces that the HAL owns and that outlive the handler.
- Handlers are neither copyable nor movable.
- Driver storage is in place: `std::optional<Driver>` (or aligned storage) emplaced by `EnsureInitialized()`.
  `make_unique`, `new` and `nothrow new` are not allowed.
- `EnsureInitialized()` returns `Result<void>`. On first call it emplaces the driver over the adapter and runs the
  driver's `EnsureInitialized()`; on failure it destroys the driver again, so the next call retries from scratch.
  It returns at once when already initialised.
- Every public method that needs the chip calls `EnsureInitialized()` itself or returns `NotInitialized`; the
  handler page says which.
- `Deinitialize()` runs the driver's `Deinitialize()` and destroys it.

### Locking

- Each handler has its own `RtosMutex` (from rtos-wrap, [threading-and-timing.md](threading-and-timing.md)).
  Every public method takes it with `MutexLockGuard` for its whole duration.
- Devices that share a bus MAY share a bus mutex passed to the constructor. The order is always handler mutex,
  then bus mutex, and both are released before the method returns.
- A handler MUST NOT call another handler while holding its locks.

### Driver access

- There is no public `GetDriver()`, raw driver pointer or reference. Code that needs a driver feature the typed
  API does not wrap uses `VisitDriver()`:

  ```cpp
  uint32_t fifo_level = 0;
  hf::Status s = bmp581.VisitDriver([&](auto& drv) {
    auto r = drv.ReadFifoLevel();
    fifo_level = r.value;
    return hf::ToStatus(r.error);
  });
  ```

- `VisitDriver()` takes the handler lock (and the bus lock), returns `NotInitialized` without calling `fn` if the
  handler is not initialised, otherwise calls `fn` with the driver and returns its `Status`. `fn` MUST NOT store the
  reference.
- A feature used through `VisitDriver()` in more than one place SHOULD become a typed method.

### Errors

- Typed methods return `hf::Result<T>`. Driver errors are mapped once, by the `ToStatus(<chip>::Error)` in the
  adapter header ([errors.md](errors.md#driver-error-to-hfstatus)), with the driver code as `detail`.
- Handlers MUST NOT return driver result types, `esp_err_t` or `bool` from a call that can fail.

### The adapter

- The adapter derives from the driver's port base (`bmp581::I2cInterface<HalI2cBmp581Comm>`) and implements its
  hooks with `BaseI2c` / `BaseSpi` / `BaseUart` / `BaseGpio` calls. It translates `hf_*_err_t` failures into
  `false`, which the driver reports as `Error::Bus`.
- The delay hooks call `hf::DelayUs()` / `hf::DelayMs()` from `handlers/common/`, which follow
  [threading-and-timing.md](threading-and-timing.md#delays); the `Log` hook forwards to the hf-core logger.
- Shared adapter bases in `handlers/common/` (`HalSpiCommBase`, `HalI2cCommBase`, `HalUartCommBase`) hold the bus
  reference, the CS / pin mapping and the delay and log hooks, so a new adapter only adds what is chip-specific.

### Diagnostics

Every handler has `GetDiagnostics()`, returning a struct whose first member is the common header:

```cpp
namespace hf {

struct DiagnosticsHeader {
  bool initialized = false;
  uint32_t ok_count = 0;          // calls that returned Ok
  uint32_t error_count = 0;       // calls that returned anything else
  Status last_error = Status::Ok;
  uint16_t last_error_detail = 0; // the driver's Error value
  uint64_t last_error_us = 0;     // hf_time::MonotonicUs() at the last error
};

} // namespace hf
```

The header is updated by the handler on every typed call and every `VisitDriver()`. Chip-specific counters and
sticky chip status follow it. `GetDiagnostics()` takes the lock, copies, and returns.

### Wrappers

A wrapper that presents part of a chip as a `Base*` (`Tmc9660AdcWrapper`, a `BaseGpio` per expander pin) is owned
by the handler in a fixed array, created by `EnsureInitialized()`, and forwards through the handler's locked API.
It is not created with `std::shared_ptr` or on demand.

### Platform independence

- Handlers include only `Base*` headers, drivers, rtos-wrap and utils ([layers.md](layers.md#includes)). They
  compile for every MCU family and on the host.
- A handler MUST NOT take `gpio_num_t`, return `esp_err_t`, or contain `#ifdef` blocks for one MCU or project. A
  chip that needs an MCU peripheral directly (the WS2812 RMT) has a `Base*` interface for it, implemented in the
  bind.

## Tests

- Every handler has a host test in `hf-core/tests/host/` that builds it over a fake `Base*` and the driver's mock:
  construction does no I/O, `EnsureInitialized()` retries after failure, every typed method maps a bus failure to
  `Status::Bus`, `VisitDriver()` refuses before init, and the diagnostics header counts.
- The test runs with `HF_RTOS_NONE`.
