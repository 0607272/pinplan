// Verify the public source tree can be reused from a separate MoonBit module.
// This is a local path dependency check, not evidence of registry publication.
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, copyFileSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('../', import.meta.url));
const files = execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'], { cwd: root, encoding: 'utf8' }).split('\0').filter(Boolean);
assert.ok(files.includes('moon.mod'));
assert.ok(files.every(f => !f.includes('申报书') && !f.startsWith('.local/') && !f.startsWith('submission/')));
mkdirSync(join(root, '.local'), { recursive: true });
const scratch = mkdtempSync(join(root, '.local', 'consumer-'));
try {
  for (const file of files) {
    const target = join(scratch, 'library', file);
    mkdirSync(dirname(target), { recursive: true });
    copyFileSync(join(root, file), target);
  }
  const consumer = join(scratch, 'consumer');
  mkdirSync(consumer);
  // JSON manifests remain supported by Moon; local paths need no registry login.
  writeFileSync(join(consumer, 'moon.mod.json'), JSON.stringify({
    name: 'pinplan-ci/consumer', version: '0.0.0',
    deps: { '0607272/pinplan': { path: '../library' } },
  }, null, 2));
  writeFileSync(join(consumer, 'moon.pkg'), 'import { "0607272/pinplan" } for "test"\n');
  writeFileSync(join(consumer, 'consumer_test.mbt'), `
///|
test "consumer plans and checks with board context" {
  let target = [@pinplan.device("led", @pinplan.Pwm, pins={ "OUT": 0 })]
  assert_eq(@pinplan.plan(target, reserved_pins=[0]).status, @pinplan.Unsatisfiable)
  assert_eq(@pinplan.check(target, reserved_pins=[0]).status, @pinplan.Invalid)
  let result = @pinplan.plan([@pinplan.device("led", @pinplan.Pwm)], reserved_pins=[0])
  assert_eq(result.status, @pinplan.Solved)
  assert_eq(@pinplan.check_assignments(result.assignments, reserved_pins=[0]).length(), 0)
}

///|
test "consumer repairs and exports through public APIs" {
  let result = @pinplan.repair(
    [@pinplan.device("led", @pinplan.Pwm)],
    [@pinplan.device("led", @pinplan.Pwm, pins={ "OUT": 0 })],
    reserved_pins=[0],
  )
  assert_eq(result.report.status, @pinplan.Solved)
  assert_eq(result.changed_pins, Some(1))
  assert_true(result.optimal)
  assert_eq(@pinplan.wiring_rows(result.report.assignments, reserved_pins=[0])[0].header_pin, 2)
  assert_true(@pinplan.export_wiring_csv(result.report.assignments, reserved_pins=[0], repair_optimal=Some(result.optimal)) is Some(_))
  assert_true(@pinplan.export_pico_header(result.report.assignments, reserved_pins=[0]) is Some(_))
  assert_eq(@pinplan.export_pico_header(result.report.assignments, reserved_pins=[1]), None)
}

///|
test "consumer diagnoses declared I2C address collisions" {
  let devices = ["a", "b"].map(fn(id) {
    @pinplan.device(id, @pinplan.I2c, bus=Some("sensors"), pins={ "SDA": 4, "SCL": 5 }, i2c_address=Some(64))
  })
  let result = @pinplan.diagnose(devices)
  assert_eq(result.report.status, @pinplan.Unsatisfiable)
  assert_eq(result.core_devices, ["a", "b"])
  assert_true(result.irreducible)
}
`);
  const run = spawnSync(process.platform === 'win32' ? 'moon.exe' : 'moon', ['test', '--target', 'js', '--deny-warn'], { cwd: consumer, encoding: 'utf8' });
  if (run.error) throw run.error;
  process.stdout.write(run.stdout); process.stderr.write(run.stderr);
  assert.equal(run.status, 0, 'Independent MoonBit consumer failed.');
  console.log('Public source tree reused successfully from a clean local dependency.');
} finally {
  // Remove only the dedicated temporary directory created above, never root.
  rmSync(scratch, { recursive: true, force: true });
}
