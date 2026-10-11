///|
test "candidate generation applies signal and instance locks" {
  let d = device("console", Uart, pins={ "TX": 0 }, instance=Some(0))
  let cs = candidates(d)
  assert_eq(cs.length(), 3)
  for c in cs {
    assert_eq(c.pins.get("TX"), Some(0))
    assert_eq(c.instance, 0)
  }
  assert_eq(cs[0].pins.get("RX"), Some(1))
  assert_eq(cs[2].pins.get("RX"), Some(17))
}

///|
test "a valid-looking but unmappable lock yields no candidates" {
  assert_eq(candidates(device("bad", Uart, pins={ "TX": 2 })).length(), 0)
  assert_eq(
    candidates(device("bad", I2c, pins={ "SDA": 0, "SCL": 3 })).length(),
    0,
  )
}

///|
test "PWM candidates retain the real slice and original locks are not mutated" {
  let pins : Map[String, Int] = { "OUT": 16 }
  let cs = candidates(device("pwm", Pwm, pins~))
  assert_eq(cs.length(), 1)
  assert_eq(cs[0].instance, 0)
  assert_eq(pins.get("OUT"), Some(16))
  assert_eq(candidates(device("pwm", Pwm, pins~, instance=Some(1))).length(), 0)
}

///|
test "SPI alternatives may use different banks of one peripheral instance" {
  let cs = candidates(
    device("mixed", Spi, pins={ "RX": 0, "CS": 5, "SCK": 18, "TX": 19 }),
  )
  assert_eq(cs.length(), 1)
  assert_eq(cs[0].instance, 0)
  assert_eq(check_assignments(cs).length(), 0)
}
