import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { run_json } from '../_build/js/release/build/bridge/bridge.js';
const run = input => JSON.parse(run_json(JSON.stringify(input)));
const invoke = (format, input) => spawnSync(process.execPath, ['bin/pinplan.mjs', '--format', format, '-'], { cwd: new URL('../', import.meta.url), input: JSON.stringify(input), encoding: 'utf8' });

// A parser independent of MoonBit's CSV serializer, including embedded CR/LF.
function csv(text) {
  const rows = []; let row = [], cell = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') { if (quoted && text[i + 1] === '"') { cell += '"'; i++; } else quoted = !quoted; }
    else if (!quoted && (c === ',' || c === '\r')) {
      row.push(cell); cell = '';
      if (c === '\r') { assert.equal(text[++i], '\n'); rows.push(row); row = []; }
    } else cell += c;
  }
  assert.equal(quoted, false); assert.equal(cell, ''); assert.deepEqual(row, []);
  return rows;
}

test('MoonBit JSON boundary preserves board context and declared addresses', () => {
  const r = run({ reserved_pins: [0, 1], devices: [{ id: 'sensor', kind: 'i2c', i2c_address: 64 }] });
  assert.equal(r.status, 'solved'); assert.deepEqual(r.reserved_pins, [0, 1]);
  assert.equal(r.assignments[0].i2c_address, 64);
  assert.ok(r.wiring.every(w => !r.reserved_pins.includes(w.gpio)));
  assert.equal(run({ mode: 'check', reserved_pins: r.reserved_pins, devices: r.assignments }).status, 'solved');
  for (const reserved_pins of [null, [0.5], [0, 0], [25], '0']) {
    assert.equal(run({ reserved_pins, devices: [] }).status, 'invalid');
  }
  for (const i2c_address of [0, 127, 64.5, '64']) {
    assert.equal(run({ devices: [{ id: 'sensor', kind: 'i2c', i2c_address }] }).status, 'invalid');
  }
});

test('CSV roundtrip handles Unicode, quotes, commas, newlines and formula-like names', () => {
  const id = ' \t=HYPERLINK("危险,😀")\r\nnext';
  const bus = '+总线,"\n';
  const r = run({ reserved_pins: [0], devices: [{ id, bus, kind: 'i2c', pins: { SDA: 4, SCL: 5 }, i2c_address: 64 }] });
  assert.equal(r.status, 'solved');
  const rows = csv(r.exports.csv);
  assert.equal(rows.length, 3);
  assert.deepEqual(rows[1], ['0', "'" + id, 'SDA', '4', '6', 'i2c0', "'" + bus, '64', '0', '']);
  assert.match(r.exports.pico_header, /#define PINPLAN_DEVICE_0_I2C_ADDRESS 64\n/);
  assert.ok(!r.exports.pico_header.includes(id));
  assert.ok(!r.exports.pico_header.includes(bus));
});

test('unknown I2C address is explicit and export failures never contain artifacts', () => {
  const r = run({ devices: [{ id: 'unknown', kind: 'i2c' }] });
  assert.equal(r.assignments[0].i2c_address, null);
  assert.match(r.exports.pico_header, /I2C_ADDRESS_KNOWN 0/);
  const devices = ['a', 'b'].map(id => ({ id, kind: 'i2c', bus: 'sensors', pins: { SDA: 4, SCL: 5 }, i2c_address: 64 }));
  const conflict = run({ mode: 'check', devices });
  assert.equal(conflict.status, 'invalid'); assert.equal(conflict.exports, undefined);
  assert.ok(conflict.findings.some(f => f.code === 'I2C_ADDRESS_CONFLICT'));
  const d = run({ mode: 'diagnose', devices });
  assert.equal(d.status, 'unsatisfiable'); assert.equal(d.diagnosis.irreducible, true);
  assert.deepEqual(d.diagnosis.core_devices, ['a', 'b']);
});

test('CLI formats emit actual files; errors use stderr and empty stdout', () => {
  const input = { devices: [{ id: 'led', kind: 'pwm', pins: { OUT: 2 } }] };
  for (const format of ['csv', 'pico-header']) {
    const p = invoke(format, input);
    assert.equal(p.status, 0, p.stderr); assert.equal(p.stderr, '');
    if (format === 'csv') assert.equal(csv(p.stdout)[1][3], '2');
    else assert.match(p.stdout, /#define PINPLAN_DEVICE_0_OUT_GPIO 2\n/);
    for (const [bad, exit] of [[{ ...input, reserved_pins: [2] }, 3], [{ ...input, max_nodes: 0 }, 4], [{ devices: [{}] }, 2]]) {
      const e = invoke(format, bad);
      assert.equal(e.status, exit); assert.equal(e.stdout, ''); assert.ok(JSON.parse(e.stderr).findings.length);
    }
  }
  assert.equal(invoke('unknown', input).status, 2);
  const help = spawnSync(process.execPath, ['bin/pinplan.mjs', '--format', 'csv', '--help'], { cwd: new URL('../', import.meta.url), encoding: 'utf8' });
  assert.equal(help.status, 2); assert.equal(help.stdout, ''); assert.equal(JSON.parse(help.stderr).findings[0].code, 'CLI_USAGE');
});

test('repair exports retain proven and unproven optimality metadata', () => {
  const pwm = (id, pin) => ({ id, kind: 'pwm', ...(pin === undefined ? {} : { pins: { OUT: pin } }) });
  for (const [max_nodes, optimal] of [[8, false], [50000, true]]) {
    const r = run({ mode: 'repair', max_nodes, devices: ['a', 'b', 'c'].map(id => pwm(id)), baseline: ['a', 'b', 'c'].map(id => pwm(id, 0)) });
    assert.equal(r.status, 'solved'); assert.equal(r.repair.optimal, optimal);
    assert.ok(csv(r.exports.csv).slice(1).every(row => row.at(-1) === String(optimal)));
    assert.match(r.exports.pico_header, /#define PINPLAN_REPAIR_OPTIMAL_KNOWN 1\n/);
    assert.ok(r.exports.pico_header.includes(`#define PINPLAN_REPAIR_OPTIMAL ${optimal ? 1 : 0}\n`));
  }
});
