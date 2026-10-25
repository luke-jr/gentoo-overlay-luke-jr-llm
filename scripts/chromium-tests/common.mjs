// Shared by the runtime checks: start Chromium with a temporary profile and a DevTools port of
// its own choosing, and talk to it over the DevTools protocol. Needs Node 22 or later (fetch and
// WebSocket built in).
import { spawn } from 'child_process';
import { mkdtempSync, readFileSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Starts chrome with a new profile; resolves when its DevTools endpoint answers.
export async function launch(chrome, args = [], { headless = true } = {}) {
  const profile = mkdtempSync(join(tmpdir(), 'chromium-test-'));
  const proc = spawn(chrome, [...(headless ? ['--headless=new'] : []), '--no-sandbox', '--no-first-run',
    '--remote-debugging-port=0', `--user-data-dir=${profile}`, ...args], { stdio: 'ignore' });
  let port;
  for (let i = 0; i < 150 && !port; i++) {
    try { port = Number(readFileSync(join(profile, 'DevToolsActivePort'), 'utf8').split('\n')[0]); } catch { }
    if (!port) await sleep(200);
  }
  if (!port) throw new Error('chrome did not start');
  const base = `http://127.0.0.1:${port}`;
  return {
    proc, profile, base,
    async close() { proc.kill(); await sleep(500); proc.kill('SIGKILL'); rmSync(profile, { recursive: true, force: true }); },
  };
}

// A DevTools protocol connection: send(method, params) resolves with the reply; onEvent(fn) sees
// every event.
export async function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  await new Promise((r, j) => { ws.addEventListener('open', r); ws.addEventListener('error', j); });
  let id = 0; const pending = new Map(); const listeners = [];
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } else listeners.forEach((f) => f(m));
  });
  return {
    send: (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); }),
    onEvent: (f) => listeners.push(f),
    close: () => ws.close(),
  };
}

// Opens url in a new tab; returns its DevTools target.
export async function newTab(browser, url) {
  return (await fetch(`${browser.base}/json/new?${url}`, { method: 'PUT' })).json();
}
