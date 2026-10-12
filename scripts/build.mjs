import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { copyFileSync, mkdirSync } from 'node:fs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
execFileSync('moon', ['build', '--target', 'js', '--release', '--deny-warn'], { cwd: root, stdio: 'inherit' });
mkdirSync(path.join(root, 'web'), { recursive: true });
copyFileSync(path.join(root, '_build/js/release/build/bridge/bridge.js'), path.join(root, 'web/pinplan.js'));
