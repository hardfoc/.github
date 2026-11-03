# ADR-0003: Drivers are templates on a CRTP port

- Status: Accepted
- Date: 2026-11-03

## Context

21 of 23 drivers already used a CRTP port with no virtual functions, but with about eight spellings of the same
hooks (`transfer`, `write_some`, `spiTransferTMCL` and others), five base-class names, and `void`, `int` or `bool`
returns. Optional hooks were detected with `void_t` in some repositories and `requires` in others, and one driver
silently skipped required delays when its port had no delay hook. A base class that forwards a hook to the derived
class turns a missing override into infinite recursion.

## Decision

- The port base is `<chip>::{Spi,I2c,Uart,Adc}Interface<Derived>`, non-copyable, with a protected constructor and
  no virtual functions. The driver template is constrained by a concept `<chip>::{Spi,I2c,Uart,Adc}Port`.
- Required hooks are PascalCase, `noexcept`, return `bool`, move raw bytes only, and are not declared in the base.
- Optional hooks (`DelayUs`, `DelayMs`, `GpioSet`, `GpioRead`, `Log`) are detected with C++20 `requires` in one
  helper; a missing hook falls back in a documented way or fails to compile.
- Pins are logical (`CtrlPin`, `GpioSignal::ACTIVE`); the port maps them to the board.
- Run-time polymorphism starts at the `Base*` interfaces in interface-wrap, which the handler's adapter calls.

## Consequences

- No virtual calls or vtables in drivers; the port is inlined.
- A wrong or missing hook is a compile error with a readable message.
- Every port, in hf-core adapters, examples and user code, is renamed to the standard hooks once.
- pca9685's register-addressed I2C hooks become raw `Write` / `WriteRead`.
