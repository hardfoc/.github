# Checklist: new handler

Copy this list into the PR that adds `hf-core/handlers/<chip>/`. [handler.md](../handler.md) is the contract. The
driver is pinned in `hf-core-drivers` first.

```markdown
### Files and build
- [ ] `handlers/<chip>/<Chip>Handler.h/.cpp` with class `hf::<Chip>Handler`
- [ ] Adapter `Hal<Bus><Chip>Comm` deriving from the driver's port base, using the shared adapter base from `handlers/common/`
- [ ] `HF_CORE_ENABLE_<CHIP>` compiles the handler and links `hf::<chip>`; listed on the Feature switches page
- [ ] Includes only the driver, `hf/iiw/Base*.h`, rtos-wrap, utils and `handlers/common/`; no `#ifdef` for an MCU or project

### Shape
- [ ] Constructor stores references only: no I/O, no driver creation, no allocation; not copyable or movable
- [ ] Driver stored in place (`std::optional<Driver>`); no `make_unique`, `new` or `shared_ptr`
- [ ] `EnsureInitialized()` returns `hf::Result<void>`, retries cleanly after a failure
- [ ] `Deinitialize()` and `IsInitialized()`
- [ ] Own `RtosMutex` taken by every public method; optional bus mutex, taken after the handler mutex
- [ ] Typed methods return `hf::Result<T>`; no driver result types, `esp_err_t` or `bool` for fallible calls
- [ ] `ToStatus(<chip>::Error)` in the adapter header: every enumerator listed, no `default:`
- [ ] `VisitDriver(fn)` returns `hf::Status`, refuses before init; no public `GetDriver()` or driver pointer
- [ ] `GetDiagnostics()` returns a struct starting with `hf::DiagnosticsHeader`, updated on every call
- [ ] Wrappers (if any) owned in fixed storage, created by `EnsureInitialized()`

### Tests and docs
- [ ] Host test over fake `Base*` objects and the driver's mock, with `HF_RTOS_NONE`: no I/O in the constructor, retry after failed init, bus failure maps to `Status::Bus`, `VisitDriver()` before init, diagnostics counts
- [ ] Handler page in `hf-core/docs/handlers/`: API, chip-specific `Error` mapping, locking, diagnostics fields
- [ ] `hf-core` `CHANGELOG.md` entry under `## [Unreleased]`
```
