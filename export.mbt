///|
// Always quote CSV cells. An apostrophe prevents user-controlled names from
// becoming spreadsheet formulas, including after leading whitespace.
fn csv_cell(text : String, user_value? : Bool = false) -> String {
  let mut escaped = ""
  for unit in text.iter() {
    escaped = escaped + (if unit == '"' { "\"\"" } else { unit.to_string() })
  }
  if user_value {
    // Prefix every nonempty user value: no spreadsheet-specific whitespace
    // interpretation can expose a formula. The prefix is part of the export.
    if text.length() > 0 {
      escaped = "'" + escaped
    }
  }
  "\"" + escaped + "\""
}

///|
/// Verified signal endpoints, not an electrical safety certificate.
/// User ID/bus cells carry a literal apostrophe prefix for spreadsheet safety.
pub fn export_wiring_csv(
  assignments : Array[Assignment],
  reserved_pins? : Array[Int] = [],
  repair_optimal? : Bool? = None,
) -> String? {
  if !check_assignments(assignments, reserved_pins~).is_empty() {
    return None
  }
  let lines : Array[String] = [
    "device_index,device,signal,gpio,header_pin,resource,bus,i2c_address,reserved_pins,repair_optimal",
  ]
  let reservations = reserved_pins.map(fn(pin) { pin.to_string() }).join(" ")
  for index = 0; index < assignments.length(); index = index + 1 {
    let a = assignments[index]
    let address = match a.i2c_address {
      Some(n) => n.to_string()
      None => ""
    }
    for row in wiring_rows([a], reserved_pins~) {
      lines.push(
        [
          index.to_string(),
          csv_cell(a.id, user_value=true),
          csv_cell(row.signal),
          row.gpio.to_string(),
          row.header_pin.to_string(),
          csv_cell(row.resource),
          csv_cell(
            match a.bus {
              Some(b) => b
              None => ""
            },
            user_value=true,
          ),
          address,
          csv_cell(reservations),
          match repair_optimal {
            Some(b) => b.to_string()
            None => ""
          },
        ].join(","),
      )
    }
  }
  Some(lines.join("\r\n") + "\r\n")
}

///|
/// Numeric constants for Pico SDK projects. No initialization or drivers.
/// Device indices match the JSON assignments array; names never enter C code.
pub fn export_pico_header(
  assignments : Array[Assignment],
  reserved_pins? : Array[Int] = [],
  repair_optimal? : Bool? = None,
) -> String? {
  if !check_assignments(assignments, reserved_pins~).is_empty() {
    return None
  }
  let lines = [
    "/* PinPlan: original Pico signal constants; no hardware initialization.",
    " * Feasible mapping only. Consult JSON for repair optimality and IDs.",
    " * I2C_ADDRESS_KNOWN=0 means address collisions could not be fully checked. */",
    "#ifndef PINPLAN_CONFIG_H",
    "#define PINPLAN_CONFIG_H",
    "#define PINPLAN_DEVICE_COUNT \{assignments.length()}",
    "#define PINPLAN_RESERVED_COUNT \{reserved_pins.length()}",
  ]
  match repair_optimal {
    Some(optimal) => {
      lines.push("#define PINPLAN_REPAIR_OPTIMAL_KNOWN 1")
      lines.push(
        "#define PINPLAN_REPAIR_OPTIMAL \{if optimal { 1 } else { 0 }}",
      )
      if !optimal {
        lines.push(
          "/* REPAIR_LIMIT: feasible repair; minimum changes not proven. */",
        )
      }
    }
    None => lines.push("#define PINPLAN_REPAIR_OPTIMAL_KNOWN 0")
  }
  for i = 0; i < reserved_pins.length(); i = i + 1 {
    lines.push("#define PINPLAN_RESERVED_\{i}_GPIO \{reserved_pins[i]}")
  }
  for i = 0; i < assignments.length(); i = i + 1 {
    let a = assignments[i]
    let prefix = "PINPLAN_DEVICE_\{i}"
    lines.push("#define \{prefix}_INSTANCE \{a.instance}")
    lines.push("#define \{prefix}_FREQUENCY_HZ \{a.frequency_hz}")
    if a.kind == I2c {
      match a.i2c_address {
        Some(n) => {
          lines.push("#define \{prefix}_I2C_ADDRESS_KNOWN 1")
          lines.push("#define \{prefix}_I2C_ADDRESS \{n}")
        }
        None => lines.push("#define \{prefix}_I2C_ADDRESS_KNOWN 0")
      }
    }
    for row in wiring_rows([a], reserved_pins~) {
      lines.push("#define \{prefix}_\{row.signal}_GPIO \{row.gpio}")
      lines.push("#define \{prefix}_\{row.signal}_HEADER_PIN \{row.header_pin}")
      if a.kind == Pwm {
        lines.push("#define \{prefix}_PWM_SLICE \{a.instance}")
        lines.push("#define \{prefix}_PWM_CHANNEL \{pwm_channel(row.gpio)}")
      }
    }
  }
  lines.push("#endif /* PINPLAN_CONFIG_H */")
  Some(lines.join("\n") + "\n")
}
