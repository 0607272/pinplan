///|
test "repair preserves valid wiring instead of choosing the first legal pins" {
  let devices = [device("console", Uart)]
  let baseline = [device("console", Uart, pins={ "TX": 16, "RX": 17 })]
  let result = repair(devices, baseline)
  assert_eq(result.report.status, Solved)
  assert_eq(result.changed_pins, Some(0))
  assert_true(result.optimal)
  assert_eq(result.report.assignments[0].pins.get("TX"), Some(16))
  assert_eq(result.changes.length(), 0)
}

///|
test "repair fixes PWM aliases with one change and honors the motor hard lock" {
  let devices = [device("motor", Pwm, pins={ "OUT": 0 }), device("led", Pwm)]
  let baseline = [
    device("motor", Pwm, pins={ "OUT": 0 }),
    device("led", Pwm, pins={ "OUT": 16 }),
  ]
  let result = repair(devices, baseline)
  assert_eq(result.report.status, Solved)
  assert_eq(result.changed_pins, Some(1))
  assert_true(result.optimal)
  assert_eq(result.report.assignments[0].pins.get("OUT"), Some(0))
  assert_eq(result.report.assignments[1].pins.get("OUT"), Some(1))
  assert_eq(result.changes.length(), 1)
  assert_eq(result.changes[0].device, "led")
  assert_eq(result.changes[0].signal, "OUT")
  assert_eq(result.changes[0].from_gpio, 16)
  assert_eq(result.changes[0].to_gpio, 1)
  assert_eq(check_assignments(result.report.assignments).length(), 0)
}

///|
test "repair budget retains a verified incumbent without claiming optimality" {
  let ds = [device("a", Pwm), device("b", Pwm), device("c", Pwm)]
  let baseline = [
    device("a", Pwm, pins={ "OUT": 0 }),
    device("b", Pwm, pins={ "OUT": 0 }),
    device("c", Pwm, pins={ "OUT": 0 }),
  ]
  let no_result = repair(ds, baseline, max_nodes=0)
  assert_eq(no_result.report.status, Limit)
  assert_eq(no_result.changed_pins, None)
  assert_false(no_result.optimal)
  let partial = repair(ds, baseline, max_nodes=8)
  assert_eq(partial.report.status, Solved)
  assert_eq(partial.report.nodes, 8)
  assert_eq(partial.changed_pins, Some(2))
  assert_false(partial.optimal)
  assert_true(has_code(partial.report.findings, "REPAIR_LIMIT"))
  assert_eq(check_assignments(partial.report.assignments).length(), 0)
}

///|
test "repair never relaxes hard locks and validates baseline identities and mapping" {
  let ds = [
    device("a", Pwm, pins={ "OUT": 0 }),
    device("b", Pwm, pins={ "OUT": 16 }),
  ]
  assert_eq(repair(ds, []).report.status, Unsatisfiable)
  for
    baseline in [
      [device("unknown", Pwm, pins={ "OUT": 2 })],
      [device("a", Uart, pins={ "TX": 0, "RX": 1 })],
      [device("a", Pwm)],
      [device("a", Pwm, pins={ "OUT": 23 })],
      [device("a", Pwm, pins={ "OUT": 0 }), device("a", Pwm, pins={ "OUT": 2 })],
    ] {
    let result = repair(ds, baseline)
    assert_eq(result.report.status, Invalid)
    assert_eq(result.report.nodes, 0)
    assert_eq(result.changed_pins, None)
  }
}

///|
test "repair optimum matches an independent two-PWM exhaustive oracle" {
  // On GPIO0..3 only, slices [0,0,1,1], channels [A,B,A,B].
  // Lock one OUT at each possible pin; enumerate the other physically valid OUT.
  for fixed in [0, 1, 2, 3] {
    for old in [0, 1, 2, 3] {
      for freq in [50, 1000] {
        let mut oracle = 2
        for pin in [0, 1, 2, 3] {
          if pin != fixed && (pin / 2 != fixed / 2 || freq == 1000) {
            let cost = if pin == old { 0 } else { 1 }
            if cost < oracle {
              oracle = cost
            }
          }
        }
        let result = repair(
          [
            device("fixed", Pwm, pins={ "OUT": fixed }),
            device("moving", Pwm, frequency_hz=freq),
          ],
          [device("moving", Pwm, pins={ "OUT": old }, frequency_hz=freq)],
        )
        assert_eq(result.report.status, Solved)
        assert_eq(result.changed_pins, Some(oracle))
        assert_true(result.optimal)
      }
    }
  }
}

///|
test "new devices cost zero and an empty repair is proven optimal at zero budget" {
  let result = repair([device("new", Pwm)], [])
  assert_eq(result.changed_pins, Some(0))
  assert_true(result.optimal)
  let empty = repair([], [], max_nodes=0)
  assert_eq(empty.report.status, Solved)
  assert_eq(empty.changed_pins, Some(0))
  assert_true(empty.optimal)
  assert_eq(repair([], [], max_nodes=-1).report.status, Invalid)
}

///|
test "repair improves a greedy incumbent by moving the earlier PWM device" {
  // Keeping indicator on slice0 forces BOTH 50Hz endpoints to move.
  // Move indicator to GPIO2 instead: both servos remain on GPIO1/0 at 50Hz.
  let baseline = [
    device("indicator", Pwm, pins={ "OUT": 0 }, frequency_hz=1000),
    device("servo_a", Pwm, pins={ "OUT": 1 }, frequency_hz=50),
    device("servo_b", Pwm, pins={ "OUT": 0 }, frequency_hz=50),
  ]
  let result = repair(
    [
      device("indicator", Pwm, frequency_hz=1000),
      device("servo_a", Pwm, frequency_hz=50),
      device("servo_b", Pwm, frequency_hz=50),
    ],
    baseline,
  )
  assert_eq(result.changed_pins, Some(1))
  assert_true(result.optimal)
  assert_eq(result.changes[0].device, "indicator")
  assert_eq(result.report.assignments[1].pins.get("OUT"), Some(1))
  assert_eq(result.report.assignments[2].pins.get("OUT"), Some(0))
}

///|
test "shared bus repair counts device signal endpoints rather than shared wires" {
  let baseline = [
    device("a", I2c, pins={ "SDA": 0, "SCL": 1 }, bus=Some("sensors")),
    device("b", I2c, pins={ "SDA": 0, "SCL": 1 }, bus=Some("sensors")),
  ]
  let result = repair(
    [
      device("a", I2c, pins={ "SDA": 4, "SCL": 5 }, bus=Some("sensors")),
      device("b", I2c, bus=Some("sensors")),
    ],
    baseline,
  )
  assert_eq(result.changed_pins, Some(4))
  assert_true(result.optimal)
  assert_eq(result.changes.length(), 4)
}
