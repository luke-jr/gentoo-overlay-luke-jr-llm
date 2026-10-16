// Set up the sources of the @paulirish/trace_engine npm package for recompiling.
//
// The package is DevTools' compiled front_end/models/trace (and what it
// imports), published without a repository. Each compiled .js file has a .js.map
// naming the one front_end/ source file it was compiled from, with that file's
// text in sourcesContent.
//
// copy PACKAGE_DIR OUT_DIR: write those source files, from the source maps, to
// OUT_DIR at the compiled file's path; copy the package's other files except
// compiled output (.js without a source map, unless it is a small hand-written
// shim; .d.ts; maps).
//
// verify PACKAGE_DIR FRONT_END: check that the sources in the source maps are
// DevTools' files in FRONT_END: a checkout of the commit the package was
// compiled from, with lighthouse-trace-engine-<version>-packaging.patch (the
// edits DevTools' unpublished packaging script makes to the sources) applied.
// For updating to a new package version; the build doesn't need it.
import fs from 'fs';
import path from 'path';

const [mode, pkgDir, ...rest] = process.argv.slice(2);
const SHIM_MAX_BYTES = 300;
const stats = {sources: 0, shims: 0, other: 0, skipped: [], differ: [], missing: []};

function sourceOf(mapFile, rel) {
  const map = JSON.parse(fs.readFileSync(mapFile, 'utf8'));
  const m = map.sources.length === 1 && /(?:^|\/)front_end\/(.+)$/.exec(map.sources[0]);
  if (!m || typeof map.sourcesContent?.[0] !== 'string') {
    throw new Error(`${rel}: expected one front_end/ source with content`);
  }
  return {path: m[1], content: map.sourcesContent[0]};
}

function walk(dir, visit) {
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, visit);
    else visit(full, path.relative(pkgDir, full));
  }
}

if (mode === 'copy') {
  const [outDir] = rest;
  walk(pkgDir, (full, rel) => {
    const out = path.join(outDir, rel);
    // Declarations are compiler output (generated/protocol.d.ts is made from
    // DevTools' generated/protocol.ts).
    if (rel.endsWith('.map') || rel.endsWith('.d.ts')) return;
    fs.mkdirSync(path.dirname(out), {recursive: true});
    if (rel.endsWith('.js')) {
      if (fs.existsSync(full + '.map')) {
        const src = sourceOf(full + '.map', rel);
        if (path.extname(src.path) !== '.ts' || src.path.replace(/\.ts$/, '.js') !== rel) {
          throw new Error(`${rel}: unexpected source ${src.path}`);
        }
        fs.writeFileSync(path.join(outDir, src.path), src.content);
        stats.sources++;
      } else if (fs.statSync(full).size <= SHIM_MAX_BYTES) {
        fs.copyFileSync(full, out);
        stats.shims++;
      } else {
        stats.skipped.push(rel);
      }
      return;
    }
    fs.copyFileSync(full, out);
    stats.other++;
  });
  console.log(`trace_engine: ${stats.sources} sources from its source maps, ${stats.shims} small shims, ` +
    `${stats.other} other files; skipped compiled files without sources: ${stats.skipped.join(' ') || 'none'}`);
} else if (mode === 'verify') {
  const [frontEnd] = rest;
  walk(pkgDir, (full, rel) => {
    if (!rel.endsWith('.js.map')) return;
    const src = sourceOf(full, rel);
    stats.sources++;
    const file = path.join(frontEnd, src.path);
    if (!fs.existsSync(file)) stats.missing.push(src.path);
    else if (fs.readFileSync(file, 'utf8') !== src.content) stats.differ.push(src.path);
  });
  if (stats.differ.length || stats.missing.length) {
    console.error(`trace_engine: sources differ from ${frontEnd}: ${stats.differ.join(' ') || 'none'}; ` +
      `missing there: ${stats.missing.join(' ') || 'none'}`);
    process.exit(1);
  }
  console.log(`trace_engine: all ${stats.sources} sources in the source maps are ${frontEnd}'s`);
} else {
  console.error('usage: lighthouse-trace-engine-sources.mjs copy PACKAGE_DIR OUT_DIR | verify PACKAGE_DIR FRONT_END');
  process.exit(1);
}
