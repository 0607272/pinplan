///|
test "diagnosis removes unrelated devices and certifies each remaining member" {
  let ds = [
    device("motor", Pwm, pins={ "OUT": 0 }),
    device("sensor", I2c, pins={ "SDA": 4, "SCL": 5 }),
    device("led", Pwm, pins={ "OUT": 16 }),
  ]
  let result = diagnose(ds)
  assert_eq(result.report.status, Unsatisfiable)
  assert_eq(result.core_devices, ["motor", "led"])
  assert_true(result.irreducible)
  assert_eq(plan([ds[0]]).status, Solved)
  assert_eq(plan([ds[2]]).status, Solved)
}

///|
test "three UARTs exhaust two controllers without a pairwise-only explanation" {
  let ds = [device("a", Uart), device("b", Uart), device("c", Uart)]
  let result = diagnose(ds)
  assert_eq(result.report.status, Unsatisfiable)
  assert_eq(result.core_devices, ["a", "b", "c"])
  assert_true(result.irreducible)
  for drop = 0; drop < 3; drop = drop + 1 {
    let subset : Array[Device] = []
    for i = 0; i < 3; i = i + 1 {
      if i != drop {
        subset.push(ds[i])
      }
    }
    assert_eq(plan(subset).status, Solved)
  }
}

///|
test "diagnosis timeout distinguishes a proven core from unproven irreducibility" {
  let ds = [
    device("a", Pwm, pins={ "OUT": 0 }),
    device("b", Pwm, pins={ "OUT": 16 }),
  ]
  let limited = diagnose(ds, max_nodes=2)
  assert_eq(limited.report.status, Unsatisfiable)
  assert_eq(limited.core_devices, ["a", "b"])
  assert_false(limited.irreducible)
  assert_eq(limited.report.nodes, 2)
  assert_true(has_code(limited.report.findings, "DIAGNOSIS_LIMIT"))
  let unknown = diagnose(ds, max_nodes=0)
  assert_eq(unknown.report.status, Limit)
  assert_eq(unknown.core_devices.length(), 0)
  assert_false(unknown.irreducible)
}

///|
test "diagnosis handles singleton mapping failure and rejects invalid input" {
  let result = diagnose([device("bad", I2c, pins={ "SDA": 0, "SCL": 3 })])
  assert_eq(result.core_devices, ["bad"])
  assert_true(result.irreducible)
  assert_eq(
    diagnose([device("x", Pwm, pins={ "OUT": 23 })]).report.status,
    Invalid,
  )
  assert_eq(diagnose([]).report.status, Solved)
  assert_false(diagnose([]).irreducible)
}
