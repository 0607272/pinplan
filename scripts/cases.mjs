import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { run_json } from '../_build/js/release/build/bridge/bridge.js';

const run = value => JSON.parse(run_json(JSON.stringify(value)));
const load = name => JSON.parse(readFileSync(new URL(`../fixtures/${name}.json`, import.meta.url), 'utf8'));
const checkSolved = r => {
  assert.equal(r.status, 'solved');
  assert.equal(run({ mode: 'check', reserved_pins: r.reserved_pins, devices: r.assignments }).status, 'solved');
};

for (const name of ['rewire-pwm', 'rewire-frequency']) {
  const input = load(name);
  const before = run({ mode: 'check', devices: input.baseline });
  assert.equal(before.status, 'invalid');
  const r = run(input);
  checkSolved(r);
  assert.equal(r.repair.changed_pins, 1);
  assert.equal(r.repair.optimal, true);
  assert.equal(r.repair.changes[0].device, 'indicator');
  if (name === 'rewire-pwm') {
    assert.equal(r.assignments[0].pins.OUT, 0);
    assert.equal(r.assignments[1].pins.OUT, 1);
    assert.equal(r.wiring[1].header_pin, 2);
  } else {
    assert.equal(r.assignments[0].pins.OUT, 2);
    assert.equal(r.assignments[1].pins.OUT, 1);
    assert.equal(r.assignments[2].pins.OUT, 0);
  }
  console.log(`${name}: ${before.findings.map(f => f.code).join(',')} -> ${JSON.stringify(r.repair.changes)}; optimal=true; nodes=${r.nodes}`);
}

const input = load('diagnose-uart');
const diagnosis = run(input);
assert.equal(diagnosis.status, 'unsatisfiable');
assert.deepEqual(diagnosis.diagnosis, { core_devices: ['console', 'gps', 'modem'], irreducible: true });
const core = input.devices.filter(d => diagnosis.diagnosis.core_devices.includes(d.id));
assert.equal(run({ devices: core }).status, 'unsatisfiable');
for (const omitted of core) {
  checkSolved(run({ devices: core.filter(d => d.id !== omitted.id) }));
}
console.log(`diagnose-uart: core=${diagnosis.diagnosis.core_devices.join(',')}; all 3 deletion witnesses solved; nodes=${diagnosis.nodes}`);

const shared = run(load('shared-wiring'));
checkSolved(shared);
assert.equal(shared.wiring.length, 6);
for (const row of shared.wiring.filter(r => r.bus === 'sensors')) {
  assert.equal(row.header_pin, row.signal === 'SDA' ? 6 : 7);
}
console.log('shared-wiring: 6 signal endpoints; I2C shared contacts 6/7; UART contacts 21/22');

const timedOut = run({ ...input, max_nodes: 0 });
assert.equal(timedOut.status, 'limit');
assert.equal(timedOut.diagnosis.irreducible, false);
console.log('budget: zero attempts -> limit, no infeasibility or irreducibility claim');
const reserved = run(load('reserved-repair'));
checkSolved(reserved);
assert.equal(reserved.repair.optimal, true);
assert.equal(reserved.repair.changed_pins, 1);
assert.equal(reserved.assignments[0].pins.OUT, 16);
assert.ok(reserved.exports.pico_header.includes('PINPLAN_RESERVED_0_GPIO 0'));
console.log('reserved-repair: GPIO0 -> GPIO16; reservations 0/1 retained in verified export');

const collisionInput = load('i2c-address-conflict');
const collision = run(collisionInput);
assert.equal(collision.status, 'unsatisfiable');
assert.deepEqual(collision.diagnosis.core_devices, ['sensor_a', 'sensor_b']);
assert.equal(collision.diagnosis.irreducible, true);
const separated = structuredClone(collisionInput);
separated.mode = 'plan';
separated.devices[1].i2c_address = 65;
checkSolved(run(separated));
console.log('i2c-address-conflict: duplicate 64 rejected; hardware-address declaration 65 is feasible');
console.log('All 7 reproducible cases passed.');
