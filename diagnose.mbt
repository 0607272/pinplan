///|
/// A proven unsatisfiable device subset, optionally certified irreducible.
pub(all) struct DiagnosisReport {
  report : Report
  core_devices : Array[String]
  irreducible : Bool
} derive(Debug, Eq)

///|
pub extend DiagnosisReport with Eq::{equal, not_equal}

///|
pub extend DiagnosisReport with @debug.Debug::{to_repr}

///|
/// Reduce an unsatisfiable request by removing unnecessary whole devices.
/// One candidate-attempt budget covers the initial proof and all deletion tests.
/// Irreducible means removing any one remaining device makes it satisfiable;
/// it does not mean globally smallest cardinality or minimum pin-lock subset.
pub fn diagnose(
  devices : Array[Device],
  reserved_pins? : Array[Int] = [],
  max_nodes? : Int = 50000,
) -> DiagnosisReport {
  let initial = plan(devices, reserved_pins~, max_nodes~)
  if initial.status != Unsatisfiable {
    return { report: initial, core_devices: [], irreducible: false, }
  }
  let mut nodes = initial.nodes
  let mut core = devices.map(fn(d) { d })
  let mut index = 0
  let mut complete = true
  while index < core.length() {
    let subset : Array[Device] = []
    for i = 0; i < core.length(); i = i + 1 {
      if i != index {
        subset.push(core[i])
      }
    }
    let probe = plan(subset, reserved_pins~, max_nodes=max_nodes - nodes)
    nodes = nodes + probe.nodes
    match probe.status {
      Unsatisfiable => core = subset
      Solved => index = index + 1
      // Subsets of validated devices remain valid. Conservatively refuse a
      // minimality certificate for any result other than a completed proof.
      Limit | Invalid => {
        complete = false
        break
      }
    }
  }
  let ids = core.map(fn(d) { d.id })
  let findings = [
    finding(
      "UNSAT_CORE",
      if complete {
        "This device set is unsatisfiable; removing any single member makes it feasible."
      } else {
        "This device set is proven unsatisfiable; irreducibility has not been proven."
      },
      ids,
      "devices",
    ),
  ]
  if !complete {
    findings.push(
      finding(
        "DIAGNOSIS_LIMIT",
        "Shared diagnosis budget exhausted before all deletion tests completed.",
        [],
        "max_nodes",
      ),
    )
  }
  {
    report: { status: Unsatisfiable, assignments: [], findings, nodes, },
    core_devices: ids,
    irreducible: complete,
  }
}
