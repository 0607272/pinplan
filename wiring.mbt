///|
/// A device signal projected onto an original Pico physical header contact.
pub(all) struct WiringRow {
  device : String
  signal : String
  gpio : Int
  header_pin : Int
  resource : String
  bus : String?
} derive(Debug, Eq)

///|
pub extend WiringRow with Eq::{equal, not_equal}

///|
pub extend WiringRow with @debug.Debug::{to_repr}

///|
/// Physical header contact number, from the original Pico datasheet pinout.
pub fn pico_header_pin(gpio : Int) -> Int? {
  let gpios = available_pins()
  let contacts = [
    1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 17, 19, 20, 21, 22, 24, 25, 26,
    27, 29, 31, 32, 34,
  ]
  for i = 0; i < gpios.length(); i = i + 1 {
    if gpios[i] == gpio {
      return Some(contacts[i])
    }
  }
  None
}

///|
/// Return deterministic wiring rows only for a fully verified assignment set.
/// Rows describe signal endpoints, not power, ground, voltage or live hardware.
pub fn wiring_rows(
  assignments : Array[Assignment],
  reserved_pins? : Array[Int] = [],
) -> Array[WiringRow] {
  if check_assignments(assignments, reserved_pins~).length() != 0 {
    return []
  }
  let rows : Array[WiringRow] = []
  for a in assignments {
    for signal in signals(a.kind) {
      match a.pins.get(signal) {
        Some(gpio) =>
          match pico_header_pin(gpio) {
            Some(header_pin) => {
              let resource = if a.kind == Pwm {
                "PWM\{a.instance}/\{if pwm_channel(gpio) == 0 { "A" } else { "B" }}"
              } else {
                "\{a.kind.name()}\{a.instance}"
              }
              rows.push({
                device: a.id,
                signal,
                gpio,
                header_pin,
                resource,
                bus: a.bus,
              })
            }
            None => ()
          }
        None => ()
      }
    }
  }
  rows
}
