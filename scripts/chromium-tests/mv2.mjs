// Manifest V2 extensions (chromium-157-manifest-v2-features.patch): loads a minimal MV2 extension
// (--load-extension) that cancels requests to URLs containing "blocked" with blocking webRequest,
// and reports whether it runs (its background page) and whether it blocks: by default, Chromium
// refuses it (both false); with --disable-features=ExtensionManifestV2Disabled, both must be true.
// Usage: node mv2.mjs CHROME
import { createServer } from 'http';
import { mkdtempSync, rmSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { connect, launch, newTab, sleep } from './common.mjs';

const chrome = process.argv[2];
const ext = mkdtempSync(join(tmpdir(), 'chromium-mv2-'));
writeFileSync(join(ext, 'manifest.json'), JSON.stringify({
  manifest_version: 2, name: 'mv2-test', version: '1.0',
  permissions: ['webRequest', 'webRequestBlocking', '<all_urls>'],
  background: { scripts: ['bg.js'], persistent: true },
}));
writeFileSync(join(ext, 'bg.js'),
  "chrome.webRequest.onBeforeRequest.addListener(() => ({ cancel: true }), " +
  "{ urls: ['*://127.0.0.1/*blocked*'] }, ['blocking']);\n");

const server = createServer((req, res) => { res.setHeader('Content-Type', 'text/html'); res.end('<p>ok</p>'); });
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const origin = `http://127.0.0.1:${server.address().port}`;

async function check(extraArgs) {
const browser = await launch(chrome, [`--load-extension=${ext}`, ...extraArgs]);
const result = { backgroundPage: false, blocked: null, allowedLoads: null };
try {
  // The extension's background page shows up as a DevTools target when it runs.
  for (let i = 0; i < 50 && !result.backgroundPage; i++) {
    const targets = await (await fetch(`${browser.base}/json/list`)).json();
    result.backgroundPage = targets.some((t) => t.type === 'background_page' && t.title === 'mv2-test');
    if (!result.backgroundPage) await sleep(200);
  }
  const tab = await newTab(browser, `${origin}/page`);
  const cdp = await connect(tab.webSocketDebuggerUrl);
  await sleep(1000);
  const probe = async (path) => (await cdp.send('Runtime.evaluate', {
    expression: `fetch(${JSON.stringify(origin + path)}).then(r => r.ok, () => false)`, awaitPromise: true,
  })).result.result.value;
  result.allowedLoads = await probe('/allowed');
  result.blocked = !(await probe('/blocked'));
  cdp.close();
} finally {
  await browser.close();
}
return result;
}

try {
  console.log(JSON.stringify({
    default: await check([]),
    mv2Enabled: await check(['--disable-features=ExtensionManifestV2Disabled']),
  }, null, 2));
} finally {
  server.close();
  rmSync(ext, { recursive: true, force: true });
}
