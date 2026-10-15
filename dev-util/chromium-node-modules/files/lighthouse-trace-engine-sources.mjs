// Recover the TypeScript sources of the @paulirish/trace_engine npm package.
//
// The package is DevTools' compiled front_end/models/trace (and what it
// imports), published without a repository. Each compiled .js file has a .js.map
// whose sourcesContent holds the one .ts (or .js) file it was compiled from.
// Write those sources to OUT_DIR at the compiled file's path, so they can be
// recompiled; copy the package's other files except compiled output (.js
// without a source map, unless it is a small hand-written shim; .d.ts; maps).
//
// Usage: node trace-engine-sources.mjs PACKAGE_DIR OUT_DIR
import fs from 'fs';
import path from 'path';

const [pkgDir, outDir] = process.argv.slice(2);
const SHIM_MAX_BYTES = 300;
const stats = {sources: 0, shims: 0, other: 0, skipped: []};

function walk(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full);
      continue;
    }
    const rel = path.relative(pkgDir, full);
    const out = path.join(outDir, rel);
    if (rel.endsWith('.map')) continue;
    // Declarations are compiler output, except protocol.d.ts: DevTools generates
    // it from the protocol definition (the package's protocol.js is empty), and
    // its const enums supply values the sources use.
    if (rel.endsWith('.d.ts') && rel !== 'generated/protocol.d.ts') continue;
    if (rel.endsWith('.js')) {
      const mapFile = full + '.map';
      if (fs.existsSync(mapFile)) {
        const map = JSON.parse(fs.readFileSync(mapFile, 'utf8'));
        if (map.sources.length !== 1 || !map.sourcesContent?.[0]) {
          throw new Error(`${rel}: expected one source with content`);
        }
        const ext = path.extname(map.sources[0]);
        fs.mkdirSync(path.dirname(out), {recursive: true});
        fs.writeFileSync(out.replace(/\.js$/, ext), map.sourcesContent[0]);
        stats.sources++;
      } else if (fs.statSync(full).size <= SHIM_MAX_BYTES) {
        fs.mkdirSync(path.dirname(out), {recursive: true});
        fs.copyFileSync(full, out);
        stats.shims++;
      } else {
        stats.skipped.push(rel);
      }
      continue;
    }
    fs.mkdirSync(path.dirname(out), {recursive: true});
    fs.copyFileSync(full, out);
    stats.other++;
  }
}

walk(pkgDir);
console.log(`trace_engine: ${stats.sources} sources from source maps, ${stats.shims} small shims, ` +
  `${stats.other} other files; skipped compiled files without sources: ${stats.skipped.join(' ')}`);
