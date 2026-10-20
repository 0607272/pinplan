///|
/// Supported RP2040 peripheral kinds.
pub(all) enum Kind {
  Uart
  Spi
  I2c
  Pwm
} derive(Debug, Eq)

///|
/// A device's requested resources and optional pin/instance locks.
pub(all) struct Device {
  id : String
  kind : Kind
  pins : Map[String, Int]
  instance : Int?
  bus : String?
  frequency_hz : Int
  i2c_address : Int?
} derive(Debug, Eq)

///|
/// A concrete device assignment. PWM instance denotes its slice.
pub(all) struct Assignment {
  id : String
  kind : Kind
  instance : Int
  pins : Map[String, Int]
  bus : String?
  frequency_hz : Int
  i2c_address : Int?
} derive(Debug, Eq)

///|
/// A diagnostic with stable machine-readable code and resource context.
pub(all) struct Finding {
  code : String
  message : String
  devices : Array[String]
  resource : String
} derive(Debug, Eq)

///|
/// Planning result. Limit means the search could not prove infeasibility.
pub(all) enum Status {
  Solved
  Invalid
  Unsatisfiable
  Limit
} derive(Debug, Eq)

///|
/// Resource planning or checking output.
pub(all) struct Report {
  status : Status
  assignments : Array[Assignment]
  findings : Array[Finding]
  nodes : Int
} derive(Debug, Eq)

///|
/// Construct a device; PWM defaults to 1000 Hz, serial buses to 0 (unspecified).
pub fn device(
  id : String,
  kind : Kind,
  pins? : Map[String, Int] = {},
  instance? : Int? = None,
  bus? : String? = None,
  i2c_address? : Int? = None,
  frequency_hz? : Int = if kind == Pwm { 1000 } else { 0 },
) -> Device {
  { id, kind, pins, instance, bus, frequency_hz, i2c_address, }
}

///|
/// Human-readable peripheral name used in the JSON protocol.
pub fn Kind::name(self : Kind) -> String {
  match self {
    Uart => "uart"
    Spi => "spi"
    I2c => "i2c"
    Pwm => "pwm"
  }
}

///|
/// Required signal names. SPI uses hardware CSn, represented as CS.
pub fn signals(kind : Kind) -> Array[String] {
  match kind {
    Uart => ["TX", "RX"]
    Spi => ["RX", "CS", "SCK", "TX"]
    I2c => ["SDA", "SCL"]
    Pwm => ["OUT"]
  }
}

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Device with Eq::{equal, not_equal}

///|
pub extend Assignment with Eq::{equal, not_equal}

///|
pub extend Finding with Eq::{equal, not_equal}

///|
pub extend Status with Eq::{equal, not_equal}

///|
pub extend Report with Eq::{equal, not_equal}

///|
pub extend Kind with @debug.Debug::{to_repr}

///|
pub extend Device with @debug.Debug::{to_repr}

///|
pub extend Assignment with @debug.Debug::{to_repr}

///|
pub extend Finding with @debug.Debug::{to_repr}

///|
pub extend Status with @debug.Debug::{to_repr}

///|
pub extend Report with @debug.Debug::{to_repr}
