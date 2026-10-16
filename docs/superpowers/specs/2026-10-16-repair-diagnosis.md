# PinPlan repair and diagnosis design

The October preliminary review requests independent engineering scope and reproducible cases. The existing module imports only MoonBit core; there is no moonplan dependency. This is a repository fact, not a claim about the reviewers' evidence or a whole-ecosystem originality guarantee.

## User workflow

1. Check an existing wiring configuration.
2. Repair it while preserving explicit hard locks. A separate `baseline` describes existing wiring as soft preferences. Minimize the number of changed device/signal GPIO assignments. Added devices have zero cost; peripheral instances and frequency changes are not costed.
3. Diagnose infeasibility with a deletion-based, device-level irreducible conflict set. This is inclusion-minimal, not minimum-cardinality, and is certified only if every deletion test completes.
4. Export solved assignments as wiring rows with physical Pico header numbers, shared-bus labels and PWM slice/channel information.

## Interfaces and correctness

- Keep `plan`, `check`, `Report` and schema version 1 compatible; add `repair` and `diagnose` modes and additive response fields.
- `repair(devices, baseline, max_nodes=50000)` returns a report, per-signal changes, optional change count and an optimality flag. Baseline must contain complete, individually valid devices matching target IDs/kinds; inter-device baseline conflicts are allowed. Target `pins` remain hard locks.
- Branch-and-bound searches cost-ordered hardware candidates with an admissible suffix lower bound. Each attempted candidate consumes one node. An incumbent after budget exhaustion is `solved` with `optimal=false`; without an incumbent the result is `limit`. Only exhaustion or reaching the lower bound proves optimality.
- `diagnose(devices, max_nodes=50000)` shares a single candidate-attempt budget between the initial proof and all deletion tests. A proven unsatisfiable set remains valid after reduction times out, but `irreducible=false`. Initial timeout never becomes an unsatisfiability claim.
- `wiring` is emitted only for fully verified solved assignments; header numbers follow the original Pico datasheet. No voltage, ground, power or firmware configuration is inferred.
- No new runtime dependencies. All new algorithms, diagnostics, change accounting and wiring projection are MoonBit code. Node and browser remain adapters.

## Evidence

Hand-derived repair scenarios, locked-unsatisfiable and budget cases, unrelated-device deletion, three-device resource exhaustion, malformed baseline, and physical header endpoints. Cross-check tiny repair cases against independently enumerated GPIO choices. Run existing regression tests and all-target checks. Keep proposal and personal details local.
