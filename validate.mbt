///|
fn finding(
  code : String,
  message : String,
  devices : Array[String],
  resource : String,
) -> Finding {
  { code, message, devices, resource, }
}

///|
/// Validate device declarations independently of a chosen resource assignment.
pub fn validate_devices(devices : Array[Device]) -> Array[Finding] {
  let findings : Array[Finding] = []
  if devices.length() > 16 {
    findings.push(
      finding(
        "DEVICE_LIMIT",
        "At most 16 devices are supported per request.",
        [],
        "devices",
      ),
    )
  }
  let ids : Map[String, Bool] = Map([])
  for d in devices {
    if d.id.length() == 0 || d.id.length() > 80 {
      findings.push(
        finding(
          "INVALID_ID",
          "Device id must contain 1..80 UTF-16 code units.",
          [d.id],
          "id",
        ),
      )
    }
    if ids.contains(d.id) {
      findings.push(
        finding(
          "DUPLICATE_ID",
          "Device id is used more than once.",
          [d.id],
          "id",
        ),
      )
    }
    ids[d.id] = true
    for signal, pin in d.pins {
      if !signals(d.kind).contains(signal) {
        findings.push(
          finding(
            "UNKNOWN_SIGNAL",
            "Unknown signal \{signal} for \{d.kind.name()}.",
            [d.id],
            signal,
          ),
        )
      }
      if !is_available(pin) {
        findings.push(
          finding(
            "PIN_UNAVAILABLE",
            "GPIO\{pin} is not exposed on the original Pico.",
            [d.id],
            "GPIO\{pin}",
          ),
        )
      }
    }
    if d.frequency_hz < 0 ||
      d.frequency_hz > 1000000000 ||
      (d.kind == Pwm && d.frequency_hz == 0) {
      findings.push(
        finding(
          "INVALID_FREQUENCY",
          "Frequency must be 0..1000000000 Hz, and positive for PWM.",
          [d.id],
          "frequency_hz",
        ),
      )
    }
    match d.instance {
      Some(n) =>
        if n < 0 || n > (if d.kind == Pwm { 7 } else { 1 }) {
          findings.push(
            finding(
              "INVALID_INSTANCE",
              "Instance is outside the peripheral's supported range.",
              [d.id],
              "instance",
            ),
          )
        }
      None => ()
    }
    match d.bus {
      Some(bus) => {
        if bus.length() == 0 || bus.length() > 80 {
          findings.push(
            finding(
              "INVALID_BUS",
              "Bus name must contain 1..80 UTF-16 code units.",
              [d.id],
              "bus",
            ),
          )
        }
        if d.kind != I2c && d.kind != Spi {
          findings.push(
            finding(
              "BUS_KIND",
              "Only I2C and SPI support explicit shared buses.",
              [d.id],
              bus,
            ),
          )
        }
      }
      None => ()
    }
  }
  findings
}

///|
fn same_bus(a : Assignment, b : Assignment) -> Bool {
  match (a.bus, b.bus) {
    (Some(x), Some(y)) => x == y
    _ => false
  }
}

///|
fn shared_signal(
  a : Assignment,
  b : Assignment,
  sa : String,
  sb : String,
) -> Bool {
  same_bus(a, b) &&
  a.kind == b.kind &&
  (a.kind == I2c || a.kind == Spi) &&
  a.instance == b.instance &&
  a.frequency_hz == b.frequency_hz &&
  sa == sb &&
  sa != "CS"
}

///|
fn pair_conflicts(a : Assignment, b : Assignment) -> Array[Finding] {
  let findings : Array[Finding] = []
  let ids = [a.id, b.id]
  let shared = same_bus(a, b)
  if shared {
    if a.kind != b.kind || (a.kind != I2c && a.kind != Spi) {
      findings.push(
        finding(
          "BUS_KIND", "A shared bus name cannot span different peripheral kinds.",
          ids, "bus",
        ),
      )
    } else {
      if a.instance != b.instance {
        findings.push(
          finding(
            "BUS_INSTANCE", "A shared bus must use one peripheral instance.", ids,
            "bus",
          ),
        )
      }
      if a.frequency_hz != b.frequency_hz {
        findings.push(
          finding(
            "BUS_FREQUENCY", "Shared bus frequency metadata must match exactly.",
            ids, "bus",
          ),
        )
      }
      for signal in signals(a.kind) {
        if signal != "CS" && a.pins.get(signal) != b.pins.get(signal) {
          findings.push(
            finding(
              "BUS_ROUTING",
              "Shared \{signal} must use the same GPIO.",
              ids,
              signal,
            ),
          )
        }
      }
    }
  }
  if a.kind == b.kind && a.kind != Pwm && a.instance == b.instance && !shared {
    findings.push(
      finding(
        "INSTANCE_CONFLICT",
        "Independent devices cannot reserve the same peripheral instance.",
        ids,
        "\{a.kind.name()}\{a.instance}",
      ),
    )
  }
  for sa in signals(a.kind) {
    match a.pins.get(sa) {
      Some(pa) =>
        for sb in signals(b.kind) {
          match b.pins.get(sb) {
            Some(pb) =>
              if pa == pb && !shared_signal(a, b, sa, sb) {
                findings.push(
                  finding(
                    "PIN_CONFLICT",
                    "GPIO\{pa} is reserved by both devices.",
                    ids,
                    "GPIO\{pa}",
                  ),
                )
              }
            None => ()
          }
        }
      None => ()
    }
  }
  if a.kind == Pwm && b.kind == Pwm && a.instance == b.instance {
    match (a.pins.get("OUT"), b.pins.get("OUT")) {
      (Some(pa), Some(pb)) =>
        if pwm_channel(pa) == pwm_channel(pb) {
          findings.push(
            finding(
              "PWM_CHANNEL",
              "Two devices cannot independently use the same PWM slice/channel, even on different GPIOs.",
              ids,
              "PWM\{a.instance}/\{pwm_channel(pa)}",
            ),
          )
        }
      _ => ()
    }
    if a.frequency_hz != b.frequency_hz {
      findings.push(
        finding(
          "PWM_FREQUENCY",
          "The A/B channels of a PWM slice share the configured frequency.",
          ids,
          "PWM\{a.instance}",
        ),
      )
    }
  }
  findings
}

///|
/// Validate full concrete assignments, including GPIO and peripheral conflicts.
pub fn check_assignments(assignments : Array[Assignment]) -> Array[Finding] {
  let declarations = assignments.map(fn(a) {
    device(
      a.id,
      a.kind,
      pins=a.pins,
      instance=Some(a.instance),
      bus=a.bus,
      frequency_hz=a.frequency_hz,
    )
  })
  let findings = validate_devices(declarations)
  for a in assignments {
    for signal in signals(a.kind) {
      match a.pins.get(signal) {
        None =>
          findings.push(
            finding(
              "MISSING_SIGNAL",
              "Required signal \{signal} is missing.",
              [a.id],
              signal,
            ),
          )
        Some(pin) =>
          if !supports(a.kind, a.instance, signal, pin) {
            findings.push(
              finding(
                "SIGNAL_MAPPING",
                "GPIO\{pin} cannot carry \{a.kind.name()}\{a.instance} \{signal}.",
                [a.id],
                "GPIO\{pin}",
              ),
            )
          }
      }
    }
    let assigned_signals = signals(a.kind)
    for i = 0; i < assigned_signals.length(); i = i + 1 {
      for j = i + 1; j < assigned_signals.length(); j = j + 1 {
        match
          (a.pins.get(assigned_signals[i]), a.pins.get(assigned_signals[j])) {
          (Some(x), Some(y)) =>
            if x == y {
              findings.push(
                finding(
                  "PIN_SELF_CONFLICT",
                  "Different signals on one device cannot share a GPIO.",
                  [a.id],
                  "GPIO\{x}",
                ),
              )
            }
          _ => ()
        }
      }
    }
  }
  for i = 0; i < assignments.length(); i = i + 1 {
    for j = i + 1; j < assignments.length(); j = j + 1 {
      for item in pair_conflicts(assignments[i], assignments[j]) {
        findings.push(item)
      }
    }
  }
  findings
}
