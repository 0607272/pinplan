import test from 'node:test';
import assert from 'node:assert/strict';
import { run_json } from '../_build/js/release/build/bridge/bridge.js';

const run = value => JSON.parse(run_json(JSON.stringify(value)));
const pwm = (id, pin) => ({ id, kind: 'pwm', ...(pin === undefined ? {} : { pins: { OUT: pin } }) });

test('JSON repair exposes an optimal signal delta and physical wiring', () => {
  const r = run({ mode: 'repair', devices: [pwm('motor', 0), pwm('led')], baseline: [pwm('motor', 0), pwm('led', 16)] });
  assert.equal(r.status, 'solved');
  assert.equal(r.mode, 'repair');
  assert.equal(r.repair.optimal, true);
  assert.equal(r.repair.changed_pins, 1);
  assert.deepEqual(r.repair.changes, [{ device: 'led', signal: 'OUT', from_gpio: 16, to_gpio: 1 }]);
  assert.deepEqual(r.wiring[1], { device: 'led', signal: 'OUT', gpio: 1, header_pin: 2, resource: 'PWM0/B', bus: null });
  assert.equal(run({ mode: 'check', devices: r.assignments }).status, 'solved');
});

test('a bounded feasible repair reports incumbent rather than a false optimality claim', () => {
  const r = run({ mode: 'repair', max_nodes: 8, devices: ['a', 'b', 'c'].map(id => pwm(id)), baseline: ['a', 'b', 'c'].map(id => pwm(id, 0)) });
  assert.equal(r.status, 'solved');
  assert.equal(r.repair.changed_pins, 2);
  assert.equal(r.repair.optimal, false);
  assert.ok(r.findings.some(f => f.code === 'REPAIR_LIMIT'));
});

test('diagnosis returns only the independently reproducible unsatisfiable subset', () => {
  const devices = [pwm('motor', 0), { id: 'sensor', kind: 'i2c', pins: { SDA: 4, SCL: 5 } }, pwm('led', 16)];
  const r = run({ mode: 'diagnose', devices });
  assert.equal(r.status, 'unsatisfiable');
  assert.equal(r.diagnosis.irreducible, true);
  assert.deepEqual(r.diagnosis.core_devices, ['motor', 'led']);
  assert.equal(r.wiring, undefined);
  for (const omit of r.diagnosis.core_devices) {
    assert.equal(run({ devices: devices.filter(d => r.diagnosis.core_devices.includes(d.id) && d.id !== omit) }).status, 'solved');
  }
});

test('diagnosis uses one total budget and does not invent a proof on timeout', () => {
  const devices = [pwm('a', 0), pwm('b', 16)];
  const initialTimeout = run({ mode: 'diagnose', devices, max_nodes: 0 });
  assert.equal(initialTimeout.status, 'limit');
  assert.deepEqual(initialTimeout.diagnosis, { core_devices: [], irreducible: false });
  const reductionTimeout = run({ mode: 'diagnose', devices, max_nodes: 2 });
  assert.equal(reductionTimeout.status, 'unsatisfiable');
  assert.equal(reductionTimeout.nodes, 2);
  assert.equal(reductionTimeout.diagnosis.irreducible, false);
});

test('baseline schema is strict and cannot silently override hard locks', () => {
  for (const value of [
    { mode: 'repair', devices: [] },
    { mode: 'repair', devices: [], baseline: {} },
    { mode: 'repair', devices: [pwm('a')], baseline: [{ ...pwm('a', 0), typo: true }] },
    { mode: 'plan', devices: [], baseline: [] },
    { mode: 'repair', devices: [pwm('a')], baseline: [pwm('removed', 0)] },
    { mode: 'repair', devices: [pwm('a')], baseline: [pwm('a')] },
  ]) {
    const r = run(value);
    assert.equal(r.status, 'invalid', JSON.stringify(value));
    assert.equal(r.nodes, 0);
  }
  const locked = run({ mode: 'repair', devices: [pwm('a', 0), pwm('b', 16)], baseline: [] });
  assert.equal(locked.status, 'unsatisfiable');
  assert.equal(locked.repair.changed_pins, null);
  assert.equal(locked.repair.optimal, false);
});

test('invalid check assignments never export a usable wiring sheet', () => {
  const r = run({ mode: 'check', devices: [pwm('a', 0), pwm('b', 16)] });
  assert.equal(r.status, 'invalid');
  assert.equal(r.wiring, undefined);
});
