///|
priv struct Search {
  mut nodes : Int
  mut exhausted : Bool
  mut last_conflicts : Array[Finding]
  max_nodes : Int
}

///|
fn search_assignments(
  choices : Array[Array[Assignment]],
  index : Int,
  stack : Array[Assignment],
  state : Search,
) -> Array[Assignment]? {
  if index == choices.length() {
    return Some(stack.map(fn(a) { a }))
  }
  for candidate in choices[index] {
    if state.nodes >= state.max_nodes {
      state.exhausted = true
      return None
    }
    state.nodes = state.nodes + 1
    let conflicts : Array[Finding] = []
    for existing in stack {
      for item in pair_conflicts(existing, candidate) {
        conflicts.push(item)
      }
    }
    if conflicts.length() != 0 {
      state.last_conflicts = conflicts
      continue
    }
    stack.push(candidate)
    let result = search_assignments(choices, index + 1, stack, state)
    ignore(stack.pop())
    match result {
      Some(_) => return result
      None => if state.exhausted { return None }
    }
  }
  None
}

///|
/// Find a deterministic feasible plan while counting each attempted candidate.
/// The budget counts candidate attempts, not wall-clock time. At most 200000.
pub fn plan(devices : Array[Device], max_nodes? : Int = 50000) -> Report {
  let invalid = validate_devices(devices)
  if max_nodes < 0 || max_nodes > 200000 {
    invalid.push(
      finding(
        "INVALID_BUDGET",
        "max_nodes must be an integer in 0..200000.",
        [],
        "max_nodes",
      ),
    )
  }
  if invalid.length() != 0 {
    return { status: Invalid, assignments: [], findings: invalid, nodes: 0, }
  }
  let choices : Array[Array[Assignment]] = []
  for d in devices {
    let cs = candidates(d)
    if cs.length() == 0 {
      return {
        status: Unsatisfiable,
        assignments: [],
        findings: [
          finding(
            "NO_CANDIDATES",
            "No valid signal mapping satisfies the device's pin and instance locks.",
            [d.id],
            d.kind.name(),
          ),
        ],
        nodes: 0,
      }
    }
    choices.push(cs)
  }
  let state : Search = {
    nodes: 0,
    exhausted: false,
    last_conflicts: [],
    max_nodes,
  }
  match search_assignments(choices, 0, [], state) {
    Some(assignments) => {
      // Validate the finished result through the independently callable checker.
      let findings = check_assignments(assignments)
      if findings.length() != 0 {
        { status: Invalid, assignments: [], findings, nodes: state.nodes, }
      } else {
        { status: Solved, assignments, findings: [], nodes: state.nodes, }
      }
    }
    None =>
      if state.exhausted {
        {
          status: Limit,
          assignments: [],
          findings: [
            finding(
              "SEARCH_LIMIT",
              "Candidate-attempt budget reached; infeasibility has not been proven.",
              [],
              "max_nodes",
            ),
          ],
          nodes: state.nodes,
        }
      } else {
        let findings = [
          finding(
            "NO_SOLUTION",
            "All candidate combinations were exhausted. Following conflicts illustrate a rejected branch; they are not a minimal unsatisfiable core.",
            [],
            "resources",
          ),
        ]
        for item in state.last_conflicts {
          findings.push(item)
        }
        {
          status: Unsatisfiable,
          assignments: [],
          findings,
          nodes: state.nodes,
        }
      }
  }
}
