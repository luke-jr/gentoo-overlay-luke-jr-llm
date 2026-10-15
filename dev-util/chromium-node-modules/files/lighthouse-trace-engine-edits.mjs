// Apply to the recovered trace_engine TypeScript the edits DevTools'
// (unpublished) scripts/trace/prep-trace-engine-package.sh makes to the
// compiled package, as seen by diffing @paulirish/trace_engine 0.0.65 against
// its sources:
//  - DevTools' i18n module isn't packaged: UI strings become
//    {i18nId, values} objects, and byte/time formatters {__i18nBytes} /
//    {__i18nMillis} objects, which Lighthouse localizes itself;
//  - modules re-exported by barrel files (extras.ts: FilmStrip,
//    MainThreadActivity) but not packaged are dropped from the barrel.
//
// Usage: node trace-engine-edits.mjs SOURCE_DIR
import fs from 'fs';
import path from 'path';

const dir = process.argv[2];
let edited = 0;

function walk(d) {
  for (const entry of fs.readdirSync(d, {withFileTypes: true})) {
    const full = path.join(d, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (full.endsWith('.ts') && !full.endsWith('.d.ts')) edit(full);
  }
}

function edit(file) {
  const before = fs.readFileSync(file, 'utf8');
  let code = before
    .replace(/^(import \* as i18n from '[./]*core\/i18n\/i18n\.js';)$/m, '// $1')
    .replace(/^(const str_ = i18n\.i18n\.registerUIStrings\(.*\);)$/m, '// $1')
    .replace(/i18n\.i18n\.getLocalizedString\.bind\(undefined, str_\)/g,
      '((i18nId: string, values?: unknown): any => ({i18nId, values}))')
    .replace(/i18n\.ByteUtilities\.bytesToString/g, '((bytes: number): any => ({__i18nBytes: bytes}))')
    .replace(/i18n\.TimeUtilities\.millisToString/g, '((millis: number): any => ({__i18nMillis: millis}))');
  code = code.replace(/^export \* as \w+ from '(\.[^']*)\.js';\n/mg, (line, spec) => {
    const target = path.join(path.dirname(file), spec);
    return fs.existsSync(target + '.ts') || fs.existsSync(target + '.js') ? line : '';
  });
  // The package leaves i18n.i18n.lockedString() calls (in Name.ts, for
  // events Lighthouse doesn't name); anything else is new and needs a look.
  if (/(?<!\.)\bi18n\.(?!i18n\.lockedString\()/.test(code.replace(/\/\*[^]*?\*\/|\/\/.*$/mg, ''))) {
    throw new Error(`${file}: unhandled use of i18n`);
  }
  if (code !== before) {
    fs.writeFileSync(file, code);
    edited++;
  }
}

walk(dir);
console.log(`trace_engine: edited ${edited} files`);
