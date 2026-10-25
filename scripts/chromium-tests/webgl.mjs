// WebGL 2 through ANGLE's Vulkan back-end on SwiftShader: operations that use ANGLE's internal
// shaders (clears, blits, resolves, mipmap generation, format conversions, copies), with a hash
// of the pixels each reads back, a sample of them, and any GL error. Compare the output between
// builds: the hashes only change when ANGLE's shaders or SwiftShader behave differently.
// Usage: node webgl.mjs CHROME
import { launch, connect, newTab } from './common.mjs';
const [chrome] = process.argv.slice(2);
const browser = await launch(chrome, ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--use-vulkan=swiftshader', 'about:blank']);
const cdp = await connect((await newTab(browser, 'about:blank')).webSocketDebuggerUrl);
const test = `(() => {
  const out = { hashes: {}, samples: {}, errors: {} };
  const c = document.createElement('canvas'); c.width = c.height = 64;
  const gl = c.getContext('webgl2', { antialias: false, preserveDrawingBuffer: true });
  if (!gl) return { error: 'no webgl2' };
  const dbg = gl.getExtension('WEBGL_debug_renderer_info');
  out.renderer = dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
  const hash = (a) => { let h = 2166136261; for (const v of a) { h ^= v; h = Math.imul(h, 16777619) >>> 0; } return h.toString(16); };
  const check = (name) => { const e = gl.getError(); if (e) out.errors[name] = e; };
  const read = (name, w, h) => { check(name + ':before');
    const p = new Uint8Array(w * h * 4); gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, p); check(name);
    out.hashes[name] = hash(p);
    const m = (h >> 1) * w * 4 + (w >> 1) * 4;
    out.samples[name] = [...p.slice(0, 4), '|', ...p.slice(m, m + 4)].join(','); };
  const shader = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) out.errors.compile = gl.getShaderInfoLog(s); return s; };
  const p = gl.createProgram();
  gl.attachShader(p, shader(gl.VERTEX_SHADER, '#version 300 es\\nlayout(location = 0) in vec2 a; out vec2 v; void main() { v = a; gl_Position = vec4(a, 0, 1); }'));
  gl.attachShader(p, shader(gl.FRAGMENT_SHADER, '#version 300 es\\nprecision highp float; in vec2 v; uniform sampler2D t; uniform int m; out vec4 o; void main() { o = m == 0 ? vec4(v * 0.5 + 0.5, 0.25, 1) : texture(t, v * 0.5 + 0.5); }'));
  gl.linkProgram(p); if (!gl.getProgramParameter(p, gl.LINK_STATUS)) out.errors.link = gl.getProgramInfoLog(p);
  gl.useProgram(p); const mode = gl.getUniformLocation(p, 'm');
  const b = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, b);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
  const fbo = (w, h, samples) => { const f = gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER, f);
    if (samples) { const r = gl.createRenderbuffer(); gl.bindRenderbuffer(gl.RENDERBUFFER, r);
      gl.renderbufferStorageMultisample(gl.RENDERBUFFER, samples, gl.RGBA8, w, h);
      gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.RENDERBUFFER, r); return f; }
    const x = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, x); gl.texStorage2D(gl.TEXTURE_2D, 1, gl.RGBA8, w, h);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, x, 0);
    gl.bindTexture(gl.TEXTURE_2D, null); return f; };  // no feedback loop through the sampler
  // A scissored clear (ANGLE's clear shader), then a draw.
  const A = fbo(64, 64); gl.viewport(0, 0, 64, 64); gl.clearColor(0.2, 0.4, 0.6, 1); gl.clear(gl.COLOR_BUFFER_BIT);
  gl.enable(gl.SCISSOR_TEST); gl.scissor(8, 8, 16, 16); gl.clearColor(1, 0, 0.5, 1); gl.clear(gl.COLOR_BUFFER_BIT);
  gl.disable(gl.SCISSOR_TEST); read('clear', 64, 64);
  gl.bindFramebuffer(gl.FRAMEBUFFER, A); gl.uniform1i(mode, 0); gl.drawArrays(gl.TRIANGLES, 0, 3); read('draw', 64, 64);
  // A scaled, flipped, filtered blit (ANGLE's blit shader).
  const B = fbo(32, 48); gl.bindFramebuffer(gl.READ_FRAMEBUFFER, A); gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, B);
  gl.blitFramebuffer(0, 0, 64, 64, 32, 0, 0, 48, gl.COLOR_BUFFER_BIT, gl.LINEAR);
  gl.bindFramebuffer(gl.FRAMEBUFFER, B); read('blit', 32, 48);
  // A multisampled draw, resolved.
  const M = fbo(64, 64, 4); gl.viewport(0, 0, 64, 64); gl.drawArrays(gl.TRIANGLES, 0, 3);
  const R = fbo(64, 64); gl.bindFramebuffer(gl.READ_FRAMEBUFFER, M); gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, R);
  gl.blitFramebuffer(0, 0, 64, 64, 0, 0, 64, 64, gl.COLOR_BUFFER_BIT, gl.NEAREST);
  gl.bindFramebuffer(gl.FRAMEBUFFER, R); read('resolve', 64, 64);
  // Uploads that need converting, sampled by a draw.
  const bytes = (n) => Uint8Array.from({ length: n }, (_, i) => (i * 37) & 255);
  const conv = (name, internal, format, type, data) => { const x = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, x);
    gl.texImage2D(gl.TEXTURE_2D, 0, internal, 4, 4, 0, format, type, data);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    fbo(16, 16); gl.viewport(0, 0, 16, 16); gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, x);
    gl.uniform1i(mode, 1); gl.drawArrays(gl.TRIANGLES, 0, 3); read(name, 16, 16); };
  conv('rgb8', gl.RGB8, gl.RGB, gl.UNSIGNED_BYTE, bytes(48));
  conv('luminanceAlpha', gl.LUMINANCE_ALPHA, gl.LUMINANCE_ALPHA, gl.UNSIGNED_BYTE, bytes(32));
  conv('rgb565', gl.RGB565, gl.RGB, gl.UNSIGNED_SHORT_5_6_5, Uint16Array.from({ length: 16 }, (_, i) => (i * 4099) & 65535));
  conv('half', gl.RGBA16F, gl.RGBA, gl.HALF_FLOAT, Uint16Array.from({ length: 64 }, (_, i) => 0x3000 + i * 97));
  // Mipmap generation, read back from level 2.
  const T = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, T);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, 32, 32, 0, gl.RGBA, gl.UNSIGNED_BYTE, bytes(4096)); gl.generateMipmap(gl.TEXTURE_2D);
  const MF = gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER, MF);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, T, 2); read('mipmap', 8, 8);
  // copyTexImage2D from the drawn image, read back.
  gl.bindFramebuffer(gl.FRAMEBUFFER, A); const CT = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, CT);
  gl.copyTexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, 4, 4, 32, 32, 0); check('copyTexImage2D');
  const CF = gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER, CF);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, CT, 0); read('copy', 32, 32);
  return out;
})()`;
const r = await cdp.send('Runtime.evaluate', { expression: test, returnByValue: true });
console.log(JSON.stringify(r.result.result.value ?? r.result, null, 1));
cdp.close(); await browser.close(); process.exit(0);
