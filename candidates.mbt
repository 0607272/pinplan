///|
fn clone_pins(pins : Map[String, Int]) -> Map[String, Int] {
  let copy : Map[String, Int] = Map([])
  for signal, pin in pins {
    copy[signal] = pin
  }
  copy
}

///|
/// Enumerate deterministic assignments that satisfy a device's pin/instance locks.
/// Call validate_devices first when consuming untrusted declarations.
pub fn candidates(
  d : Device,
  reserved_pins? : Array[Int] = [],
) -> Array[Assignment] {
  let result : Array[Assignment] = []
  let instances = match d.instance {
    Some(n) => [n]
    None => if d.kind == Pwm { [0, 1, 2, 3, 4, 5, 6, 7] } else { [0, 1] }
  }
  for instance in instances {
    let mut partials : Array[Map[String, Int]] = [Map([])]
    for signal in signals(d.kind) {
      let next : Array[Map[String, Int]] = []
      for pin in available_pins() {
        let matches_lock = match d.pins.get(signal) {
          Some(locked) => locked == pin
          None => true
        }
        if !reserved_pins.contains(pin) &&
          matches_lock &&
          supports(d.kind, instance, signal, pin) {
          for partial in partials {
            let copy = clone_pins(partial)
            copy[signal] = pin
            next.push(copy)
          }
        }
      }
      partials = next
    }
    for pins in partials {
      result.push({
        id: d.id,
        kind: d.kind,
        instance,
        pins,
        bus: d.bus,
        frequency_hz: d.frequency_hz,
        i2c_address: d.i2c_address,
      })
    }
  }
  result
}
