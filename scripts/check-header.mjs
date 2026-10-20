// CI must compile real generated C, rather than comparing the serializer to itself.
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { run_json } from '../_build/js/release/build/bridge/bridge.js';

const r = JSON.parse(run_json(JSON.stringify({
  reserved_pins: [20],
  devices: [
    { id: '*/\n#error attack', kind: 'pwm', pins: { OUT: 2 }, frequency_hz: 50 },
    { id: '😀,"sensor', kind: 'i2c', bus: '*/\n', pins: { SDA: 4, SCL: 5 }, i2c_address: 64 },
    { id: 'unknown', kind: 'i2c', pins: { SDA: 6, SCL: 7 } },
  ],
})));
assert.equal(r.status, 'solved');
const dir = mkdtempSync(join(tmpdir(), 'pinplan-header-'));
try {
  writeFileSync(join(dir, 'pinplan_config.h'), r.exports.pico_header);
  writeFileSync(join(dir, 'test.c'), `#include "pinplan_config.h"
#include "pinplan_config.h"
_Static_assert(PINPLAN_DEVICE_COUNT == 3, "count");
_Static_assert(PINPLAN_RESERVED_0_GPIO == 20, "reservation");
_Static_assert(PINPLAN_DEVICE_0_OUT_GPIO == 2, "gpio");
_Static_assert(PINPLAN_DEVICE_0_OUT_HEADER_PIN == 4, "contact");
_Static_assert(PINPLAN_DEVICE_0_PWM_SLICE == 1, "slice");
_Static_assert(PINPLAN_DEVICE_0_PWM_CHANNEL == 0, "channel");
_Static_assert(PINPLAN_DEVICE_1_I2C_ADDRESS == 64, "address");
_Static_assert(PINPLAN_DEVICE_1_I2C_ADDRESS_KNOWN == 1, "known");
_Static_assert(PINPLAN_DEVICE_2_I2C_ADDRESS_KNOWN == 0, "unknown");
int main(void) { return 0; }
`);
  const p = spawnSync('cc', ['-std=c11', '-Wall', '-Wextra', '-Werror', '-fsyntax-only', join(dir, 'test.c')], { encoding: 'utf8' });
  if (p.error) throw p.error;
  assert.equal(p.status, 0, p.stderr);
  console.log('Generated Pico header compiled with C11 static assertions.');
} finally {
  // Only the directory just created by mkdtemp is removed.
  rmSync(dir, { recursive: true, force: true });
}
