# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: cargo-stubs.eclass
# @SUPPORTED_EAPIS: 8
# @BLURB: replace crates that are never built on this platform with stubs
# @DESCRIPTION:
# Cargo.lock lists the dependencies of every platform, and cargo wants all of
# them in the vendor directory, including crates that are only built on, say,
# Windows (winapi, windows-targets and its import libraries, ...). Instead of
# fetching those, list them in CARGO_STUB_CRATES (and leave them out of CRATES):
# this eclass puts a stub in their place that has the same name, version,
# checksum, dependencies (from Cargo.lock) and the features that other crates
# ask for, but no code. A stub that does get built fails with compile_error!.
#
# Use scripts/cargo-unused-crates.py from this repository to find candidates.
# The ebuild must set PYTHON_COMPAT, and inherit cargo before this eclass.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_CARGO_STUBS_ECLASS} ]]; then
_CARGO_STUBS_ECLASS=1

if [[ -z ${_CARGO_ECLASS} ]]; then
	die "${ECLASS}: inherit cargo before ${ECLASS}"
fi

inherit python-any-r1

# @ECLASS_VARIABLE: CARGO_STUB_CRATES
# @DEFAULT_UNSET
# @DESCRIPTION:
# Crates to replace with stubs, as name@version (like CRATES).

# @ECLASS_VARIABLE: CARGO_STUB_LOCKFILE
# @DEFAULT_UNSET
# @DESCRIPTION:
# The Cargo.lock that lists the stubbed crates. Cargo.toml files below its
# directory, and those of the vendored crates, are searched for the features
# the stubs need. Defaults to ${S}/Cargo.lock.

# @FUNCTION: cargo-stubs_pkg_setup
# @DESCRIPTION:
# Runs python-any-r1_pkg_setup and rust_pkg_setup.
cargo-stubs_pkg_setup() {
	python-any-r1_pkg_setup
	rust_pkg_setup
}

# @FUNCTION: cargo_stub_crates
# @DESCRIPTION:
# Writes the stubs for CARGO_STUB_CRATES to ${ECARGO_VENDOR}.
cargo_stub_crates() {
	debug-print-function ${FUNCNAME} "$@"

	[[ ${CARGO_STUB_CRATES} ]] || return 0
	local lockfile=${CARGO_STUB_LOCKFILE:-${S}/Cargo.lock}
	einfo "Writing stubs for crates that are not built on this platform"
	"${EPYTHON}" - "${lockfile}" "${ECARGO_VENDOR}" ${CARGO_STUB_CRATES} <<-'PYEOF' || die "writing crate stubs failed"
	import json, os, re, sys, tomllib

	lockfile, vendor, *wanted = sys.argv[1:]
	stubs = {tuple(w.split("@", 1)) for w in wanted}
	lock = [p for p in tomllib.load(open(lockfile, "rb"))["package"]]
	versions = {}
	for p in lock:
	    versions.setdefault(p["name"], []).append(p["version"])

	# Features that any manifest asks of a stubbed crate (by crate name; a
	# stub may declare more features than its real version has, which is harmless).
	stubnames = {n for n, _ in stubs}
	features = {n: set() for n in stubnames}
	manifests = [os.path.join(vendor, d, "Cargo.toml") for d in os.listdir(vendor)]
	for root, dirs, files in os.walk(os.path.dirname(os.path.abspath(lockfile))):
	    dirs[:] = [d for d in dirs if d not in ("target", ".git")]
	    if "Cargo.toml" in files:
	        manifests.append(os.path.join(root, "Cargo.toml"))
	for m in manifests:
	    if not os.path.exists(m):
	        continue
	    toml = tomllib.load(open(m, "rb"))
	    tables = [toml] + list(toml.get("target", {}).values())
	    renamed = {}
	    for t in tables:
	        for kind in ("dependencies", "dev-dependencies", "build-dependencies"):
	            for key, spec in t.get(kind, {}).items():
	                name = spec.get("package", key) if isinstance(spec, dict) else key
	                renamed[key] = name
	                if name in features and isinstance(spec, dict):
	                    features[name].update(spec.get("features", []))
	    for values in toml.get("features", {}).values():
	        for v in values:
	            if "/" in v:
	                dep, feat = v.split("/", 1)
	                dep = renamed.get(dep.rstrip("?"), dep.rstrip("?"))
	                if dep in features:
	                    features[dep].add(feat)

	def q(s):
	    return json.dumps(s)

	for p in lock:
	    key = (p["name"], p["version"])
	    if key not in stubs:
	        continue
	    stubs.discard(key)
	    if "checksum" not in p:
	        sys.exit(f"{p['name']} {p['version']} has no checksum in {lockfile}")
	    d = os.path.join(vendor, f"{p['name']}-{p['version']}")
	    if os.path.exists(d):
	        sys.exit(f"{d} already exists (is {p['name']} in CRATES too?)")
	    os.makedirs(os.path.join(d, "src"))
	    lines = ["[package]", f"name = {q(p['name'])}", f"version = {q(p['version'])}",
	             'edition = "2015"', "", "[lib]", 'path = "src/lib.rs"', "", "[dependencies]"]
	    seen = set()
	    for dep in p.get("dependencies", []):
	        name, *rest = dep.split(" ")
	        ver = rest[0] if rest else versions[name][0]
	        key = name if name not in seen else re.sub(r"\W", "_", f"{name}_{ver}")
	        seen.add(name)
	        lines.append(f"{key} = {{ package = {q(name)}, version = {q('=' + ver)} }}")
	    lines += ["", "[features]"] + [f"{q(f)} = []" for f in sorted(features[p["name"]])]
	    open(os.path.join(d, "Cargo.toml"), "w").write("\n".join(lines) + "\n")
	    open(os.path.join(d, "src", "lib.rs"), "w").write(
	        f'compile_error!("{p["name"]} {p["version"]} is a stub (CARGO_STUB_CRATES), '
	        'but the build needs it");\n')
	    json.dump({"package": p["checksum"], "files": {}},
	              open(os.path.join(d, ".cargo-checksum.json"), "w"))
	    print(f"  {p['name']} {p['version']}", file=sys.stderr)
	if stubs:
	    sys.exit("not in " + lockfile + ": " + " ".join("@".join(s) for s in sorted(stubs)))
	PYEOF
}

# @FUNCTION: cargo-stubs_src_unpack
# @DESCRIPTION:
# Runs cargo_src_unpack, then cargo_stub_crates.
cargo-stubs_src_unpack() {
	cargo_src_unpack
	cargo_stub_crates
}

fi

EXPORT_FUNCTIONS pkg_setup src_unpack
