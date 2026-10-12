///|
fn main {
  let input =
    #|{"board":"pico","devices":[
    #| {"id":"console","kind":"uart","pins":{"TX":0,"RX":1}},
    #| {"id":"sensor","kind":"i2c","pins":{"SDA":4,"SCL":5}},
    #| {"id":"display","kind":"spi"},
    #| {"id":"motor","kind":"pwm","pins":{"OUT":2},"frequency_hz":1000}
    #|]}
  println(@pinplan.run_json(input))
}
