import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync, spawn } from 'node:child_process';

const cli = fileURLToPath(new URL('../bin/pinplan.mjs', import.meta.url));
const input = JSON.stringify({ devices: [{ id: '灯😀', kind: 'pwm', pins: { OUT: 2 } }] });
const invoke = (args, bytes, cwd) => spawnSync(process.execPath, [cli, ...args], { input: bytes, cwd, encoding: 'utf8' });

test('CLI resolves relative input paths against the caller working directory', () => {
  const dir = mkdtempSync(join(tmpdir(), 'pinplan-cwd-'));
  try {
    writeFileSync(join(dir, 'caller.json'), input);
    const p = invoke(['caller.json'], undefined, dir);
    assert.equal(p.status, 0, p.stdout + p.stderr);
    assert.equal(JSON.parse(p.stdout).assignments[0].id, '灯😀');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('UTF-8 BOM is accepted from files and stdin without altering names', () => {
  const dir = mkdtempSync(join(tmpdir(), 'pinplan-bom-'));
  try {
    const file = join(dir, 'utf8-bom.json'); writeFileSync(file, '\ufeff' + input);
    for (const p of [invoke([file]), invoke(['-'], Buffer.from('\ufeff' + input))]) {
      assert.equal(p.status, 0, p.stdout + p.stderr);
      assert.equal(JSON.parse(p.stdout).assignments[0].id, '灯😀');
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('UTF-8 decoding rejects malformed or truncated byte sequences', () => {
  for (const bytes of [Buffer.from([0xc3, 0x28]), Buffer.from([0xf0, 0x9f]), Buffer.from([0xff, 0xfe])]) {
    const p = invoke(['--format', 'csv', '-'], bytes);
    assert.equal(p.status, 2); assert.equal(p.stdout, '');
    assert.equal(JSON.parse(p.stderr).findings[0].code, 'INPUT_ENCODING');
  }
});

test('input limit counts UTF-16 units and handles multibyte chunk boundaries', () => {
  const boundary = ' '.repeat(8191 - '{"devices":[{"id":"'.length) + input;
  const exact = ' '.repeat(65536 - input.length) + input;
  for (const text of [boundary, exact]) {
    const p = invoke(['-'], Buffer.from(text));
    assert.equal(p.status, 0, p.stdout + p.stderr);
    assert.equal(JSON.parse(p.stdout).assignments[0].id, '灯😀');
  }
  const p = invoke(['-'], Buffer.from(exact + ' '));
  assert.equal(p.status, 2); assert.equal(JSON.parse(p.stdout).findings[0].code, 'INPUT_SIZE');
});

test('oversized stdin is rejected before the sender closes the stream', { timeout: 15000 }, async () => {
  const p = spawn(process.execPath, [cli, '-'], { stdio: ['pipe', 'pipe', 'pipe'] });
  let output = '', errors = '';
  p.stdout.setEncoding('utf8'); p.stdout.on('data', data => output += data);
  p.stderr.setEncoding('utf8'); p.stderr.on('data', data => errors += data);
  p.stdin.on('error', () => {}); // Early rejection may close the input pipe.
  const closed = new Promise((resolve, reject) => { p.once('error', reject); p.once('close', resolve); });
  try {
    p.stdin.write(Buffer.alloc(70000, 32)); // Deliberately no end().
    const timeout = setTimeout(() => p.kill(), 10000);
    try {
      assert.equal(await closed, 2, output + errors);
      assert.equal(JSON.parse(output).findings[0].code, 'INPUT_SIZE');
    } finally { clearTimeout(timeout); }
  } finally { p.stdin.destroy(); if (p.exitCode === null) p.kill(); }
});
