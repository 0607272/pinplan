# PinPlan independent workflow implementation plan

Goal: implement the repair/diagnosis/wiring workflow defined in [the design](../specs/2026-10-16-repair-diagnosis.md), with examples supporting the October preliminary-review response.

Execution: inline in this chat under the user's request to modify the project. Preserve history and private proposal; no external registration or messaging. Use current MoonBit 0.10.14+ and Node 20+, no added dependencies.

- [x] Repair: add `repair_wbtest.mbt` first; implement `repair.mbt` with baseline validation, stable local cost ordering, suffix lower bounds, branch-and-bound, changed-signal output and truthful budget/optimality flags. Check cases: zero changes; PWM0/16 alias needs one move; locked PWM0 forces the other device to GPIO1; invalid baseline; no incumbent at zero budget; infeasible locks; independently enumerated two-PWM optimum.
- [x] Diagnosis: add `diagnose_wbtest.mbt` first; implement `diagnose.mbt` with one shared budget and deletion tests. Assert unrelated devices are removed, three UARTs form a three-device core, singleton mapping failures are retained, and timeouts cannot certify irreducibility.
- [x] Wiring: test physical pins GPIO0=1, GPIO1=2, GPIO22=29, GPIO26=31, GPIO28=34 and shared I2C rows; implement `wiring.mbt` with verified-only export.
- [x] Boundary: write Node integration tests for the new modes and baseline schema rejection, extend `json_api.mbt`, then run build and integration tests. All new fields use strict schema checks.
- [x] Delivery: add real fixtures and an automated case runner, browser repair/diagnose controls and wiring table, README/API semantics, source scope and engineering case document. Rewrite the ignored one-page proposal from implemented facts.
- [x] Verify: format, check all targets, MoonBit tests, build, Node tests, examples, case runner, generated interface review, privacy and diff checks. Public delivery follows local verification: commit coherent changes, push the existing public default branch under prior upload authorization, and inspect remote CI.
