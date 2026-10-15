// @rollup/plugin-terser (which DevTools' front_end/third_party/lit is bundled
// with), running terser in-process instead of in worker threads.
import { createRequire } from 'module';
const { minify } = createRequire(import.meta.url)('terser');

export default function terser(options = {}) {
  return {
    name: 'terser',
    async renderChunk(code, chunk, outputOptions) {
      const defaultOptions = {
        sourceMap: outputOptions.sourcemap === true || typeof outputOptions.sourcemap === 'string',
      };
      if (outputOptions.format === 'es') defaultOptions.module = true;
      if (outputOptions.format === 'cjs') defaultOptions.toplevel = true;
      const result = await minify(code, { ...options, ...defaultOptions });
      return { code: result.code, map: result.map };
    },
  };
}
