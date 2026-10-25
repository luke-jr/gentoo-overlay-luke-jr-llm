// Opens DevTools' front-end on a test page and checks it: the panels open, the libraries DevTools
// vendors (built from source by this overlay) work, and no exceptions or console errors come up.
// Screenshots of the panels go to OUTDIR.
// Usage: node devtools.mjs CHROME OUTDIR
import { mkdirSync, writeFileSync } from 'fs';
import { launch, connect, sleep } from './common.mjs';
const [chrome, out] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const browser = await launch(chrome, ['--window-size=1400,900',
  'data:text/html,<title>t</title><h1 id=x>hello</h1><script>console.log("page log")</script>']);
const list = await (await fetch(`${browser.base}/json/list`)).json();
const page = list.find((t) => t.type === 'page');
const host = browser.base.replace('http://', '');
const url = `${browser.base}/devtools/inspector.html?ws=${host}/devtools/page/${page.id}`;
const dt = await (await fetch(`${browser.base}/json/new?${encodeURIComponent(url)}`, { method: 'PUT' })).json();
const cdp = await connect(dt.webSocketDebuggerUrl);
const problems = [];
cdp.onEvent((m) => {
  if (m.method === 'Runtime.exceptionThrown') problems.push('exception: ' + (m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text).split('\n')[0]);
  if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') problems.push('console.error: ' + m.params.args.map((a) => a.value ?? a.description).join(' ').slice(0, 200));
  if (m.method === 'Log.entryAdded' && m.params.entry.level === 'error') problems.push('log: ' + m.params.entry.text.slice(0, 200));
});
const send = cdp.send;
await send('Runtime.enable'); await send('Log.enable'); await send('Page.enable');
await send('Page.reload');
await sleep(8000);
const evalJs = async (expr) => (await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })).result?.result?.value;
const deepCount = `(() => { let n = 0; const walk = (r) => { for (const el of r.querySelectorAll('*')) { n++; if (el.shadowRoot) walk(el.shadowRoot); } }; walk(document); return n; })()`;
const deepText = (s) => `(() => { const walk = (r) => { for (const el of r.querySelectorAll('*')) { if (el.shadowRoot) { const t = walk(el.shadowRoot); if (t) return t; } } return r.querySelector(${JSON.stringify(s)}); }; const e = walk(document); return e ? (e.innerText || e.textContent || '').slice(0, 120) : null; })()`;
const result = { elements: await evalJs(deepCount), title: await evalJs('document.title') };
result.elementsTree = await evalJs(deepText('.elements-tree-outline, [role=tree]'));
const shot = async (name) => { const s = await send('Page.captureScreenshot'); writeFileSync(`${out}/${name}.png`, Buffer.from(s.result.data, 'base64')); };
await shot('elements');
// Console panel (Escape drawer / panel switch via the API DevTools exposes for its tests)
for (const panel of ["console", "sources", "chrome-recorder", "lighthouse", "timeline", "network"]) {
  result[panel] = await evalJs(`(async () => { try { const m = await import('./ui/legacy/legacy.js'); await m.ViewManager.ViewManager.instance().showView(${JSON.stringify(panel)}); return 'shown'; } catch (e) { return 'error: ' + e; } })()`);
  await sleep(2500); await shot(panel);
}
result.elementsAfter = await evalJs(deepCount);
result.libs = await evalJs(`(async () => {
  const r = {};
  const t = async (name, f) => { try { r[name] = await f(); } catch (e) { r[name] = 'ERROR ' + e; } };
  await t('acorn', async () => { const a = await import('./third_party/acorn/acorn.js'); return JSON.stringify(a.parse('let a = 1 + 2; class B { #x = 1; static { } }', {ecmaVersion: 'latest'}).body.map(n => n.type)); });
  await t('marked', async () => { const m = await import('./third_party/marked/marked.js'); return JSON.stringify(m.Marked.lexer('# Hi *x*\\n\\n- a\\n- b\\n\\n\`\`\`js\\ncode\\n\`\`\`').map(x => x.type)); });
  await t('json5', async () => { const j = await import('./third_party/json5/json5.js'); return JSON.stringify(j.parse("{a: 1, b: 'x', c: [1,2,], // c\\n}")); });
  await t('intl', async () => { const i = await import('./third_party/intl-messageformat/intl-messageformat.js'); return new i.IntlMessageFormat('{n, plural, one {# item} other {# items}} by {who}', 'en').format({n: 3, who: 'me'}); });
  await t('diff', async () => { const d = await import('./third_party/diff/diff.js'); return JSON.stringify(d.Diff.DiffWrapper.charDiff('the quick brown fox', 'the quack brown box')); });
  await t('wasmparser', async () => { const w = await import('./third_party/wasmparser/wasmparser.js'); const bytes = new Uint8Array([0,97,115,109,1,0,0,0,1,7,1,96,2,127,127,1,127,3,2,1,0,7,7,1,3,97,100,100,0,0,10,9,1,7,0,32,0,32,1,106,11]); const d = new w.WasmDis.WasmDisassembler(); const p = new w.WasmParser.BinaryReader(); p.setData(bytes.buffer, 0, bytes.length); d.disassembleChunk(p); return d.getResult().lines.join('|'); });
  await t('cm', async () => { const cm = await import('./third_party/codemirror.next/codemirror.next.js'); const out = {}; const langs = {js: [cm.javascript.javascript(), 'let x = 1 /* c */'], css: [cm.css.css(), 'a { color: red }'], html: [cm.html.html(), '<p class=x>hi</p>'], py: [(await cm.python()).python(), 'def f(): return 1'], cpp: [(await cm.cpp()).cpp(), 'int main() {}'], md: [(await cm.markdown()).markdown(), '# t'], java: [(await cm.java()).java(), 'class A {}'], xml: [(await cm.xml()).xml(), '<a b="c"/>'], php: [(await cm.php()).php(), '<?php echo 1; ?>'], wast: [(await cm.wast()).wast(), '(module)'], sass: [(await cm.sass()).sass({indented: true}), 'a\\n  b: c'], less: [(await cm.less()).less(), '@x: 1;'], vue: [(await cm.vue()).vue(), '<template><p/></template>'], svelte: [(await cm.svelte()).svelte(), '<p/>'], angular: [(await cm.angular()).angular(), '<p *ngIf=x></p>'], go: [await cm.go(), 'func f() {}'], shell: [await cm.shell(), 'echo $x'], clojure: [await cm.clojure(), '(+ 1 2)']};
      for (const [k, [ext, doc]] of Object.entries(langs)) { const s = cm.EditorState.create({doc, extensions: [ext]}); out[k] = cm.syntaxTree(s).toString().slice(0, 80); }
      const v = new cm.EditorView({doc: 'const a = [1, 2];', extensions: [cm.javascript.javascript(), cm.syntaxHighlighting(cm.defaultHighlightStyle)], parent: document.body}); out.view = v.contentDOM.innerHTML.length; v.destroy(); return JSON.stringify(out); });
  await t('puppeteer', async () => { const p = await import('./third_party/puppeteer/puppeteer.js'); return Object.keys(p).sort().join(','); });
  await t('replay', async () => { const p = await import('./third_party/puppeteer-replay/puppeteer-replay.js'); const rec = p.parse({title: 't', steps: [{type: 'navigate', url: 'https://example.com'}, {type: 'click', selectors: [['#x']], offsetX: 1, offsetY: 1}]}); return (await p.stringify(rec)).length; });
  await t('tpw', async () => { const p = await import('./third_party/third-party-web/third-party-web.js'); return p.ThirdPartyWeb.getEntity('https://www.google-analytics.com/analytics.js')?.name; });
  await t('webvitals', async () => { const p = await import('./third_party/web-vitals/web-vitals.js'); return Object.keys(p).sort().join(','); });
  await t('lit', async () => { const p = await import('./third_party/lit/lit.js'); return Object.keys(p).length; });
  return r; })()`);
result.problems = problems;
console.log(JSON.stringify(result, null, 1));
cdp.close(); await browser.close(); process.exit(0);
