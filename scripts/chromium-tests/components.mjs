// Lists the components registered at startup (chrome://components) and whether the ones that
// would download executable code are there.
// Usage: node components.mjs CHROME [SECONDS-TO-WAIT]
import { launch, connect, newTab, sleep } from './common.mjs';
const [chrome, wait = '15'] = process.argv.slice(2);
const browser = await launch(chrome, ['about:blank']);
await sleep(Number(wait) * 1000); // let startup registration happen
const cdp = await connect((await newTab(browser, 'chrome://components')).webSocketDebuggerUrl);
await sleep(3000);
const r = await cdp.send('Runtime.evaluate', { returnByValue: true, expression: `(() => {
  const walk = (n) => { let s = ''; for (const c of n.querySelectorAll('*')) if (c.shadowRoot) s += walk(c.shadowRoot);
    return s + (n.innerText || n.textContent || ''); };
  return walk(document.body ?? document); })()` });
const text = r.result.result.value || '';
const names = [...new Set(text.split('\n').map((l) => l.trim())
  .filter((l) => l && !/^(Version|Status|Check for update|Component|Components)/.test(l)))];
console.log(JSON.stringify({ screenAI: /screen ?ai/i.test(text), commerce: /commerce/i.test(text), widevine: /widevine/i.test(text),
  lines: names }, null, 1));
cdp.close(); await browser.close(); process.exit(0);
