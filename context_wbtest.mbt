///|
test "reserved GPIOs constrain plans, checks, repairs and diagnosis" {
  let d = device("led", Pwm, pins={ "OUT": 0 })
  assert_eq(plan([d], reserved_pins=[0]).status, Unsatisfiable)
  assert_eq(check([d], reserved_pins=[0]).status, Invalid)
  let r = repair([device("led", Pwm)], [d], reserved_pins=[0])
  assert_eq(r.report.status, Solved)
  assert_eq(r.changed_pins, Some(1))
  assert_eq(r.report.assignments[0].pins.get("OUT"), Some(1))
  let core = diagnose([d, device("other", Pwm)], reserved_pins=[0])
  assert_eq(core.core_devices, ["led"])
  assert_true(core.irreducible)
  assert_eq(plan([], reserved_pins=[23]).status, Invalid)
  assert_eq(plan([], reserved_pins=[0, 0]).status, Invalid)
  let all_reserved = plan([device("a", Pwm)], reserved_pins=available_pins())
  assert_eq(all_reserved.status, Unsatisfiable)
}

///|
test "shared I2C addresses are hardware constraints" {
  let a = device(
    "a",
    I2c,
    pins={ "SDA": 4, "SCL": 5 },
    bus=Some("sensors"),
    i2c_address=Some(64),
  )
  let b = device(
    "b",
    I2c,
    pins={ "SDA": 4, "SCL": 5 },
    bus=Some("sensors"),
    i2c_address=Some(64),
  )
  assert_eq(plan([a, b]).status, Unsatisfiable)
  assert_true(has_code(check([a, b]).findings, "I2C_ADDRESS_CONFLICT"))
  assert_eq(
    plan([a, device("b", I2c, bus=Some("sensors"), i2c_address=Some(65))]).status,
    Solved,
  )
  assert_eq(plan([a, device("b", I2c, bus=Some("sensors"))]).status, Solved)
  assert_eq(
    plan([
      device("a", I2c, instance=Some(0), i2c_address=Some(64)),
      device("b", I2c, instance=Some(1), i2c_address=Some(64)),
    ]).status,
    Solved,
  )
  for address in [7, 120] {
    assert_eq(
      plan([device("bad", I2c, i2c_address=Some(address))]).status,
      Invalid,
    )
  }
  for address in [8, 119] {
    assert_eq(
      plan([device("edge", I2c, i2c_address=Some(address))]).status,
      Solved,
    )
  }
  assert_eq(plan([device("bad", Pwm, i2c_address=Some(64))]).status, Invalid)
}

///|
test "exports reject invalid context and preserve a valid empty plan" {
  let a = check([device("led", Pwm, pins={ "OUT": 0 })]).assignments
  assert_eq(export_wiring_csv(a, reserved_pins=[0]), None)
  assert_eq(export_pico_header(a, reserved_pins=[0]), None)
  assert_true(export_wiring_csv([]) is Some(_))
  assert_true(export_pico_header([]) is Some(_))
}

///|
test "CSV quoted Unicode names survive across compiler targets" {
  assert_eq(
    csv_cell("=传感器,\"😀\"\r\n", user_value=true),
    "\"'=传感器,\"\"😀\"\"\r\n\"",
  )
  let a = check([device("led", Pwm, pins={ "OUT": 2 })]).assignments
  assert_eq(
    export_wiring_csv(a, repair_optimal=Some(false)),
    Some(
      "device_index,device,signal,gpio,header_pin,resource,bus,i2c_address,reserved_pins,repair_optimal\r\n0,\"'led\",\"OUT\",2,4,\"PWM1/A\",\"\",,\"\",false\r\n",
    ),
  )
}
