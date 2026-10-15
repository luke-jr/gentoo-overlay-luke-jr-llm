// emoji-test-regex-pattern's dist/latest/javascript.txt, without its PHP regexp builder:
// the sequences of Unicode's emoji-test.txt plus the package's EXTRA_SEQUENCES
// (script/get-sequences.js), as a trie of UTF-16 code units (the pattern is used
// without the u flag) with common prefixes and suffixes factored out. Like the
// original, it matches the longest sequence at each position.
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

// trie of code units; '' marks the end of a sequence
const root = new Map();
for (const s of seqs) {
  let node = root;
  for (let i = 0; i < s.length; i++) {
    if (!node.has(s[i])) node.set(s[i], new Map());
    node = node.get(s[i]);
  }
  node.set('', null);
}

// Expressions: an alternation {alts: [sequence], opt}, matching one of alts (or
// nothing, if opt); a sequence is an array of atoms; an atom is a set of code units
// {set: [numbers]} or a group {group: alternation}.
const esc = n => {
  const c = String.fromCharCode(n);
  if (/[0-9A-Za-z#]/.test(c)) return c;
  if (c === '*') return '\\*';
  return n < 0x100 ? '\\x' + n.toString(16).toUpperCase().padStart(2, '0') : '\\u' + n.toString(16).toUpperCase().padStart(4, '0');
};
const setStr = ns => {
  let out = '', i = 0;
  while (i < ns.length) {
    let j = i;
    while (j + 1 < ns.length && ns[j + 1] === ns[j] + 1) j++;
    out += j === i ? esc(ns[i]) : j === i + 1 ? esc(ns[i]) + esc(ns[j]) : `${esc(ns[i])}-${esc(ns[j])}`;
    i = j + 1;
  }
  return ns.length === 1 ? out : `[${out}]`;
};
const altStr = (e, top) => {
  // (?:(?:a|b))? is (?:a|b)?
  if (e.alts.length === 1 && e.alts[0].length === 1 && e.alts[0][0].group && !e.alts[0][0].group.opt)
    return altStr({ alts: e.alts[0][0].group.alts, opt: e.opt }, top);
  const nullable = s => s.every(a => a.group && a.group.opt);
  const body = [...e.alts.filter(s => !nullable(s)).map(seqStr).sort(), ...e.alts.filter(nullable).map(seqStr)].join('|');
  if (top) return body;
  const single = e.alts.length === 1 && e.alts[0].length === 1 && !e.alts[0][0].group;
  if (single) return body + (e.opt ? '?' : '');
  return `(?:${body})` + (e.opt ? '?' : '');
};
const atomStr = a => a.set ? setStr(a.set) :
  !a.group.opt && a.group.alts.length === 1 ? seqStr(a.group.alts[0]) : altStr(a.group, false);
const seqStr = s => s.map(atomStr).join('');

// alternation for a trie node (null: only the end)
const fromNode = node => {
  const alts = [];
  for (const [c, child] of node) {
    if (c === '') continue;
    const rest = fromNode(child);
    alts.push([{ set: [c.charCodeAt(0)] }, ...(rest ? (rest.alts.length === 1 && !rest.opt ? rest.alts[0] : [{ group: rest }]) : [])]);
  }
  return alts.length ? optimize({ alts, opt: node.has('') }) : null;
};

// Factor common suffixes: alternatives ending in the same atom become
// (?:prefixes)atom, and alternatives that differ only in their first code unit
// become one set. The alternatives always start with distinct code units, so the
// order in which they are tried doesn't matter, and (with greedy ?) the longest
// sequence wins, as with the plain trie.
function optimize(e) {
  let changed = true;
  while (changed) {
    changed = false;
    // same rest after a first set => merge the sets
    const byRest = new Map();
    for (const s of e.alts) {
      const key = s[0].set ? seqStr(s.slice(1)) : '\0' + seqStr(s);
      if (!byRest.has(key)) byRest.set(key, []);
      byRest.get(key).push(s);
    }
    if ([...byRest.values()].some(g => g.length > 1)) {
      e.alts = [...byRest.values()].map(g => g.length === 1 ? g[0] :
        [{ set: g.flatMap(s => s[0].set).sort((a, b) => a - b) }, ...g[0].slice(1)]);
      changed = true;
    }
    // same last atom => factor it out
    const byLast = new Map();
    for (const s of e.alts) {
      if (!s.length || s.every(a => a.group && a.group.opt)) { byLast.set(Symbol(), [s]); continue; }
      const key = atomStr(s[s.length - 1]);
      if (!byLast.has(key)) byLast.set(key, []);
      byLast.get(key).push(s);
    }
    const alts = [];
    for (const g of byLast.values()) {
      if (g.length === 1) { alts.push(g[0]); continue; }
      const last = g[0][g[0].length - 1];
      const rest = g.map(s => s.slice(0, -1));
      const prefixes = optimize({ alts: rest.filter(s => s.length), opt: rest.some(s => !s.length) });
      alts.push([...(prefixes.alts.length === 1 && !prefixes.opt ? prefixes.alts[0] : [{ group: prefixes }]), last]);
      changed = true;
    }
    if (changed) e.alts = alts;
    // an optional (?:T|P T?) is P?T?: (the alternative that can match nothing goes last)
    if (e.opt) {
      for (const b of e.alts) {
        const g = b[b.length - 1];
        if (b.length < 2 || !g.group || !g.group.opt || g.group.alts.length !== 1) continue;
        const t = seqStr(g.group.alts[0]);
        const a = e.alts.find(x => x !== b && seqStr(x) === t);
        if (!a) continue;
        const p = b.slice(0, -1);
        const pOpt = { group: { alts: [p], opt: true } };
        e.alts = e.alts.filter(x => x !== a && x !== b);
        e.alts.push([pOpt, g]);
        e.opt = false;
        changed = true;
        break;
      }
    }
  }
  return e;
}
process.stdout.write(altStr(fromNode(root), true) + '\n');
