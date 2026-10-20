#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { run_json } from '../_build/js/release/build/bridge/bridge.js';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const help = `PinPlan — Raspberry Pi Pico pin planner

Usage: node bin/pinplan.mjs [--format json|csv|pico-header] [INPUT.json|-]
  -       read JSON from stdin
  --help  show this help

Exit codes: 0 solved, 2 invalid input/configuration, 3 proven unsatisfiable,
4 search budget exhausted (infeasibility not proven).

JSON modes: plan, check, repair (requires baseline), diagnose.
A solved repair can have repair.optimal=false; inspect it before claiming minimum.
A proven diagnosis can have diagnosis.irreducible=false if reduction times out.
Solved reports include wiring rows with original Pico physical header numbers.
CSV/header formats emit only verified signal constants, not hardware drivers.
For non-JSON formats errors are JSON on stderr; stdout stays empty.
Consult the JSON report for repair optimality before using an exported mapping.`;

function errorReport(code, message) {
  return JSON.stringify({ schema_version: 1, board: 'pico', mode: 'unknown', status: 'invalid', assignments: [], findings: [{ code, message, devices: [], resource: 'cli' }], nodes: 0 }, null, 2);
}

function main() {
const args = process.argv.slice(2);
if (args.includes('--help') || args.includes('-h')) {
  if (args.length !== 1) { console.error(errorReport('CLI_USAGE', '--help must be used alone.')); return 2; }
  console.log(help); return 0;
}
let format = 'json', inputPath, formatSeen = false;
function emitError(report) {
  (format === 'json' ? process.stdout : process.stderr).write(`${report}\n`);
}
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--format' && !formatSeen) {
    formatSeen = true;
    const value = args[++i];
    if (!['json', 'csv', 'pico-header'].includes(value)) {
      console.error(errorReport('CLI_USAGE', '--format requires json, csv or pico-header.'));
      return 2;
    }
    format = value;
  } else if ((!args[i].startsWith('-') || args[i] === '-') && inputPath === undefined) {
    inputPath = args[i];
  } else {
    // Usage failures never risk contaminating a redirected artifact.
    console.error(errorReport('CLI_USAGE', 'Provide one input path and at most one --format option.'));
    return 2;
  }
}
if (inputPath?.startsWith('-') && inputPath !== '-') {
  emitError(errorReport('CLI_USAGE', 'Provide one JSON file path or - for stdin.'));
  return 2;
}

let input;
try {
  input = inputPath === '-' || !inputPath
    ? readFileSync(0, 'utf8')
    : readFileSync(path.resolve(root, inputPath), 'utf8');
} catch (error) {
  emitError(errorReport('INPUT_IO', `Cannot read input: ${error.message}`));
  return 2;
}

let report;
try {
  report = JSON.parse(run_json(input));
} catch (error) {
  emitError(errorReport('BRIDGE_ERROR', `MoonBit bridge failed: ${error.message}`));
  return 2;
}
if (format === 'json') process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
else if (report.status !== 'solved') emitError(JSON.stringify(report, null, 2));
else {
  const artifact = report.exports?.[format === 'csv' ? 'csv' : 'pico_header'];
  if (typeof artifact !== 'string') {
    emitError(errorReport('EXPORT_INVALID', 'No independently verified artifact is available.'));
    return 2;
  }
  process.stdout.write(artifact);
}
return { solved: 0, invalid: 2, unsatisfiable: 3, limit: 4 }[report.status] ?? 2;
}

// Allow stdout/stderr to drain before Node exits, including when piped.
process.exitCode = main();
