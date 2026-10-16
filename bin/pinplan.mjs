#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { run_json } from '../_build/js/release/build/bridge/bridge.js';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const help = `PinPlan — Raspberry Pi Pico pin planner

Usage: node bin/pinplan.mjs [INPUT.json|-]
  -       read JSON from stdin
  --help  show this help

Exit codes: 0 solved, 2 invalid input/configuration, 3 proven unsatisfiable,
4 search budget exhausted (infeasibility not proven).

JSON modes: plan, check, repair (requires baseline), diagnose.
A solved repair can have repair.optimal=false; inspect it before claiming minimum.
A proven diagnosis can have diagnosis.irreducible=false if reduction times out.
Solved reports include wiring rows with original Pico physical header numbers.`;

function errorReport(code, message) {
  return JSON.stringify({ schema_version: 1, board: 'pico', mode: 'unknown', status: 'invalid', assignments: [], findings: [{ code, message, devices: [], resource: 'cli' }], nodes: 0 }, null, 2);
}

function main() {
const args = process.argv.slice(2);
if (args.includes('--help') || args.includes('-h')) {
  if (args.length !== 1) { console.error(help); return 2; }
  console.log(help); return 0;
}
if (args.length > 1 || (args[0] && args[0].startsWith('-') && args[0] !== '-')) {
  console.log(errorReport('CLI_USAGE', 'Provide exactly one JSON file path or - for stdin.'));
  return 2;
}

let input;
try {
  input = args[0] === '-' || !args[0]
    ? readFileSync(0, 'utf8')
    : readFileSync(path.resolve(root, args[0]), 'utf8');
} catch (error) {
  console.log(errorReport('INPUT_IO', `Cannot read input: ${error.message}`));
  return 2;
}

let report;
try {
  report = JSON.parse(run_json(input));
} catch (error) {
  console.log(errorReport('BRIDGE_ERROR', `MoonBit bridge failed: ${error.message}`));
  return 2;
}
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
return { solved: 0, invalid: 2, unsatisfiable: 3, limit: 4 }[report.status] ?? 2;
}

// Allow stdout/stderr to drain before Node exits, including when piped.
process.exitCode = main();
