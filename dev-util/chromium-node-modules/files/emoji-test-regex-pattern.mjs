// emoji-test-regex-pattern's dist/latest/javascript.txt, without its PHP regexp builder:
// the sequences of Unicode's emoji-test.txt plus the package's EXTRA_SEQUENCES
// (script/get-sequences.js), as a trie of UTF-16 code units. Like the original, it
// matches the longest sequence at each position.
// Usage: node emoji-test-regex-pattern.mjs emoji-test.txt get-sequences.js > javascript.txt
import fs from 'fs';
const [testFile, getSequences] = process.argv.slice(2);
const seqs = new Set();
for (const line of fs.readFileSync(testFile, 'utf8').split('\n')) {
  const m = /^([0-9A-F ]+);/.exec(line);
  if (m) seqs.add(String.fromCodePoint(...m[1].trim().split(/\s+/).map(h => parseInt(h, 16))));
}
const src = fs.readFileSync(getSequences, 'utf8');
const extra = new Function(`return ${/const EXTRA_SEQUENCES = (\[[\s\S]*?\n\]);/.exec(src)[1]}`)();
for (const s of extra) seqs.add(s);

const root = new Map();
for (const s of seqs) {
  let node = root;
  for (const unit of s) {
    // code units, as the pattern is used without the u flag
    for (let i = 0; i < unit.length; i++) {
      const c = unit[i];
      if (!node.has(c)) node.set(c, new Map());
      node = node.get(c);
    }
  }
  node.set('', null); // end of a sequence
}
const esc = c => {
  const n = c.charCodeAt(0);
  if (/[0-9A-Za-z]/.test(c)) return c;
  if (c === '#' || c === '*') return c === '*' ? '\\*' : '#';
  return n < 0x100 ? '\\x' + n.toString(16).toUpperCase().padStart(2, '0') : '\\u' + n.toString(16).toUpperCase().padStart(4, '0');
};
const classOf = cs => {
  // character class with ranges
  const ns = cs.map(c => c.charCodeAt(0)).sort((a, b) => a - b);
  let out = '', i = 0;
  while (i < ns.length) {
    let j = i;
    while (j + 1 < ns.length && ns[j + 1] === ns[j] + 1) j++;
    const a = esc(String.fromCharCode(ns[i])), b = esc(String.fromCharCode(ns[j]));
    out += j === i ? a : j === i + 1 ? a + b : `${a}-${b}`;
    i = j + 1;
  }
  return ns.length === 1 ? out : `[${out}]`;
};
const memo = new Map();
const emit = node => {
  // alternatives for the rest of the sequence; '' ends it
  const end = node.has('');
  const groups = new Map(); // same continuation => one character class
  for (const [c, child] of node) {
    if (c === '') continue;
    const rest = emit(child);
    if (!groups.has(rest)) groups.set(rest, []);
    groups.get(rest).push(c);
  }
  const alts = [...groups].map(([rest, cs]) => classOf(cs) + rest).sort();
  if (!alts.length) return '';
  const body = alts.length === 1 ? alts[0] : `(?:${alts.join('|')})`;
  if (!end) return body;
  // greedy: prefer the longer sequence
  return (alts.length === 1 && /^(\\x..|\\u....|[^\\[(])$/.test(body)) ? body + '?' : (alts.length === 1 ? `(?:${body})?` : body + '?');
};
let pattern = emit(root);
if (pattern.startsWith('(?:') && pattern.endsWith(')')) {
  // top level: plain alternation
  let depth = 0, top = true;
  for (let i = 0; i < pattern.length - 1; i++) {
    if (pattern[i] === '\\') { i++; continue; }
    if (pattern[i] === '[') { while (pattern[i] !== ']') { if (pattern[i] === '\\') i++; i++; } continue; }
    if (pattern[i] === '(') depth++;
    if (pattern[i] === ')') { depth--; if (depth === 0) { top = false; break; } }
  }
  if (top) pattern = pattern.slice(3, -1);
}
process.stdout.write(pattern + '\n');
