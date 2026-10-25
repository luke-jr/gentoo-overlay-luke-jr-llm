#!/bin/bash
# Runs the runtime checks against an installed (or just built) Chromium, writing the results to
# OUTDIR. Compare them with the previous version's (e.g. diff -r): see README.md for what may differ.
# Usage: run-all.sh CHROME CHROMEDRIVER OUTDIR
here=$(dirname "$(readlink -f "$0")")
chrome=${1:?chrome}; driver=${2:?chromedriver}; out=${3:?outdir}
mkdir -p "${out}"
"${chrome}" --version > "${out}/version.txt"
run() { local name=$1; shift; echo "### ${name}"; timeout 300 "$@" > "${out}/${name}.json" 2> "${out}/${name}.log" || echo "${name}: FAILED (see ${out}/${name}.log)"; }
run components node "${here}/components.mjs" "${chrome}"
run devtools node "${here}/devtools.mjs" "${chrome}" "${out}/devtools"
run bidi node "${here}/bidi.mjs" "${driver}" "${chrome}"
run webgl node "${here}/webgl.mjs" "${chrome}"
if command -v Xvfb >/dev/null && command -v xdotool >/dev/null && command -v import >/dev/null; then
	echo "### restore-pages"; "${here}/restore-pages.sh" "${chrome}" "${out}/restore-pages"
else
	echo "restore-pages: skipped (needs Xvfb, xdotool and ImageMagick)"
fi
