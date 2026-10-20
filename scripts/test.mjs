// Expand test filenames ourselves: Windows shells and Node 20 do not expand
// the same globs. Pass explicit files to the built-in Node test runner.
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const directory = new URL('../tests/', import.meta.url);
const files = readdirSync(directory).filter(name => name.endsWith('.test.mjs')).sort();
if (files.length === 0) throw new Error('No Node integration tests found.');
const run = spawnSync(process.execPath, ['--test', ...files.map(name => fileURLToPath(new URL(name, directory)))], { stdio: 'inherit' });
if (run.error) throw run.error;
process.exitCode = run.status ?? 1;
