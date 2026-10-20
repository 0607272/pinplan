# Board context and verified exports

Continue the approved Pico project with three bounded capabilities: request-wide reserved GPIOs, optional normal 7-bit I2C addresses, and MoonBit-generated CSV/C configuration constants. No additional board support or hardware driver generation.

1. Add regression tests for reserved pins, repair/diagnosis context, address collisions and safe exports; demonstrate failure before implementation.
2. Propagate optional `reserved_pins=[]` through all core operations. Reject duplicate/unavailable reservations. Planning against a reserved hard lock is unsatisfiable; checking such wiring is invalid. Baseline wiring may occupy a newly reserved GPIO.
3. Add `i2c_address=None` to Device/Assignment. Only I2C accepts addresses 8..119. Equal known addresses on an explicitly shared bus conflict. Unknown addresses remain explicitly unknown.
4. Generate exports only after independent validation. CSV uses quoted cells and neutralizes spreadsheet formula prefixes in user names. C uses numeric device indices, fixed signal names and numeric constants, never raw names. Constants do not initialize hardware.
5. Expose CSV/header through CLI `--format` and browser downloads. Failed exports emit no file content; CLI errors go to stderr with existing status codes.
6. Update examples, protocol/compatibility docs and version 0.2.0; run MoonBit targets and Node integration checks, browser workflow and independent code review; commit and push to the authorized main branch. Keep personal submission documents ignored.

Budget, endpoint-change cost and irreducible-core semantics remain unchanged. Diagnosis deletion tests keep the same board context. A solved budget-limited repair is exportable but must retain its optimality warning in the JSON report and export comments/metadata. I2C addresses are declared hardware facts, never automatically reassigned. Adding a public record field requires migration for record literals; constructor calls retain defaults.
