#!/bin/bash
# The "Restore pages?" check (chromium-156-crash-bubble-once.patch): after a crash, the bubble
# offers to restore; once restored, a window opened later (running chrome again) must not offer it
# again. Takes three screenshots in OUTDIR: 1-after-crash.png (bubble shown), 2-after-restore.png
# (the page restored, no bubble), 3-second-window.png (a new window, no bubble).
# Needs Xvfb, xdotool and ImageMagick's import. The Restore button is clicked at a fixed position
# in a 1200x800 window at 0,0; check the screenshots if Chromium's layout changes.
# Usage: restore-pages.sh CHROME OUTDIR
set -u
chrome=${1:?chrome}; out=${2:?outdir}
mkdir -p "${out}"
profile=$(mktemp -d) || exit 1
Xvfb -displayfd 4 -screen 0 1400x900x24 4>"${profile}.display" >/dev/null 2>&1 &
xvfb=$!
for _ in $(seq 50); do [ -s "${profile}.display" ] && break; sleep 0.1; done
export DISPLAY=:$(cat "${profile}.display")
pgid=
cleanup() {
	[ -n "${pgid}" ] && kill -9 -- "-${pgid}" 2>/dev/null
	kill "${xvfb}" 2>/dev/null
	rm -rf "${profile:?}" "${profile:?}.display"
}
trap cleanup EXIT
# Chrome and its helpers in a process group of their own, so they can be killed together.
launch() {
	setsid "${chrome}" --no-sandbox --test-type --no-first-run --user-data-dir="${profile}" \
		--window-size=1200,800 --window-position=0,0 "$@" >/dev/null 2>&1 &
	pgid=$!
	disown
}
shot() { import -window root "${out}/$1.png"; }

# A session to restore, saved to disk; then a crash.
launch "data:text/html,<title>Page one</title><h1>Page one</h1>"
for _ in $(seq 60); do
	grep -q '"exit_type":"Crashed"' "${profile}/Default/Preferences" 2>/dev/null &&
		[ -n "$(ls "${profile}/Default/Sessions/" 2>/dev/null)" ] && break
	sleep 1
done
sleep 5
kill -9 -- "-${pgid}"; sleep 2
launch; sleep 10; shot 1-after-crash
xdotool mousemove 1132 185 click 1; sleep 8; shot 2-after-restore
# A second window through the startup path: the running browser opens it.
timeout 20 "${chrome}" --no-sandbox --test-type --no-first-run --user-data-dir="${profile}" >/dev/null 2>&1
sleep 8; shot 3-second-window
echo "screenshots in ${out}: the bubble must show in 1-after-crash.png only"
