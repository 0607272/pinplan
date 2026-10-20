///|
fn has_code(findings : Array[Finding], code : String) -> Bool {
  findings.any(fn(f) { f.code == code })
}

///|
fn assigned(d : Device, instance : Int) -> Assignment {
  {
    id: d.id,
    kind: d.kind,
    pins: d.pins,
    instance,
    bus: d.bus,
    frequency_hz: d.frequency_hz,
    i2c_address: d.i2c_address,
  }
}

///|
test "invalid pin locks and duplicate IDs are rejected before searching" {
  let bad = [device("a", Uart, pins={ "TX": 23, "FAKE": 1 }), device("a", Uart)]
  let findings = validate_devices(bad)
  assert_true(has_code(findings, "PIN_UNAVAILABLE"))
  assert_true(has_code(findings, "UNKNOWN_SIGNAL"))
  assert_true(has_code(findings, "DUPLICATE_ID"))
}

///|
test "wrong alternate function is a mapping conflict" {
  let d = device("uart", Uart, pins={ "TX": 4, "RX": 5 })
  assert_true(has_code(check_assignments([assigned(d, 0)]), "SIGNAL_MAPPING"))
}

///|
test "shared I2C requires identical explicit bus routing" {
  let a = device("sensor", I2c, pins={ "SDA": 0, "SCL": 1 }, bus=Some("bus"))
  let b = device("screen", I2c, pins={ "SDA": 0, "SCL": 1 }, bus=Some("bus"))
  assert_eq(check_assignments([assigned(a, 0), assigned(b, 0)]).length(), 0)
  let independent = device("screen", I2c, pins={ "SDA": 0, "SCL": 1 })
  assert_true(
    has_code(
      check_assignments([assigned(a, 0), assigned(independent, 0)]),
      "PIN_CONFLICT",
    ),
  )
  let elsewhere = device(
    "screen",
    I2c,
    pins={ "SDA": 4, "SCL": 5 },
    bus=Some("bus"),
  )
  assert_true(
    has_code(
      check_assignments([assigned(a, 0), assigned(elsewhere, 0)]),
      "BUS_ROUTING",
    ),
  )
}

///|
test "shared SPI chip selects remain exclusive" {
  let a = device(
    "screen",
    Spi,
    pins={ "RX": 0, "CS": 1, "SCK": 2, "TX": 3 },
    bus=Some("display"),
  )
  let b = device(
    "flash",
    Spi,
    pins={ "RX": 0, "CS": 5, "SCK": 2, "TX": 3 },
    bus=Some("display"),
  )
  assert_eq(check_assignments([assigned(a, 0), assigned(b, 0)]).length(), 0)
  let c = device(
    "flash",
    Spi,
    pins={ "RX": 0, "CS": 1, "SCK": 2, "TX": 3 },
    bus=Some("display"),
  )
  assert_true(
    has_code(
      check_assignments([assigned(a, 0), assigned(c, 0)]),
      "PIN_CONFLICT",
    ),
  )
}

///|
test "PWM alias and slice frequency constraints are physical resources" {
  let a = device("motor", Pwm, pins={ "OUT": 0 }, frequency_hz=1000)
  let pwm_alias = device("led", Pwm, pins={ "OUT": 16 }, frequency_hz=1000)
  assert_true(
    has_code(
      check_assignments([assigned(a, 0), assigned(pwm_alias, 0)]),
      "PWM_CHANNEL",
    ),
  )
  let b = device("servo", Pwm, pins={ "OUT": 1 }, frequency_hz=50)
  assert_true(
    has_code(
      check_assignments([assigned(a, 0), assigned(b, 0)]),
      "PWM_FREQUENCY",
    ),
  )
  let same = device("led", Pwm, pins={ "OUT": 1 }, frequency_hz=1000)
  assert_eq(check_assignments([assigned(a, 0), assigned(same, 0)]).length(), 0)
}

///|
test "a peripheral instance cannot drive independent signal routings" {
  let a = device("a", Uart, pins={ "TX": 0, "RX": 1 })
  let b = device("b", Uart, pins={ "TX": 12, "RX": 13 })
  assert_true(
    has_code(
      check_assignments([assigned(a, 0), assigned(b, 0)]),
      "INSTANCE_CONFLICT",
    ),
  )
}

///|
test "check reports incomplete assignments and invalid shared bus kinds" {
  assert_true(
    has_code(
      check_assignments([assigned(device("a", Uart), 0)]),
      "MISSING_SIGNAL",
    ),
  )
  assert_true(
    has_code(
      validate_devices([device("a", Uart, bus=Some("serial"))]),
      "BUS_KIND",
    ),
  )
  let a = device("a", I2c, pins={ "SDA": 0, "SCL": 1 }, bus=Some("x"))
  let b = device(
    "b",
    Spi,
    pins={ "RX": 8, "CS": 9, "SCK": 10, "TX": 11 },
    bus=Some("x"),
  )
  assert_true(
    has_code(check_assignments([assigned(a, 0), assigned(b, 1)]), "BUS_KIND"),
  )
}

///|
test "bus frequency mismatch rejects identical wires" {
  let a = device(
    "a",
    I2c,
    pins={ "SDA": 0, "SCL": 1 },
    bus=Some("x"),
    frequency_hz=100000,
  )
  let b = device(
    "b",
    I2c,
    pins={ "SDA": 0, "SCL": 1 },
    bus=Some("x"),
    frequency_hz=400000,
  )
  assert_true(
    has_code(
      check_assignments([assigned(a, 0), assigned(b, 0)]),
      "BUS_FREQUENCY",
    ),
  )
}
