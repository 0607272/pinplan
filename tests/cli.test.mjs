import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const invoke = (args, input) => spawnSync(process.execPath, ['bin/pinplan.mjs', ...args], { cwd: root, encoding: 'utf8', input });

test('CLI solves the mixed fixture and preserves locked GPIOs', () => {
  const p = invoke(['fixtures/mixed.json']);
  assert.equal(p.status, 0, p.stderr);
  const r = JSON.parse(p.stdout);
  assert.equal(r.status, 'solved');
  assert.equal(r.assignments.length, 4);
  assert.deepEqual(r.assignments[0].pins, { TX: 0, RX: 1 });
});

for (const [file, code, status] of [['pwm-conflict', 2, 'invalid'], ['unsatisfiable', 3, 'unsatisfiable'], ['limit', 4, 'limit']]) {
  test(`CLI ${file} returns exit ${code}`, () => {
    const p = invoke([`fixtures/${file}.json`]);
    assert.equal(p.status, code, p.stderr);
    assert.equal(JSON.parse(p.stdout).status, status);
  });
}

test('stdin input uses the same MoonBit checker', () => {
  const p = invoke(['-'], JSON.stringify({ mode: 'check', devices: [{ id: 'a', kind: 'uart', pins: { TX: 0, RX: 1 } }] }));
  assert.equal(p.status, 0, p.stderr);
  assert.equal(JSON.parse(p.stdout).mode, 'check');
});

test('malformed JSON produces a report and nonzero exit', () => {
  const p = invoke(['-'], '{');
  assert.equal(p.status, 2);
  assert.equal(JSON.parse(p.stdout).findings[0].code, 'JSON_PARSE');
});

test('missing file is a structured adapter error', () => {
  const p = invoke(['fixtures/does-not-exist.json']);
  assert.equal(p.status, 2);
  assert.equal(JSON.parse(p.stdout).findings[0].code, 'INPUT_IO');
});

test('invalid CLI options are rejected', () => {
  assert.equal(invoke(['--unexpected']).status, 2);
  assert.equal(invoke(['fixtures/mixed.json', 'extra']).status, 2);
});

test('help is available and explains exit codes', () => {
  const p = invoke(['--help']);
  assert.equal(p.status, 0);
  assert.match(p.stdout, /unsatisfiable/);
});

test('repair fixture retains motor wiring and moves the indicator', () => {
  const p = invoke(['fixtures/repair.json']);
  assert.equal(p.status, 0);
  const r = JSON.parse(p.stdout);
  assert.equal(r.assignments[0].pins.OUT, 0);
  assert.equal(r.assignments[1].pins.OUT, 1);
});

test('CLI flushes a large JSON report through a pipe before exiting', () => {
  const id = 'device-'.repeat(8000);
  const p = invoke(['-'], JSON.stringify({ mode: 'check', devices: [{ id, kind: 'pwm', pins: { OUT: 2 } }] }));
  assert.equal(p.status, 2, p.stderr);
  assert.equal(JSON.parse(p.stdout).findings[0].devices[0], id);
  assert.ok(p.stdout.endsWith('\n'));
});
