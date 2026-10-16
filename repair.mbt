///|
/// One changed signal, measured per device endpoint rather than physical wire.
pub(all) struct PinChange {
  device : String
  signal : String
  from_gpio : Int
  to_gpio : Int
} derive(Debug, Eq)

///|
pub extend PinChange with Eq::{equal, not_equal}

///|
pub extend PinChange with @debug.Debug::{to_repr}

///|
/// A feasible incumbent may be returned even when optimality was not proven.
pub(all) struct RepairReport {
  report : Report
  changes : Array[PinChange]
  changed_pins : Int?
  optimal : Bool
} derive(Debug, Eq)

///|
pub extend RepairReport with Eq::{equal, not_equal}

///|
pub extend RepairReport with @debug.Debug::{to_repr}

///|
priv struct RepairChoice {
  assignment : Assignment
  cost : Int
}

///|
priv struct RepairSearch {
  mut nodes : Int
  mut exhausted : Bool
  mut best : Array[Assignment]?
  mut best_cost : Int
  lower_bound : Int
  max_nodes : Int
}

///|
fn pin_changes(
  assignments : Array[Assignment],
  baseline : Map[String, Device],
) -> Array[PinChange] {
  let changes : Array[PinChange] = []
  for a in assignments {
    match baseline.get(a.id) {
      None => ()
      Some(old) =>
        for signal in signals(a.kind) {
          match (old.pins.get(signal), a.pins.get(signal)) {
            (Some(from_gpio), Some(to_gpio)) if from_gpio != to_gpio =>
              changes.push({ device: a.id, signal, from_gpio, to_gpio, })
            _ => ()
          }
        }
    }
  }
  changes
}

///|
fn repair_cost(a : Assignment, baseline : Map[String, Device]) -> Int {
  let mut cost = 0
  match baseline.get(a.id) {
    None => ()
    Some(old) =>
      for signal in signals(a.kind) {
        if old.pins.get(signal) != a.pins.get(signal) {
          cost = cost + 1
        }
      }
  }
  cost
}

///|
fn search_repairs(
  choices : Array[Array[RepairChoice]],
  suffix : Array[Int],
  index : Int,
  cost : Int,
  stack : Array[Assignment],
  state : RepairSearch,
) -> Unit {
  // Local minima ignore interactions and thus never overestimate future cost.
  if cost + suffix[index] >= state.best_cost {
    return
  }
  if index == choices.length() {
    state.best = Some(stack.map(fn(a) { a }))
    state.best_cost = cost
    return
  }
  for choice in choices[index] {
    if cost + choice.cost + suffix[index + 1] >= state.best_cost {
      continue
    }
    if state.nodes >= state.max_nodes {
      state.exhausted = true
      return
    }
    state.nodes = state.nodes + 1
    let mut compatible = true
    for existing in stack {
      if pair_conflicts(existing, choice.assignment).length() != 0 {
        compatible = false
        break
      }
    }
    if compatible {
      stack.push(choice.assignment)
      search_repairs(
        choices,
        suffix,
        index + 1,
        cost + choice.cost,
        stack,
        state,
      )
      ignore(stack.pop())
      if state.exhausted || state.best_cost == state.lower_bound {
        return
      }
    }
  }
}

///|
fn failed_repair(report : Report) -> RepairReport {
  { report, changes: [], changed_pins: None, optimal: false, }
}

///|
/// Minimize changed device/signal GPIOs relative to complete baseline devices.
/// Target pins/instances are hard locks. Baseline pins are soft preferences;
/// conflicts between baseline devices are allowed, malformed mappings are not.
/// Budget counts candidate attempts, shared by the entire optimization search.
pub fn repair(
  devices : Array[Device],
  baseline : Array[Device],
  max_nodes? : Int = 50000,
) -> RepairReport {
  let invalid = validate_devices(devices)
  if max_nodes < 0 || max_nodes > 200000 {
    invalid.push(
      finding(
        "INVALID_BUDGET",
        "max_nodes must be in 0..200000.",
        [],
        "max_nodes",
      ),
    )
  }
  let by_id : Map[String, Device] = Map([])
  for d in devices {
    by_id[d.id] = d
  }
  let old_by_id : Map[String, Device] = Map([])
  for item in validate_devices(baseline) {
    invalid.push(item)
  }
  for old in baseline {
    match by_id.get(old.id) {
      Some(target) if target.kind == old.kind => ()
      _ =>
        invalid.push(
          finding(
            "BASELINE_DEVICE",
            "Baseline IDs and kinds must match target devices.",
            [old.id],
            "baseline",
          ),
        )
    }
    // Validate individually: a conflicting whole baseline is precisely what
    // repair is intended to accept, not a reason to reject its input.
    if check([old]).status != Solved {
      invalid.push(
        finding(
          "BASELINE_MAPPING",
          "Each baseline device must have complete, individually valid signal mappings.",
          [old.id],
          "baseline",
        ),
      )
    }
    old_by_id[old.id] = old
  }
  if invalid.length() != 0 {
    return failed_repair({
      status: Invalid,
      assignments: [],
      findings: invalid,
      nodes: 0,
    })
  }
  let choices : Array[Array[RepairChoice]] = []
  for d in devices {
    let cs = candidates(d)
    if cs.length() == 0 {
      return failed_repair({
        status: Unsatisfiable,
        assignments: [],
        nodes: 0,
        findings: [
          finding(
            "NO_CANDIDATES",
            "No mapping satisfies the target's hard locks.",
            [d.id],
            d.kind.name(),
          ),
        ],
      })
    }
    // At most four signals per device: stable cost buckets avoid depending on
    // sort stability, preserving reproducible ties across all compiler targets.
    let ranked : Array[RepairChoice] = []
    for cost = 0; cost <= signals(d.kind).length(); cost = cost + 1 {
      for a in cs {
        if repair_cost(a, old_by_id) == cost {
          ranked.push({ assignment: a, cost, })
        }
      }
    }
    choices.push(ranked)
  }
  let suffix : Array[Int] = Array::make(choices.length() + 1, 0)
  for i = choices.length() - 1; i >= 0; i = i - 1 {
    suffix[i] = suffix[i + 1] + choices[i][0].cost
  }
  let state : RepairSearch = {
    nodes: 0,
    exhausted: false,
    best: None,
    best_cost: 65,
    lower_bound: suffix[0],
    max_nodes,
  }
  search_repairs(choices, suffix, 0, 0, [], state)
  match state.best {
    Some(assignments) => {
      let findings = check_assignments(assignments)
      if findings.length() != 0 {
        return failed_repair({
          status: Invalid,
          assignments: [],
          findings,
          nodes: state.nodes,
        })
      }
      if state.exhausted {
        findings.push(
          finding(
            "REPAIR_LIMIT",
            "Feasible repair found; budget reached before optimality could be proven.",
            [],
            "max_nodes",
          ),
        )
      }
      {
        report: { status: Solved, assignments, findings, nodes: state.nodes, },
        changes: pin_changes(assignments, old_by_id),
        changed_pins: Some(state.best_cost),
        optimal: !state.exhausted,
      }
    }
    None =>
      failed_repair({
        status: if state.exhausted {
          Limit
        } else {
          Unsatisfiable
        },
        assignments: [],
        nodes: state.nodes,
        findings: [
          if state.exhausted {
            finding(
              "SEARCH_LIMIT",
              "No feasible repair found within the budget; infeasibility is unproven.",
              [],
              "max_nodes",
            )
          } else {
            finding(
              "NO_SOLUTION",
              "All repairs satisfying the hard locks were exhausted.",
              [],
              "resources",
            )
          },
        ],
      })
  }
}
