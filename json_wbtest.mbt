///|
fn json_status(text : String) -> String raise {
  match @json.parse(run_json(text)) {
    Object(fields) =>
      match fields.get("status") {
        Some(String(s)) => s
        _ => fail("Missing status")
      }
    _ => fail("API response must be a JSON object")
  }
}

///|
test "JSON API plans a real setup and rejects malformed input" {
  assert_eq(
    json_status(
      "{\"devices\":[{\"id\":\"console\",\"kind\":\"uart\",\"pins\":{\"TX\":0,\"RX\":1}}]}",
    ),
    "solved",
  )
  for text in ["{", "[]", "{}", "{\"devices\":null}", "{\"devices\":[{}]}"] {
    assert_eq(json_status(text), "invalid")
  }
}

///|
test "unknown fields, kinds, boards and modes are rejected" {
  for
    text in [
      "{\"board\":\"esp32\",\"devices\":[]}", "{\"mode\":\"scan\",\"devices\":[]}",
      "{\"devices\":[],\"typo\":true}", "{\"devices\":[{\"id\":\"a\",\"kind\":\"adc\"}]}",
      "{\"devices\":[{\"id\":\"a\",\"kind\":\"uart\",\"pin\":0}]}",
    ] {
    assert_eq(json_status(text), "invalid")
  }
}

///|
test "integer fields never silently truncate fractional JSON values" {
  for
    text in [
      "{\"devices\":[],\"max_nodes\":1.5}", "{\"devices\":[],\"max_nodes\":-1}",
      "{\"devices\":[],\"max_nodes\":1e400}", "{\"devices\":[{\"id\":\"a\",\"kind\":\"pwm\",\"pins\":{\"OUT\":0.5}}]}",
      "{\"devices\":[{\"id\":\"a\",\"kind\":\"pwm\",\"frequency_hz\":\"50\"}]}",
    ] {
    assert_eq(json_status(text), "invalid")
  }
}

///|
test "check mode requires a complete assignment and detects a concrete conflict" {
  assert_eq(
    json_status(
      "{\"mode\":\"check\",\"devices\":[{\"id\":\"a\",\"kind\":\"uart\",\"pins\":{\"TX\":0}}]}",
    ),
    "invalid",
  )
  assert_eq(
    json_status(
      "{\"mode\":\"check\",\"devices\":[{\"id\":\"a\",\"kind\":\"pwm\",\"pins\":{\"OUT\":0}},{\"id\":\"b\",\"kind\":\"pwm\",\"pins\":{\"OUT\":16}}]}",
    ),
    "invalid",
  )
  assert_eq(
    json_status(
      "{\"mode\":\"check\",\"devices\":[{\"id\":\"a\",\"kind\":\"uart\",\"pins\":{\"TX\":0,\"RX\":1}}]}",
    ),
    "solved",
  )
}

///|
test "JSON preserves explicit limit and proven no solution statuses" {
  assert_eq(
    json_status(
      "{\"max_nodes\":0,\"devices\":[{\"id\":\"a\",\"kind\":\"uart\"}]}",
    ),
    "limit",
  )
  assert_eq(
    json_status(
      "{\"devices\":[{\"id\":\"a\",\"kind\":\"uart\",\"pins\":{\"TX\":2}}]}",
    ),
    "unsatisfiable",
  )
}

///|
test "JSON input nesting and size are bounded before device decoding" {
  let mut nested = "0"
  for _ in 0..<40 {
    nested = "[" + nested + "]"
  }
  assert_eq(json_status("{\"devices\":" + nested + "}"), "invalid")
  let oversized = String::make(65537, ' ')
  assert_eq(json_status(oversized), "invalid")
}
