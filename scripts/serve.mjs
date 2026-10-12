import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const port = Number(process.env.PORT || 4173);
const server = createServer(async (request, response) => {
  const relative = request.url === '/' ? '/index.html' : request.url;
  const webRoot = path.resolve(root, 'web');
  const file = path.resolve(webRoot, `.${relative}`);
  const relativeFile = path.relative(webRoot, file);
  if (relativeFile.startsWith('..') || path.isAbsolute(relativeFile)) { response.writeHead(400); response.end('bad path'); return; }
  try {
    const body = await readFile(file);
    const type = file.endsWith('.js') ? 'text/javascript; charset=utf-8' : 'text/html; charset=utf-8';
    response.writeHead(200, { 'content-type': type, 'cache-control': 'no-store' }); response.end(body);
  } catch { response.writeHead(404); response.end('not found'); }
});
server.listen(port, '127.0.0.1', () => console.log(`PinPlan demo: http://127.0.0.1:${port}`));
