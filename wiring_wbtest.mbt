///|
test "wiring export maps physical header endpoints and PWM aliases" {
  for (gpio, header) in [(0, 1), (1, 2), (22, 29), (26, 31), (27, 32), (28, 34)] {
    let report = plan([device("load", Pwm, pins={ "OUT": gpio })])
    let rows = wiring_rows(report.assignments)
    assert_eq(rows.length(), 1)
    assert_eq(rows[0].gpio, gpio)
    assert_eq(rows[0].header_pin, header)
  }
  assert_eq(pico_header_pin(23), None)
  assert_eq(pico_header_pin(29), None)
  let pwm = wiring_rows(
    plan([device("motor", Pwm, pins={ "OUT": 16 })]).assignments,
  )
  assert_eq(pwm[0].resource, "PWM0/A")
}

///|
test "wiring export preserves shared-bus membership but refuses conflicting plans" {
  let ds = [
    device("temp", I2c, pins={ "SDA": 4, "SCL": 5 }, bus=Some("sensors")),
    device("humidity", I2c, pins={ "SDA": 4, "SCL": 5 }, bus=Some("sensors")),
  ]
  let rows = wiring_rows(check(ds).assignments)
  assert_eq(rows.length(), 4)
  assert_eq(rows[0].header_pin, 6)
  assert_eq(rows[1].header_pin, 7)
  assert_eq(rows[0].bus, Some("sensors"))
  let bad = check([
    device("a", Pwm, pins={ "OUT": 0 }),
    device("b", Pwm, pins={ "OUT": 16 }),
  ])
  assert_eq(wiring_rows(bad.assignments).length(), 0)
}
