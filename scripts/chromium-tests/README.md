# Checks for a Chromium build

Run them for every new version, and compare the results with the previous version's.

- **`verify-regenerated.py WORKDIR`** (after `src_compile`): `src_prepare` moves the tarball's
  checked-in generated files aside (to `${WORKDIR}/upstream-generated`); this checks that the build
  made every one of them again, and how many came out identical. A handful are never made again
  because nothing uses them (stale upstream copies); they are listed by name, and should be the same
  kinds each time.
- **`run-all.sh CHROME CHROMEDRIVER OUTDIR`** (the installed browser, e.g.
  `/usr/lib64/chromium-browser/chrome`): runs the runtime checks below and writes their results to
  `OUTDIR`.
  - `components.mjs`: the components registered at startup (`chrome://components`). Screen AI,
    Commerce Heuristics and Widevine must not be there (they would download code).
  - `devtools.mjs`: DevTools' front-end on a test page: the panels open, and the libraries it vendors
    (rebuilt from source here: acorn, marked, CodeMirror, Puppeteer, Lighthouse, lit, …) work.
    Screenshots of the panels go to `OUTDIR/devtools`.
  - `bidi.mjs`: WebDriver BiDi through chromedriver's chromium-bidi mapper (also rebuilt here).
  - `webgl.mjs`: WebGL 2 on ANGLE's Vulkan back-end over SwiftShader, through ANGLE's internal shaders
    (which the ebuild compiles with the system glslang): pixel hashes per operation.
  - `restore-pages.sh`: the "Restore pages?" bubble after a crash must not come back in a window
    opened later (`chromium-156-crash-bubble-once.patch`); three screenshots to look at. Needs Xvfb,
    xdotool and ImageMagick.

Needs Node 22 or later. The browser runs headless, with a temporary profile, without the sandbox
(so it also works in a container).

**What may differ between versions:** DevTools' element count; its two console messages (a 404,
and "CodeMirror plugin crashed: … reading 'scope'"), which every 156 and 157 build here has shown;
component versions (data components update); the components list when upstream adds or drops a data
component. **What must not:** the BiDi results, the WebGL hashes (unless ANGLE's shaders or SwiftShader
changed), and the absence of the code-downloading components.
