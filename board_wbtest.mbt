///|
test "Pico exposed GPIOs exclude internal pins and GPIO29" {
  assert_true(is_available(0))
  assert_true(is_available(22))
  assert_true(is_available(26))
  assert_true(is_available(28))
  for pin in [-1, 23, 24, 25, 29, 30] {
    assert_false(is_available(pin))
  }
}

///|
test "UART alternative signals must use the correct instance" {
  assert_true(supports(Uart, 0, "TX", 0))
  assert_true(supports(Uart, 0, "RX", 13))
  assert_true(supports(Uart, 1, "TX", 4))
  assert_false(supports(Uart, 0, "TX", 4))
  assert_false(supports(Uart, 0, "RX", 29))
  assert_false(supports(Uart, 2, "TX", 0))
}

///|
test "SPI and I2C mappings match RP2040 alternate functions" {
  assert_true(supports(Spi, 0, "SCK", 18))
  assert_true(supports(Spi, 1, "TX", 27))
  assert_true(supports(Spi, 1, "RX", 28))
  assert_false(supports(Spi, 0, "TX", 27))
  assert_true(supports(I2c, 1, "SDA", 2))
  assert_true(supports(I2c, 0, "SCL", 21))
  assert_false(supports(I2c, 0, "SDA", 2))
  assert_false(supports(Spi, 0, "CS", 25))
}

///|
test "PWM GPIO aliases address the same slice and channel" {
  assert_eq(pwm_slice(0), 0)
  assert_eq(pwm_slice(16), 0)
  assert_eq(pwm_channel(0), 0)
  assert_eq(pwm_channel(16), 0)
  assert_eq(pwm_slice(28), 6)
  assert_eq(pwm_channel(1), 1)
}
