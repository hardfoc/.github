# Board HAL contract

What a board HAL (`hf-hal-<board>-v1`) provides, what moves into the shared `hf-hal-common`, and the shape of the
platform bind (`bsp_bind/<family>`). Decision: [ADR-0005](adr/0005-hf-hal-common.md).

## What lives where

| Repository / folder | Contains | Namespace |
| --- | --- | --- |
| `hf-hal-common` | `ManagerBase`, `FacadeBase`, `ManagerId`, the `PlatformBind` interface, the six common managers (NVS, LED, GPIO, ADC, temperature, comms), the diagnostics collector and the boundary lints | `hf::hal` |
| `hf-hal-<board>-v1` | The board config (pin map selection, bus table, chip list), the bind for its MCU family, the board-specific managers (Vortex: motor, IMU, encoder; Flux: valves), the board facade, its examples | `<board>` (`vortex`, `flux`) |
| `bsp_bind/<family>/` in the HAL | The only code that names the MCU family: creates `Esp*` / `Stm*` / `Host*` objects from the board config | `<board>::bsp` |

A board HAL MUST NOT carry its own copy of anything in `hf-hal-common`. A manager that two boards need moves to
`hf-hal-common`; a manager only one board needs stays in that HAL.

`hf-hal-common` is consumed as a submodule (`lib/common`) pinned to a release tag, next to `lib/core` (`hf-core`).

## Managers

```cpp
namespace hf::hal {

enum class ManagerId : uint8_t {
  Nvs, Led, Gpio, Adc, Temperature, Comms,  // common managers
  Board = 32,                               // board-specific managers number from here
};

class ManagerBase {
public:
  virtual ~ManagerBase() = default;
  [[nodiscard]] virtual ManagerId Id() const noexcept = 0;
  [[nodiscard]] virtual const char* Name() const noexcept = 0;

  virtual hf::Status Initialize() noexcept = 0;    // idempotent
  virtual hf::Status Deinitialize() noexcept = 0;  // to the safe state
  [[nodiscard]] bool IsInitialized() const noexcept;

  [[nodiscard]] hf::Status GetLastError() const noexcept;
  void ClearLastError() noexcept;

  virtual void CollectDiagnostics(DiagnosticsSink& sink) const noexcept = 0;
};

} // namespace hf::hal
```

Rules:

- One manager per board function. A manager owns the handlers for its function and the `Base*` objects the bind
  created for them.
- Managers reach chips only through their handlers' typed API or `VisitDriver()`. A manager MUST NOT include a
  driver header or hold a driver pointer.
- Every fallible method returns `hf::Status` ([errors.md](errors.md#managers-and-the-facade)). There is no
  `ManagerError` enum.
- Managers are created by the facade in static storage. No heap after start-up; allocation during `Initialize()`
  is allowed only for objects that live until reset, and the HAL's allocation lint lists them.
- Managers are thread-safe: each public method takes the manager's `RtosMutex` or delegates to a thread-safe
  handler.
- `CollectDiagnostics()` writes the manager's state and the `DiagnosticsHeader` of each handler it owns into the
  sink; it does not log.

## Facade and start-up

```cpp
namespace hf::hal {

struct StartupResult {
  hf::Status status = hf::Status::Ok;
  ManagerId manager = ManagerId::Nvs;  // the first manager that failed; meaningless when status is Ok
};

class FacadeBase {
public:
  StartupResult Initialize() noexcept;   // ordered, fail-closed
  void Deinitialize() noexcept;          // reverse order
  void CollectDiagnostics(DiagnosticsSink& sink) const noexcept;

protected:
  explicit FacadeBase(std::span<ManagerBase* const> start_order) noexcept;
};

} // namespace hf::hal
```

- The board facade (`vortex::Hal`, `flux::Hal`) derives from `FacadeBase` and passes its managers in start-up
  order. The order is fixed at compile time and documented on the HAL's Architecture page.
- **Fail-closed**: `Initialize()` starts managers in order and stops at the first failure. It then deinitialises
  the managers already started, in reverse, so every output is back in its safe state, and returns the failing
  manager and its status.
- A manager the board can run without is marked optional in the start order; its failure is recorded in the
  diagnostics and start-up continues. Safety-relevant managers (motor, valves, power) are never optional.
- The facade is the product's only entry point. It exposes the managers by reference and nothing below them.
- `CollectDiagnostics()` visits every manager. It is the one diagnostics call a product makes.

## The platform bind

The bind is the only code that names the MCU family. It turns the board config into `Base*` objects. There is one
interface, starting from Flux's shape:

```cpp
namespace hf::hal::bind {

// Peripherals, created and destroyed by slot. Specs carry raw pins resolved from the board config.
BaseGpio* CreateGpio(size_t slot, const GpioSpec& spec) noexcept;
void DestroyGpio(size_t slot) noexcept;
bool CreateSpiBus(size_t bus, const SpiBusSpec& spec) noexcept;
BaseSpi* CreateSpiDevice(size_t bus, const SpiDeviceSpec& spec) noexcept;
void DestroySpiBus(size_t bus) noexcept;
BaseI2c* CreateI2cDevice(size_t bus, const I2cDeviceSpec& spec) noexcept;
BaseUart* CreateUart(const UartSpec& spec) noexcept;
BaseCan* CreateCan(const CanSpec& spec) noexcept;
BaseAdc* CreateInternalAdc(uint8_t unit, uint32_t channel_mask) noexcept;
BaseTemperature* CreateDieTemperature() noexcept;
BaseNvs& NvsRegion(size_t slot, const char* name_space) noexcept;

// LED strip
bool LedStripBegin(const LedStripSpec& spec) noexcept;
void LedStripSetPixel(uint16_t index, uint32_t rgb) noexcept;
bool LedStripShow() noexcept;
void LedStripEnd() noexcept;

// System
uint64_t MonotonicMicros() noexcept;
uint32_t LastResetReason() noexcept;
[[noreturn]] void SystemRestart() noexcept;
uint32_t FreeHeapBytes() noexcept;
uint32_t LargestFreeHeapBlock() noexcept;

} // namespace hf::hal::bind
```

Rules:

- Verbs are `Create*` / `Destroy*` (and `Acquire*` for singletons the SDK owns). Each `Create*` returns `nullptr`
  or `false` on failure and is idempotent per slot.
- Buses are slots (`bus`, `slot` indices below `kMax*` constants), so a board with two SPI controllers and four
  devices each needs no new API.
- The bind stores every object it creates in static storage sized by the `kMax*` constants. It does not allocate
  after start-up.
- Every family has a bind: `esp32c6/`, `esp32s3/`, `stm32h7/` as boards need them, and `host/`, which backs the
  host tests with fakes and a settable clock.
- The bind's interface header includes only `Base*` headers and standard headers, so the HAL above it compiles
  for every family.

## Board config

- One `board/<board>/` folder holds the bus table, the chip list and the selection of the `hf-pincfg` board
  (`HARDFOC_BOARD_<BOARD>`). It contains data, not logic.
- Raw pin numbers appear only in `hf-pincfg` and the board config; managers use functional pin names.

## Lints

`hf-hal-common` ships the merged lints of both HALs, run in every HAL's CI:

| Lint | Fails on |
| --- | --- |
| Boundary | an ESP-IDF, FreeRTOS, `mcu/<family>/` or driver include outside `bsp_bind/` |
| Driver access | `GetDriver()`, a driver pointer, or a driver call outside `VisitDriver()` |
| Allocation | `new`, `malloc`, `make_unique`, `make_shared`, `std::vector` growth outside the allowlisted start-up code |
| Lock | a raw RTOS lock, or a manager holding its lock across a call into another manager |

An exception goes in the lint's allowlist file in the HAL, with a comment naming the issue that removes it.

## Tests and docs

- The HAL builds on the host with the `host/` bind, and `tests/host/` covers start-up order, fail-closed
  behaviour (inject a failure into each manager in turn), and `CollectDiagnostics()`.
- Examples in `examples/esp32/` build in CI for the board's MCU.
- The HAL page set in [docs.md](docs.md), with the start-up order and the manager table on the Architecture page.
