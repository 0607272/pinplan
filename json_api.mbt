///|
priv suberror InputError {
  InputError(String, String)
}

///|
priv struct Request {
  devices : Array[Device]
  mode : String
  max_nodes : Int
}

///|
fn[T] input_error(message : String) -> T raise InputError {
  raise InputError("INPUT_SCHEMA", message)
}

///|
fn object_fields(
  value : Json,
  path : String,
) -> Map[String, Json] raise InputError {
  match value {
    Object(fields) => fields
    _ => input_error("\{path}: expected an object")
  }
}

///|
fn reject_unknown(
  fields : Map[String, Json],
  allowed : Array[String],
  path : String,
) -> Unit raise InputError {
  for key, _ in fields {
    if !allowed.contains(key) {
      raise InputError("UNKNOWN_FIELD", "\{path}.\{key}: unknown field")
    }
  }
}

///|
fn required(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Json raise InputError {
  match fields.get(key) {
    Some(value) => value
    None => input_error("\{path}.\{key}: required field is missing")
  }
}

///|
fn string_value(value : Json, path : String) -> String raise InputError {
  match value {
    String(text) => text
    _ => input_error("\{path}: expected a string")
  }
}

///|
fn integer_value(value : Json, path : String) -> Int raise InputError {
  match value {
    Number(n, ..) if n >= -2147483648.0 && n <= 2147483647.0 => {
      let result = n.to_int()
      if result.to_double() != n {
        input_error("\{path}: expected an integer, not a fractional number")
      } else {
        result
      }
    }
    _ => input_error("\{path}: expected a finite 32-bit integer")
  }
}

///|
fn decode_device(value : Json, index : Int) -> Device raise InputError {
  let path = "devices[\{index}]"
  let fields = object_fields(value, path)
  reject_unknown(
    fields,
    ["id", "kind", "pins", "instance", "bus", "frequency_hz"],
    path,
  )
  let id = string_value(required(fields, "id", path), "\{path}.id")
  let kind = match
    string_value(required(fields, "kind", path), "\{path}.kind") {
    "uart" => Uart
    "spi" => Spi
    "i2c" => I2c
    "pwm" => Pwm
    _ =>
      raise InputError(
        "UNKNOWN_KIND",
        "\{path}.kind: use uart, spi, i2c or pwm",
      )
  }
  let pins : Map[String, Int] = Map([])
  match fields.get("pins") {
    Some(value) => {
      let pin_fields = object_fields(value, "\{path}.pins")
      for signal, pin in pin_fields {
        pins[signal] = integer_value(pin, "\{path}.pins.\{signal}")
      }
    }
    None => ()
  }
  let instance = match fields.get("instance") {
    None | Some(Null) => None
    Some(value) => Some(integer_value(value, "\{path}.instance"))
  }
  let bus = match fields.get("bus") {
    None | Some(Null) => None
    Some(value) => Some(string_value(value, "\{path}.bus"))
  }
  let frequency_hz = match fields.get("frequency_hz") {
    None => if kind == Pwm { 1000 } else { 0 }
    Some(value) => integer_value(value, "\{path}.frequency_hz")
  }
  device(id, kind, pins~, instance~, bus~, frequency_hz~)
}

// Core 0.10.14 exposes this depth parameter with a deprecated label_migration
// annotation. Keep its actual protection, confining compatibility to this call.

///|
#warnings("-deprecated")
fn parse_bounded(text : String) -> Json raise InputError {
  @json.parse(text, max_nesting_depth=32) catch {
    _ =>
      raise InputError(
        "JSON_PARSE", "Malformed JSON or nesting deeper than 32 levels.",
      )
  }
}

///|
fn decode_request(text : String) -> Request raise InputError {
  if text.length() > 65536 {
    raise InputError("INPUT_SIZE", "Input exceeds 65536 UTF-16 code units.")
  }
  let value = parse_bounded(text)
  let fields = object_fields(value, "$root")
  reject_unknown(fields, ["board", "mode", "devices", "max_nodes"], "$root")
  let board = match fields.get("board") {
    None => "pico"
    Some(value) => string_value(value, "board")
  }
  if board != "pico" {
    raise InputError(
      "UNKNOWN_BOARD", "Only the original Raspberry Pi Pico (board=pico) is supported.",
    )
  }
  let mode = match fields.get("mode") {
    None => "plan"
    Some(value) => string_value(value, "mode")
  }
  if mode != "plan" && mode != "check" {
    raise InputError("UNKNOWN_MODE", "mode must be plan or check.")
  }
  let max_nodes = match fields.get("max_nodes") {
    None => 50000
    Some(value) => integer_value(value, "max_nodes")
  }
  if max_nodes < 0 || max_nodes > 200000 {
    raise InputError("INVALID_BUDGET", "max_nodes must be in 0..200000.")
  }
  let values = match required(fields, "devices", "$root") {
    Array(values) => values
    _ => input_error("devices: expected an array")
  }
  if values.length() > 16 {
    raise InputError("DEVICE_LIMIT", "At most 16 devices are supported.")
  }
  let devices : Array[Device] = []
  for index = 0; index < values.length(); index = index + 1 {
    devices.push(decode_device(values[index], index))
  }
  { devices, mode, max_nodes, }
}

///|
/// Check fully specified devices, inferring a peripheral instance from mappings.
pub fn check(devices : Array[Device]) -> Report {
  let findings = validate_devices(devices)
  let assignments : Array[Assignment] = []
  for d in devices {
    let mut complete = true
    for signal in signals(d.kind) {
      if !d.pins.contains(signal) {
        complete = false
        findings.push(
          finding(
            "MISSING_SIGNAL",
            "check mode requires every signal to have an explicit GPIO.",
            [d.id],
            signal,
          ),
        )
      }
    }
    if complete {
      let cs = candidates(d)
      if cs.length() == 0 {
        findings.push(
          finding(
            "SIGNAL_MAPPING",
            "No peripheral instance accepts all explicitly assigned signals.",
            [d.id],
            d.kind.name(),
          ),
        )
      } else {
        assignments.push(cs[0])
      }
    }
  }
  if findings.length() != 0 {
    return { status: Invalid, assignments: [], findings, nodes: 0, }
  }
  let conflicts = check_assignments(assignments)
  {
    status: if conflicts.length() == 0 {
      Solved
    } else {
      Invalid
    },
    assignments,
    findings: conflicts,
    nodes: 0,
  }
}

///|
/// Convert a report to the versioned JSON response protocol.
pub fn report_json(report : Report, mode? : String = "plan") -> Json {
  let assignments = report.assignments.map(fn(a) {
    let bus : Json = match a.bus {
      Some(b) => Json::string(b)
      None => Json::null()
    }
    Json::object({
      "id": Json::string(a.id),
      "kind": Json::string(a.kind.name()),
      "instance": @json.to_json(a.instance),
      "pins": @json.to_json(a.pins),
      "bus": bus,
      "frequency_hz": @json.to_json(a.frequency_hz),
    })
  })
  let findings = report.findings.map(fn(f) {
    Json::object({
      "code": Json::string(f.code),
      "message": Json::string(f.message),
      "devices": @json.to_json(f.devices),
      "resource": Json::string(f.resource),
    })
  })
  let status = match report.status {
    Solved => "solved"
    Invalid => "invalid"
    Unsatisfiable => "unsatisfiable"
    Limit => "limit"
  }
  Json::object({
    "schema_version": @json.to_json(1),
    "board": Json::string("pico"),
    "mode": Json::string(mode),
    "status": Json::string(status),
    "assignments": Json::array(assignments),
    "findings": Json::array(findings),
    "nodes": @json.to_json(report.nodes),
  })
}

///|
/// Plan or check a bounded JSON input and always return a JSON report.
pub fn run_json(text : String) -> String {
  let report = try {
    let request = decode_request(text)
    let report = if request.mode == "check" {
      check(request.devices)
    } else {
      plan(request.devices, max_nodes=request.max_nodes)
    }
    report_json(report, mode=request.mode)
  } catch {
    InputError(code, message) =>
      report_json(
        {
          status: Invalid,
          assignments: [],
          findings: [finding(code, message, [], "input")],
          nodes: 0,
        },
        mode="unknown",
      )
  }
  report.stringify(indent=2)
}
