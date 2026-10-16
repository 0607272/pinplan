# Mapping and algorithm sources

The implementation is original MoonBit code. No upstream driver/library source is copied.

- [RP2040 official datasheet](https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf): GPIO function-select mappings (UART, SPI, I2C), PWM slices and A/B channels. GPIO16 and GPIO0 are aliases for PWM slice0/channelA.
- [Raspberry Pi Pico official datasheet](https://datasheets.raspberrypi.com/pico/pico-datasheet.pdf): original Pico pinout; GPIO0–22 and GPIO26–28 are brought out, GPIO23–25 are board-internal, GPIO29 is not a free header GPIO.
- [Official Pico documentation](https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html): product documentation entry point.

PinPlan explicitly permits mixed alternative signal mappings belonging to the same peripheral instance. SPI currently requires RX/CS/SCK/TX and models hardware CSn. It does not configure firmware GPIO multiplexers or verify external electrical connections.

The solver uses a conventional deterministic depth-first backtracking search with incremental resource checks and an explicit work budget. This is a general algorithm, not a source port. Test fixtures are authored for this project.

The official documents remain under their original terms and are not bundled or relicensed. PinPlan's MIT license covers its own source. The MoonBit core dependency remains Apache-2.0. `sbqrre/moonbit-mcu-hal` (Apache-2.0) was examined as an ecosystem comparison, and is not a runtime dependency.

Development uses AI assistance; the project owner should review the mappings, tests and public claims before competition submission. Generated code is subject to the same testing and review as other code.

## Scope comparison (2026-10-16)

`moon search moonplan --limit 10 --json` returned `cn-xjr/moonplan` 0.1.0. The [public MoonPlan README](https://github.com/cn-xjr/MoonPlan) was also read. It already describes finite-domain constraints, bounded solving, irreducible conflict sets and scheduling repair/optimization. These general concepts are not claimed as inventions of PinPlan.

PinPlan does not import or vendor MoonPlan. Its module/package manifests, current source imports and Git history were inspected for this comparison. The shared use of conventional backtracking, deletion testing and branch-and-bound is an algorithmic similarity; no MoonPlan source was used to implement this update. MoonPlan is Apache-2.0 and is cited as an ecosystem comparison, not a runtime dependency.

The concrete PinPlan work is the RP2040 resource model and candidate semantics, hard-lock versus baseline-wiring optimization, per-device-signal change accounting, verified device-level conflict reduction, physical Pico header projection, and their strict JSON/CLI/browser workflows and tests. The examples in `fixtures/rewire-*.json`, `diagnose-uart.json` and `shared-wiring.json` are authored logical configurations, not measured hardware experiments or third-party datasets.

`wiring.mbt` maps GPIO to physical contact numbers using the Pico datasheet pinout. The browser's 40-contact view uses the same original Pico pinout, oriented with USB at the top and the component side facing the viewer. Neither output includes an electrical validation or firmware initialization guarantee.
