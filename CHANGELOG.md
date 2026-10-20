# Changelog

## 0.2.1 — 2026-10-20

- Show reserved GPIOs as gold squares with explicit labels and an accessible legend on the browser pinout, including unsatisfiable requests. Verified wiring remains green; non-GPIO contacts cannot be mistaken for GPIO reservations.
- Resolve CLI input paths relative to the caller's working directory. Accept UTF-8 BOM, reject malformed/truncated UTF-8 with `INPUT_ENCODING`, and decode incrementally so inputs exceeding 65536 UTF-16 units are rejected before EOF.
- Verify public typed APIs from a separate module using a clean local dependency. Add Windows CLI/encoding regressions and Linux/Windows consumer checks to CI; document official acceptance requirements and remaining registry publication work.

## 0.2.0 — 2026-10-20

- Add request-wide `reserved_pins` to planning, checking, minimum-change repair and device diagnosis. Preserve reservations through deletion tests, independent checks and exports; allow baseline wires to move away from newly reserved GPIOs.
- Add optional normal 7-bit `i2c_address` metadata (8..119), reject equal known addresses on explicitly shared I2C buses, and retain unknown addresses as `null`.
- Generate verified CSV and Pico C constants in MoonBit, expose CLI `--format json|csv|pico-header` and browser downloads. Invalid results produce no artifacts. Numeric device indices prevent C identifier/comment injection; CSV quotes fields and prefixes user names for spreadsheet safety.
- Add board-context regressions, two runnable workflows, C11 compiler assertions in Linux CI, and document API record-literal migration. These changes do not provide hardware initialization, voltage checks or live bus discovery.

Constructor calls remain compatible via defaults. Direct `Device` and `Assignment` literals must add `i2c_address: None`. JSON schema version 1 receives optional input/additional output fields; consumers that whitelist response keys must accept `reserved_pins`, assignment `i2c_address` and solved `exports`.

## 0.1.0

Initial Pico resource planning, wiring checks, bounded minimum-change repair, irreducible device diagnosis, physical contact mapping, strict JSON/CLI/browser workflows and CI.
