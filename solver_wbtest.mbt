///|
test "planning a mixed setup preserves fixed wiring and verifies the result" {
  let devices = [
    device("console", Uart, pins={ "TX": 0, "RX": 1 }),
    device("sensor", I2c, pins={ "SDA": 4, "SCL": 5 }),
    device("display", Spi),
    device("motor", Pwm, pins={ "OUT": 2 }),
  ]
  let result = plan(devices)
  assert_eq(result.status, Solved)
  assert_eq(result.assignments.length(), 4)
  assert_eq(result.assignments[0].pins.get("TX"), Some(0))
  assert_eq(result.assignments[1].pins.get("SDA"), Some(4))
  assert_eq(check_assignments(result.assignments).length(), 0)
  assert_eq(plan(devices), result)
}

///|
test "a fixed PWM alias conflict is proven unsatisfiable" {
  let result = plan([
    device("a", Pwm, pins={ "OUT": 0 }),
    device("b", Pwm, pins={ "OUT": 16 }),
  ])
  assert_eq(result.status, Unsatisfiable)
  assert_true(has_code(result.findings, "PWM_CHANNEL"))
  assert_eq(result.assignments.length(), 0)
}

///|
test "zero budget cannot be mistaken for no solution" {
  assert_eq(plan([device("a", Uart)], max_nodes=0).status, Limit)
  assert_eq(plan([], max_nodes=0).status, Solved)
  assert_eq(plan([device("a", Uart)], max_nodes=-1).status, Invalid)
}

///|
test "budget exhaustion is distinguished from a fully explored dead end" {
  let devices = [
    device("a", Uart, instance=Some(0)),
    device("b", Uart, instance=Some(0)),
  ]
  let result = plan(devices, max_nodes=1)
  assert_eq(result.status, Limit)
  assert_eq(result.nodes, 1)
  assert_eq(plan(devices, max_nodes=1000).status, Unsatisfiable)
}

///|
test "explicit shared buses are assigned consistently by search" {
  let devices = [
    device("a", I2c, bus=Some("sensors")),
    device("b", I2c, bus=Some("sensors")),
  ]
  let result = plan(devices)
  assert_eq(result.status, Solved)
  assert_eq(result.assignments[0].pins, result.assignments[1].pins)
  assert_eq(result.assignments[0].instance, result.assignments[1].instance)
}

///|
test "incompatible alternate-function locks have an explicit no-candidate finding" {
  let result = plan([device("bad", I2c, pins={ "SDA": 0, "SCL": 3 })])
  assert_eq(result.status, Unsatisfiable)
  assert_true(has_code(result.findings, "NO_CANDIDATES"))
}

///|
test "small PWM feasibility agrees with hand-derived exhaustive cases" {
  // Independent physical resource labels for this fixture, not production helpers.
  let pins = [0, 1, 2, 3, 16, 17]
  let slices = [0, 0, 1, 1, 0, 0]
  let channels = [0, 1, 0, 1, 0, 1]
  for i = 0; i < pins.length(); i = i + 1 {
    for j = 0; j < pins.length(); j = j + 1 {
      for frequency in [50, 1000] {
        let expected = if slices[i] == slices[j] &&
          (channels[i] == channels[j] || frequency != 1000) {
          Unsatisfiable
        } else {
          Solved
        }
        let result = plan([
          device("a", Pwm, pins={ "OUT": pins[i] }, frequency_hz=1000),
          device("b", Pwm, pins={ "OUT": pins[j] }, frequency_hz=frequency),
        ])
        assert_eq(result.status, expected)
      }
    }
  }
}

///|
test "invalid input is rejected before consuming search budget" {
  let result = plan([device("a", Pwm, pins={ "OUT": 23 })])
  assert_eq(result.status, Invalid)
  assert_eq(result.nodes, 0)
}
