import test from 'node:test';
import assert from 'node:assert/strict';
import { run_json } from '../_build/js/release/build/bridge/bridge.js';

test('compiled MoonBit bridge returns a versioned report', () => {
  const report = JSON.parse(run_json(JSON.stringify({ devices: [{ id: 'a', kind: 'uart', pins: { TX: 0, RX: 1 } }] })));
  assert.equal(report.schema_version, 1);
  assert.equal(report.status, 'solved');
  assert.equal(report.assignments[0].pins.TX, 0);
});
