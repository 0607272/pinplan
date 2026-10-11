///|
/// Whether a GPIO is brought out on the original Raspberry Pi Pico headers.
pub fn is_available(gpio : Int) -> Bool {
  (gpio >= 0 && gpio <= 22) || (gpio >= 26 && gpio <= 28)
}

///|
/// The Pico's exposed GPIO numbers in deterministic ascending order.
pub fn available_pins() -> Array[Int] {
  [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 26, 27, 28,
  ]
}

///|
/// RP2040 PWM slice (caller must separately validate that the GPIO is exposed).
pub fn pwm_slice(gpio : Int) -> Int {
  gpio / 2 % 8
}

///|
/// RP2040 PWM channel: 0 is A, 1 is B.
pub fn pwm_channel(gpio : Int) -> Int {
  gpio % 2
}

///|
/// Check a signal against RP2040 function-select mappings and Pico availability.
pub fn supports(
  kind : Kind,
  instance : Int,
  signal : String,
  gpio : Int,
) -> Bool {
  if !is_available(gpio) {
    return false
  }
  match kind {
    Uart => {
      let candidates = match (instance, signal) {
        (0, "TX") => [0, 12, 16, 28]
        (0, "RX") => [1, 13, 17, 29]
        (1, "TX") => [4, 8, 20, 24]
        (1, "RX") => [5, 9, 21, 25]
        _ => []
      }
      candidates.contains(gpio)
    }
    Spi => {
      let candidates = match (instance, signal) {
        (0, "RX") => [0, 4, 16, 20]
        (0, "CS") => [1, 5, 17, 21]
        (0, "SCK") => [2, 6, 18, 22]
        (0, "TX") => [3, 7, 19, 23]
        (1, "RX") => [8, 12, 24, 28]
        (1, "CS") => [9, 13, 25, 29]
        (1, "SCK") => [10, 14, 26]
        (1, "TX") => [11, 15, 27]
        _ => []
      }
      candidates.contains(gpio)
    }
    I2c =>
      match (instance, signal) {
        (0, "SDA") => gpio % 4 == 0
        (0, "SCL") => gpio % 4 == 1
        (1, "SDA") => gpio % 4 == 2
        (1, "SCL") => gpio % 4 == 3
        _ => false
      }
    Pwm => signal == "OUT" && instance == pwm_slice(gpio)
  }
}
