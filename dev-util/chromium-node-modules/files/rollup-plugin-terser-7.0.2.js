// rollup-plugin-terser 7.0.2's terser() plugin, minus jest-worker: it runs terser
// in-process. Upstream serializes the options (and so the shared name cache)
// into a worker as each chunk is rendered, before any worker has returned, then
// merges the cache back; every chunk of an output thus starts from the same
// name cache, which renderStart's snapshot reproduces.
import { createRequire } from 'module';
const { minify } = createRequire(import.meta.url)('terser');

export function terser(userOptions = {}) {
  if (userOptions.sourceMap != null) {
    throw Error('sourceMap option is removed, use sourcemap instead');
  }
  let snapshot;
  return {
    name: 'terser',
    renderStart() {
      snapshot = structuredClone(userOptions);
    },
    async renderChunk(code, chunk, outputOptions) {
      const defaultOptions = {
        sourceMap: outputOptions.sourcemap === true || typeof outputOptions.sourcemap === 'string',
      };
      if (outputOptions.format === 'es' || outputOptions.format === 'esm') defaultOptions.module = true;
      if (outputOptions.format === 'cjs') defaultOptions.toplevel = true;
      const options = structuredClone({ ...defaultOptions, ...snapshot });
      delete options.numWorkers;
      const result = await minify(code, options);
      if (options.nameCache) {
        let { vars, props } = userOptions.nameCache;
        if (vars) {
          const newVars = options.nameCache.vars && options.nameCache.vars.props;
          if (newVars) {
            vars.props = vars.props || {};
            Object.assign(vars.props, newVars);
          }
        }
        if (!props) {
          userOptions.nameCache.props = props = {};
        }
        const newProps = options.nameCache.props && options.nameCache.props.props;
        if (newProps) {
          props.props = props.props || {};
          Object.assign(props.props, newProps);
        }
      }
      return result;
    },
  };
}
