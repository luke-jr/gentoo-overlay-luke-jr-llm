// Compile TypeScript files with tsc's emitter, as one program, keeping the
// directory layout. Type errors are counted but don't stop emit: the type
// declarations of dependencies (@types/*, other packages) aren't installed,
// and emit doesn't depend on them, except for const enums and type-only
// re-exports, which the program resolves from the sources it has.
//
// Usage: [ES_MODULE_INTEROP=1] [DECLARATION=1 [DECLARATION_DIR=DIR]] [TSC_LOG=FILE] \
//   node ts-transpile.cjs TYPESCRIPT_JS commonjs|esnext TARGET OUT_DIR FILE...
// FILEs are relative to the current directory; X.ts is written to OUT_DIR/X.js.
'use strict';

const fs = require('fs');
const path = require('path');

const [tsPath, moduleKind, target, outDir, ...files] = process.argv.slice(2);
const ts = require(tsPath);

const commonjs = moduleKind === 'commonjs';
const options = {
  module: commonjs ? ts.ModuleKind.CommonJS : ts.ModuleKind.ESNext,
  moduleResolution: commonjs ? ts.ModuleResolutionKind.Node10 : ts.ModuleResolutionKind.Bundler,
  ignoreDeprecations: '6.0',
  target: ts.ScriptTarget[target],
  lib: ['lib.esnext.d.ts', 'lib.dom.d.ts'],
  types: [],
  esModuleInterop: process.env.ES_MODULE_INTEROP === '1',
  experimentalDecorators: true,
  resolveJsonModule: true,
  declaration: process.env.DECLARATION === '1',
  declarationDir: process.env.DECLARATION_DIR || undefined,
  skipLibCheck: true,
  noEmitOnError: false,
  rootDir: '.',
  outDir,
};

const program = ts.createProgram(files, options);
const result = program.emit();
const errors = ts.getPreEmitDiagnostics(program).concat(result.diagnostics)
  .filter(d => d.category === ts.DiagnosticCategory.Error);
for (const file of files) {
  const out = path.join(outDir, file.replace(/\.[cm]?ts$/, '.js'));
  if (!file.endsWith('.d.ts') && !fs.existsSync(out)) {
    console.error(`not emitted: ${out}`);
    process.exitCode = 1;
  }
}
if (errors.length) {
  const log = process.env.TSC_LOG || '/dev/null';
  fs.writeFileSync(log, ts.formatDiagnostics(errors, {
    getCanonicalFileName: f => f, getCurrentDirectory: () => process.cwd(), getNewLine: () => '\n',
  }));
  console.log(`  tsc: ${files.length} files, ${errors.length} type errors ignored (${log})`);
}
