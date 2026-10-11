# Mapping and algorithm sources

The implementation is original MoonBit code. No upstream driver/library source is copied.

- [RP2040 official datasheet](https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf): GPIO function-select mappings (UART, SPI, I2C), PWM slices and A/B channels. GPIO16 and GPIO0 are aliases for PWM slice0/channelA.
- [Raspberry Pi Pico official datasheet](https://datasheets.raspberrypi.com/pico/pico-datasheet.pdf): original Pico pinout; GPIO0–22 and GPIO26–28 are brought out, GPIO23–25 are board-internal, GPIO29 is not a free header GPIO.
- [Official Pico documentation](https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html): product documentation entry point.

PinPlan explicitly permits mixed alternative signal mappings belonging to the same peripheral instance. SPI currently requires RX/CS/SCK/TX and models hardware CSn. It does not configure firmware GPIO multiplexers or verify external electrical connections.

The solver uses a conventional deterministic depth-first backtracking search with incremental resource checks and an explicit work budget. This is a general algorithm, not a source port. Test fixtures are authored for this project.

The official documents remain under their original terms and are not bundled or relicensed. PinPlan's MIT license covers its own source. The MoonBit core dependency remains Apache-2.0. `sbqrre/moonbit-mcu-hal` (Apache-2.0) was examined as an ecosystem comparison, and is not a runtime dependency.

Development uses AI assistance; the project owner should review the mappings, tests and public claims before competition submission. Generated code is subject to the same testing and review as other code.
