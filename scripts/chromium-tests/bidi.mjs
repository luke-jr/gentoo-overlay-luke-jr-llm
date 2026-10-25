// WebDriver BiDi through chromedriver (and its embedded chromium-bidi mapper): session, navigation,
// script evaluation, node location, screenshots, tabs, exceptions and events.
// Usage: node bidi.mjs CHROMEDRIVER CHROME
import { spawn } from 'child_process';
import { mkdtempSync, rmSync } from 'fs';
import { createServer } from 'net';
import { tmpdir } from 'os';
import { join } from 'path';
import { connect, sleep } from './common.mjs';
const [driver, chrome] = process.argv.slice(2);
const port = await new Promise((r) => { const s = createServer().listen(0, () => { const p = s.address().port; s.close(() => r(p)); }); });
const profile = mkdtempSync(join(tmpdir(), 'chromium-test-'));
const cd = spawn(driver, [`--port=${port}`], { stdio: 'ignore' });
await sleep(1500);
const base = `http://127.0.0.1:${port}`;
const sess = await (await fetch(`${base}/session`, { method: 'POST', body: JSON.stringify({ capabilities: { alwaysMatch: {
  webSocketUrl: true, 'goog:chromeOptions': { binary: chrome, args: ['--headless=new', '--no-sandbox', `--user-data-dir=${profile}`] } } } }) })).json();
const bidi = await connect(sess.value.capabilities.webSocketUrl);
const events = [];
bidi.onEvent((m) => { if (m.type === 'event') events.push(m.method + ' ' + JSON.stringify(m.params.text ?? m.params.url ?? '')); });
const r = {};
r.status = (await bidi.send('session.status')).result;
await bidi.send('session.subscribe', { events: ['log.entryAdded', 'browsingContext.load'] });
const tree = (await bidi.send('browsingContext.getTree')).result; const ctx = tree.contexts[0].context; r.contexts = tree.contexts.length;
r.navigate = (await bidi.send('browsingContext.navigate', { context: ctx, url: 'data:text/html,<h1 id=x>hi</h1><script>console.log("from page")</script>', wait: 'complete' })).type;
r.eval = (await bidi.send('script.evaluate', { expression: '[1+2, document.querySelector("#x").textContent]', target: { context: ctx }, awaitPromise: false })).result?.result;
r.call = (await bidi.send('script.callFunction', { functionDeclaration: '(a, b) => ({sum: a + b})', arguments: [{ type: 'number', value: 2 }, { type: 'number', value: 5 }], target: { context: ctx }, awaitPromise: false })).result?.result;
r.node = (await bidi.send('browsingContext.locateNodes', { context: ctx, locator: { type: 'css', value: 'h1' } })).result?.nodes?.length;
r.shot = ((await bidi.send('browsingContext.captureScreenshot', { context: ctx })).result?.data ?? '').length > 1000;
r.newTab = (await bidi.send('browsingContext.create', { type: 'tab' })).type;
r.err = (await bidi.send('script.evaluate', { expression: 'throw new Error("boom")', target: { context: ctx }, awaitPromise: false })).result?.exceptionDetails?.text;
await sleep(500);
r.events = events;
console.log(JSON.stringify(r, null, 1));
await fetch(`${base}/session/${sess.value.sessionId}`, { method: 'DELETE' });
bidi.close(); cd.kill(); rmSync(profile, { recursive: true, force: true }); process.exit(0);
