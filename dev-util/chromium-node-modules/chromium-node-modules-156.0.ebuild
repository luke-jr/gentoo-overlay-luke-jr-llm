# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# The npm packages in Chromium's tarball are as npm publishes them: the files
# the build uses are often generated (transpiled from TypeScript, bundled with
# their dependencies, minified). This builds such files from their sources (the
# packages' git tags), as self-contained bundles made with esbuild, and installs
# each at the path of the file it replaces in Chromium's tree
# (/usr/lib/chromium-node-modules/SLOT/third_party/...). The Chromium ebuild
# copies them over the originals, after checking the npm packages' versions
# (VERSIONS). The packages these bundles include are then unused, and deleted.
#
# Slotted by Chromium's major version, whose npm package versions this follows.

# Sources: id, GitHub repository, tag (or commit).
JS_SOURCES=(
	# terser/dist/bundle.min.js
	"terser terser/terser v5.37.0"
	"gen-mapping jridgewell/gen-mapping v0.3.3"
	"resolve-uri jridgewell/resolve-uri v3.1.1"
	"set-array jridgewell/set-array v1.1.2"
	"source-map jridgewell/source-map v0.3.5"
	"sourcemap-codec-1.4.15 jridgewell/sourcemap-codec v1.4.15"
	"trace-mapping jridgewell/trace-mapping v0.3.19"
	# chromium-bidi: @rollup/plugin-node-resolve
	"node-resolve rollup/plugins node-resolve-v16.0.3"
	"pluginutils rollup/plugins pluginutils-v5.3.0"
	"deepmerge TehShrike/deepmerge v4.3.1"
	"is-mergeable-object TehShrike/is-mergeable-object v1.1.0"
	"is-module component/is-module 1.0.0"
	"resolve browserify/resolve v1.22.11"
	"is-core-module inspect-js/is-core-module v2.16.1"
	"hasown inspect-js/hasOwn v2.0.2"
	"function-bind Raynos/function-bind v1.1.2"
	"path-parse jbgutierrez/path-parse v1.0.7"
	"supports-preserve-symlinks-flag inspect-js/node-supports-preserve-symlinks-flag v1.0.0"
	"estree-walker-2 Rich-Harris/estree-walker v2.0.2"
	"picomatch-4 micromatch/picomatch 4.0.4"
	# chromium-bidi: rollup-plugin-cleanup
	"rollup-plugin-cleanup aMarCruz/rollup-plugin-cleanup 3.2.1"
	"js-cleanup aMarCruz/js-cleanup 1.2.0"
	"rollup-pluginutils rollup/rollup-pluginutils 2.8.2"
	"estree-walker-0 Rich-Harris/estree-walker v0.6.1"
	"micromatch micromatch/micromatch 4.0.2"
	"braces micromatch/braces 3.0.2"
	# 7.0.1 isn't tagged; npm's gitHead for it
	"fill-range jonschlinkert/fill-range 39f421b499d5c97b62e955c179fa34c062aab2a5"
	"to-regex-range micromatch/to-regex-range 5.0.1"
	"is-number jonschlinkert/is-number 7.0.0"
	"picomatch-2 micromatch/picomatch 2.0.7"
	"magic-string-0.25 Rich-Harris/magic-string v0.25.9"
	"sourcemap-codec-1.4.8 Rich-Harris/sourcemap-codec v1.4.8"
	"perf-regexes aMarCruz/perf-regexes 1.0.1"
	"skip-regex aMarCruz/skip-regex 1.0.2"
	# chromium-bidi: rollup-plugin-license
	"rollup-plugin-license mjeanroy/rollup-plugin-license v3.7.1"
	"commenting 3rd-Eden/commenting 1.1.0"
	"fdir thecodrr/fdir v6.5.0"
	"lodash lodash/lodash 4.18.1"
	"magic-string-0.30 Rich-Harris/magic-string v0.30.21"
	"sourcemap-codec-1.5.5 jridgewell/sourcemaps sourcemap-codec/1.5.5"
	"moment moment/moment 2.30.1"
	"package-name-regex dword-design/package-name-regex v2.0.6"
	"spdx-expression-validate kemitchell/spdx-expression-validate.js v2.0.0"
	"spdx-satisfies kemitchell/spdx-satisfies.js v5.0.1"
	"spdx-compare kemitchell/spdx-compare.js v1.0.0"
	"spdx-expression-parse jslicense/spdx-expression-parse.js v3.0.1"
	"spdx-ranges kemitchell/spdx-ranges.js v2.1.1"
	"spdx-license-ids jslicense/spdx-license-ids v3.0.22"
	"spdx-exceptions kemitchell/spdx-exceptions.json v2.5.0"
	"array-find-index sindresorhus/array-find-index v1.0.2"
	# WebUI's CSS minifier: postcss-selector-parser
	"postcss-selector-parser postcss/postcss-selector-parser v6.1.2"
	"cssesc mathiasbynens/cssesc v3.0.0"
	"regenerate mathiasbynens/regenerate v1.4.2"
	"util-deprecate TooTallNate/util-deprecate 1.0.2"
	# ts-proto (protoc plugin generating TypeScript); untagged ones by npm's gitHead
	"ts-proto stephenh/ts-proto v2.7.7"
	"ts-proto-descriptors stephenh/ts-proto f828a779495538cdd5719d23d28d6697d86bdeb3"
	"ts-poet stephenh/ts-poet bda410a132645d243090bdd01cdb6559e4964ab2"
	"case-anything mesqueeb/case-anything 4ff82505a22d1f71fc2528ed8f9a5691ca1d0511"
	"bufbuild-protobuf bufbuild/protobuf-es v2.2.5"
	# DevTools: CSS minification (cssnano) and SVG optimization (svgo)
	"entities fb55/entities v4.5.0"
	"domelementtype fb55/domelementtype v2.3.0"
	"domhandler fb55/domhandler v5.0.3"
	"dom-serializer cheeriojs/dom-serializer v2.0.0"
	"domutils fb55/domutils v3.2.2"
	"nth-check fb55/nth-check v2.1.1"
	"css-what fb55/css-what v7.0.0"
	"css-select fb55/css-select v6.0.0"
	"css-tokenizer csstools/postcss-plugins 9256e22798ff1360e178912af9b57d59d0601c99"
	"baseline-browser-mapping web-platform-dx/baseline-browser-mapping v2.11.21"
	"caniuse-api MoOx/caniuse-api 4.0.0"
	"postcss-selector-parser-7 postcss/postcss-selector-parser 7.1.6"
	"nanoid ai/nanoid 3.3.18"
	"colordx dkryaklin/colordx @colordx/core@6.4.0"
	# DevTools: build scripts (yargs, ...), esbuild's JavaScript API
	"yargs yargs/yargs v18.1.0"
	"y18n yargs/y18n v5.0.5"
	"cliui yargs/cliui v9.0.1"
	"yargs-parser-22 yargs/yargs-parser yargs-parser-v22.0.0"
	"escalade lukeed/escalade v3.2.0"
	"get-caller-file stefanpenner/get-caller-file v2.0.5"
	"js-yaml nodeca/js-yaml 5.4.1"
	"uuid uuidjs/uuid v14.0.0"
	"esbuild evanw/esbuild v0.28.2"
	# WebUI's lit (3.3.0, lit-html 3.3.0, lit-element 4.2.0, @lit/reactive-element 2.1.0,
	# one commit), built with its rollup-common.js: rollup-plugin-terser's terser and
	# the rollup plugins that change the output
	"lit lit/lit eb71041517fe054b736823bd8cec5f0c8835e54c"
	"terser-5.34 terser/terser v5.34.1"
	"plugin-replace rollup/plugins replace-v5.0.7"
	"plugin-virtual rollup/plugins virtual-v3.0.2"
	"pluginutils-5.1 rollup/plugins pluginutils-v5.1.0"
	"magic-string-0.30.7 Rich-Harris/magic-string v0.30.7"
	"picomatch-2.3 micromatch/picomatch 2.3.1"
)

inherit edo

DESCRIPTION="Generated files of Chromium's npm packages, built from source"
HOMEPAGE="https://www.chromium.org/"

# _js_source <spec>: sets src_id, src_repo, src_ref, src_distfile and src_dir
# (GitHub's archive directory: repository name, then the tag without a leading
# "v" and with "/" and "@" as "-", or the commit).
_js_source() {
	read -r src_id src_repo src_ref <<< "${1}"
	local ref=${src_ref//[\/@]/-}
	src_distfile="${src_repo//\//-}-${ref}.gh.tar.gz"
	[[ ${ref} =~ ^v[0-9] ]] && ref=${ref#v}
	src_dir="${src_repo##*/}-${ref}"
}
SRC_URI=""
for _spec in "${JS_SOURCES[@]}"; do
	_js_source "${_spec}"
	if [[ ${src_ref} =~ ^[0-9a-f]{40}$ ]]; then
		SRC_URI+=" https://github.com/${src_repo}/archive/${src_ref}.tar.gz -> ${src_distfile}"
	else
		SRC_URI+=" https://github.com/${src_repo}/archive/refs/tags/${src_ref}.tar.gz -> ${src_distfile}"
	fi
done
unset _spec src_id src_repo src_ref src_distfile src_dir
S="${WORKDIR}"

LICENSE="Apache-2.0 BSD-2 ISC MIT"
# spdx-license-ids, spdx-exceptions (data)
LICENSE+=" CC-BY-3.0 CC0-1.0"
SLOT="${PV%%.*}"
KEYWORDS="~amd64 ~arm64"
IUSE="test"
RESTRICT="!test? ( test )"

BDEPEND="
	dev-lang/typescript:6.0.2
	dev-util/rollup:4.21.0
	dev-libs/protobuf
	dev-util/esbuild
	net-libs/nodejs
"

# npm packages whose files are replaced, as installed in VERSIONS.
REPLACED_PACKAGES=(
	"third_party/node/node_modules/terser 5.37.0"
	"third_party/node/node_modules/postcss-selector-parser 6.1.2"
	"third_party/chromium-bidi/node_modules/@rollup/plugin-node-resolve 16.0.3"
	"third_party/chromium-bidi/node_modules/rollup-plugin-cleanup 3.2.1"
	"third_party/chromium-bidi/node_modules/rollup-plugin-license 3.7.1"
	"third_party/node/node_modules/ts-proto 2.7.7"
	"third_party/node/node_modules/@bufbuild/protobuf 2.2.5"
	"third_party/node/node_modules/lit 3.3.0"
	"third_party/node/node_modules/lit-html 3.3.0"
	"third_party/node/node_modules/lit-element 4.2.0"
	"third_party/node/node_modules/@lit/reactive-element 2.1.0"
	"third_party/devtools-frontend/src/node_modules/entities 4.5.0"
	"third_party/devtools-frontend/src/node_modules/domelementtype 2.3.0"
	"third_party/devtools-frontend/src/node_modules/domhandler 5.0.3"
	"third_party/devtools-frontend/src/node_modules/dom-serializer 2.0.0"
	"third_party/devtools-frontend/src/node_modules/domutils 3.2.2"
	"third_party/devtools-frontend/src/node_modules/nth-check 2.1.1"
	"third_party/devtools-frontend/src/node_modules/css-what 7.0.0"
	"third_party/devtools-frontend/src/node_modules/css-select 6.0.0"
	"third_party/devtools-frontend/src/node_modules/@csstools/css-tokenizer 4.0.0"
	"third_party/devtools-frontend/src/node_modules/baseline-browser-mapping 2.11.21"
	"third_party/devtools-frontend/src/node_modules/caniuse-api 4.0.0"
	"third_party/devtools-frontend/src/node_modules/postcss-selector-parser 7.1.6"
	"third_party/devtools-frontend/src/node_modules/nanoid 3.3.18"
	"third_party/devtools-frontend/src/node_modules/@colordx/core 6.4.0"
	"third_party/devtools-frontend/src/node_modules/cssesc 3.0.0"
	"third_party/devtools-frontend/src/node_modules/yargs 18.1.0"
	"third_party/devtools-frontend/src/node_modules/y18n 5.0.5"
	"third_party/devtools-frontend/src/node_modules/yargs/node_modules/cliui 9.0.1"
	"third_party/devtools-frontend/src/node_modules/yargs/node_modules/yargs-parser 22.0.0"
	"third_party/devtools-frontend/src/node_modules/escalade 3.2.0"
	"third_party/devtools-frontend/src/node_modules/get-caller-file 2.0.5"
	"third_party/devtools-frontend/src/node_modules/js-yaml 5.4.1"
	"third_party/devtools-frontend/src/node_modules/uuid 14.0.0"
	"third_party/devtools-frontend/src/node_modules/esbuild 0.28.2"
)

# _dir <id>: the unpacked directory of a source
_dir() {
	local spec src_id src_repo src_ref src_distfile src_dir
	for spec in "${JS_SOURCES[@]}"; do
		_js_source "${spec}"
		if [[ ${src_id} == "${1}" ]]; then
			[[ -d ${WORKDIR}/${src_dir} ]] || die "${src_dir} not found"
			echo "${WORKDIR}/${src_dir}"
			return
		fi
	done
	die "unknown source ${1}"
}

# _bundle <format> <output> <entry> [<npm package>=<source id>[:<path>]]...
# Bundles <entry> (<source id>:<path>) with esbuild, resolving the given npm
# packages to source paths (or an absolute path; "external" leaves the import
# as it is), into ${WORKDIR}/image/<output> (or <output>, if absolute).
# Arguments starting with "--" are passed to esbuild. Formats: esm, cjs,
# and cjs-default (module.exports is the entry's default export, as with
# rollup's "exports: default").
_bundle() {
	local format=${1} output=${2} entry=${3}
	shift 3
	entry="$(_dir "${entry%%:*}")/${entry#*:}"
	[[ ${output} == /* ]] || output="${WORKDIR}/image/${output}"
	local args=(
		--bundle --platform=node --target=node18 --log-level=warning
		--outfile="${output}" --define:DEBUG=false
	)
	case ${format} in
		esm)
			# CommonJS dependencies require() Node.js modules
			args+=( --format=esm --banner:js="import { createRequire as __createRequire } from 'module'; const require = __createRequire(import.meta.url);" )
			;;
		cjs) args+=( --format=cjs ) ;;
		cjs-default)
			local shim="${T}/${output//\//_}.shim.cjs"
			echo "module.exports = require('${entry}').default;" > "${shim}" || die
			entry=${shim}
			args+=( --format=cjs )
			;;
		*) die "unknown format ${format}" ;;
	esac
	local alias target
	for alias; do
		if [[ ${alias} == --* ]]; then
			args+=( "${alias}" )
			continue
		fi
		target=${alias#*=}
		if [[ ${target} == external ]]; then
			args+=( --external:"${alias%%=*}" )
		elif [[ ${target} == /* ]]; then
			args+=( --alias:"${alias%%=*}=${target}" )
		elif [[ ${target} == *:* ]]; then
			args+=( --alias:"${alias%%=*}=$(_dir "${target%%:*}")/${target#*:}" )
		else
			args+=( --alias:"${alias%%=*}=$(_dir "${target}")" )
		fi
	done
	edo "${ESBUILD}" "${entry}" "${args[@]}"
}

# _split <output dir> <source id>:<base dir> <entry>... [-- <esbuild arg>...]
# Bundles the entries (relative to the base directory) as ES modules sharing
# chunks, into ${WORKDIR}/image/<output dir> (paths below the base kept). All
# npm imports stay external: they resolve in Chromium's tree as before.
_split() {
	local out=${1} base="$(_dir "${2%%:*}")/${2#*:}"
	shift 2
	local entries=()
	while [[ ${#} -gt 0 && ${1} != -- ]]; do
		entries+=( "${base}/${1}" )
		shift
	done
	[[ ${1} == -- ]] && shift
	edo "${ESBUILD}" "${entries[@]}" --bundle --splitting --format=esm --platform=node --target=node18 \
		--packages=external --log-level=warning --outbase="${base}" --outdir="${WORKDIR}/image/${out}" "${@}"
}

src_compile() {
	local ESBUILD
	ESBUILD=$(best_version -b dev-util/esbuild) || die "dev-util/esbuild not found"
	ESBUILD="${BROOT}/usr/bin/esbuild-$(ver_cut 1-3 "${ESBUILD#dev-util/esbuild-}")"

	local bidi=third_party/chromium-bidi/node_modules webui=third_party/node/node_modules

	# Terser's library bundle (upstream: main.js with rollup, UMD), with
	# @jridgewell/source-map included; acorn is only for the CLI's --parse acorn.
	_bundle cjs ${webui}/terser/dist/bundle.min.js terser:main.js \
		@jridgewell/source-map=source-map:src/source-map.ts \
		@jridgewell/gen-mapping=gen-mapping:src/gen-mapping.ts \
		@jridgewell/trace-mapping=trace-mapping:src/trace-mapping.ts \
		@jridgewell/set-array=set-array:src/set-array.ts \
		@jridgewell/resolve-uri=resolve-uri:src/resolve-uri.ts \
		@jridgewell/sourcemap-codec=sourcemap-codec-1.4.15:src/sourcemap-codec.ts \
		acorn=external

	# chromium-bidi's rollup plugins (its rollup.config.mjs imports these).
	_bundle esm ${bidi}/@rollup/plugin-node-resolve/dist/es/index.js \
		node-resolve:packages/node-resolve/src/index.js \
		@rollup/pluginutils=pluginutils:packages/pluginutils/src/index.ts \
		deepmerge=deepmerge:index.js \
		is-mergeable-object=is-mergeable-object:index.js \
		is-module=is-module:index.js \
		resolve=resolve \
		is-core-module=is-core-module:index.js \
		hasown=hasown:index.js \
		function-bind=function-bind:index.js \
		path-parse=path-parse:index.js \
		supports-preserve-symlinks-flag=supports-preserve-symlinks-flag:index.js \
		estree-walker=estree-walker-2:src/index.js \
		picomatch=picomatch-4
	_bundle cjs-default ${bidi}/rollup-plugin-cleanup/dist/rollup-plugin-cleanup.js \
		rollup-plugin-cleanup:src/index.js \
		js-cleanup=js-cleanup:src/index.ts \
		rollup-pluginutils=rollup-pluginutils:src/index.ts \
		estree-walker=estree-walker-0:src/estree-walker.js \
		micromatch=micromatch:index.js \
		braces=braces:index.js \
		fill-range=fill-range:index.js \
		to-regex-range=to-regex-range:index.js \
		is-number=is-number:index.js \
		picomatch=picomatch-2 \
		magic-string=magic-string-0.25:src/index.js \
		sourcemap-codec=sourcemap-codec-1.4.8:src/sourcemap-codec.ts \
		perf-regexes=perf-regexes:src/index.js \
		skip-regex=skip-regex:src/skip-regex.js
	_bundle cjs-default ${bidi}/rollup-plugin-license/dist/index.js \
		rollup-plugin-license:src/index.js \
		commenting=commenting:index.js \
		fdir=fdir:src/index.ts \
		lodash=lodash:lodash.js \
		magic-string=magic-string-0.30:src/index.js \
		@jridgewell/sourcemap-codec=sourcemap-codec-1.5.5:packages/sourcemap-codec/src/sourcemap-codec.ts \
		moment=moment:src/moment.js \
		package-name-regex=package-name-regex:src/index.js \
		spdx-expression-validate=spdx-expression-validate:index.js \
		spdx-satisfies=spdx-satisfies:index.js \
		spdx-compare=spdx-compare:index.js \
		spdx-expression-parse=spdx-expression-parse \
		spdx-ranges=spdx-ranges:index.json \
		spdx-license-ids=spdx-license-ids \
		spdx-exceptions=spdx-exceptions:index.json \
		array-find-index=array-find-index:index.js

	# WebUI's CSS minifier: postcss-selector-parser, with cssesc.js made from
	# its template as upstream's Gruntfile does (minus the Babel step to ES5).
	local cssesc
	cssesc=$(_dir cssesc) || die
	mkdir -p "${T}/node_modules" || die
	ln -s "$(_dir regenerate)" "${T}/node_modules/regenerate" || die
	pushd "${cssesc}" >/dev/null || die
	NODE_PATH="${T}/node_modules" edo node -e '
		const fs = require("fs");
		const data = require("./src/data.js");
		const out = fs.readFileSync("src/cssesc.js", "utf8").replace(/<%= (\w+) %>/g, (m, k) => {
			if (!(k in data)) throw new Error("unknown template variable " + k);
			return data[k];
		});
		fs.writeFileSync(process.argv[1], out);
	' "${T}/cssesc.js"
	popd >/dev/null || die
	_bundle cjs-default ${webui}/postcss-selector-parser/dist/index.js \
		postcss-selector-parser:src/index.js \
		cssesc="${T}/cssesc.js" \
		util-deprecate=util-deprecate:node.js

	# ts-proto's plugin. ts-proto-descriptors (ts-proto's TypeScript for protoc's
	# plugin messages) is ts-proto's own output, committed to git: build the plugin
	# with the committed copy, regenerate the descriptors with it (as its
	# protos/build.sh does), and build the plugin with those, checking that it
	# regenerates them identically. dprint-node, a native formatter, is left out
	# like Chromium's patches/ts_poet.patch does (ts-poet then doesn't format). The
	# plugin reads ts-proto's package.json at run time (../../package.json).
	mkdir -p "${T}/ts-poet" || die
	ln -s "$(_dir ts-poet)/src" "${T}/ts-poet/build" || die
	echo '{"name": "ts-poet", "main": "build/index.ts"}' > "${T}/ts-poet/package.json" || die
	echo 'module.exports = { default: { format() { throw new Error("dprint is not available"); } } };' \
		> "${T}/dprint-node.js" || die
	_ts_proto() {
		_bundle cjs "${1}" ts-proto:src/plugin.ts \
			--supported:dynamic-import=false \
			../../package.json=external ../package.json=external \
			ts-poet="${T}/ts-poet" \
			dprint-node="${T}/dprint-node.js" \
			case-anything=case-anything:src/index.ts \
			ts-proto-descriptors="${2}" \
			@bufbuild/protobuf=bufbuild-protobuf:packages/protobuf/src
	}
	_ts_proto_descriptors() {
		local plugin=${1} out=${2}
		mkdir -p "${plugin}"/build/src "${out}" || die
		cp "$(_dir ts-proto)"/package.json "${plugin}"/ || die
		printf '#!/bin/sh\nexec node "%s/build/src/plugin.js"\n' "${plugin}" > "${plugin}"/protoc-gen-ts_proto || die
		chmod +x "${plugin}"/protoc-gen-ts_proto || die
		pushd "$(_dir ts-proto-descriptors)/protos" >/dev/null || die
		edo protoc --plugin=protoc-gen-ts_proto="${plugin}"/protoc-gen-ts_proto --ts_proto_out="${out}" \
			--ts_proto_opt=esModuleInterop=true,useExactTypes=false,initializeFieldsAsUndefined=false,exportCommonSymbols=false,unknownFields=true,usePrototypeForDefaults=true,outputExtensions=true,disableProto2Optionals=true \
			google/protobuf/descriptor.proto google/protobuf/compiler/plugin.proto
		cp index.ts "${out}"/ || die
		popd >/dev/null || die
	}
	_ts_proto "${T}/stage1/build/src/plugin.js" "$(_dir ts-proto-descriptors)/protos/index.ts"
	_ts_proto_descriptors "${T}/stage1" "${T}/descriptors1"
	_ts_proto ${webui}/ts-proto/build/src/plugin.js "${T}/descriptors1/index.ts"
	mkdir -p "${T}/stage2/build/src" || die
	cp "${WORKDIR}/image/${webui}/ts-proto/build/src/plugin.js" "${T}/stage2/build/src/" || die
	_ts_proto_descriptors "${T}/stage2" "${T}/descriptors2"
	diff -r "${T}/descriptors1" "${T}/descriptors2" ||
		die "ts-proto doesn't regenerate its descriptors identically"

	# @bufbuild/protobuf's ES modules, which chrome://traces-internals bundles: its
	# build:esm is plain tsc. TypeScript 6 needs these flags for its TypeScript 5
	# configuration; type-checking (against newer lib*.d.ts) doesn't affect the output.
	pushd "$(_dir bufbuild-protobuf)/packages/protobuf" >/dev/null || die
	edo "${BROOT}/usr/bin/tsc-6.0.2" --project tsconfig.json --rootDir src \
		--ignoreDeprecations 6.0 --noCheck \
		--outDir "${WORKDIR}/image/${webui}/@bufbuild/protobuf/dist/esm"
	popd >/dev/null || die

	# WebUI's lit: compile each package (tsc --build: development/), then run its
	# rollup.config.js (../../rollup-common.js: minified files with a shared terser
	# name cache). The rollup plugins it imports: rollup-plugin-terser (in process,
	# files/), @rollup/plugin-replace and -virtual from source; the others (size
	# summary, test copies, source maps, the Node build's DOM shim and its bundled
	# polyfill-support) don't change the files Chromium uses, and are no-ops. The
	# result is byte-identical to npm's (Chromium's lit_html.patch is applied by
	# the Chromium ebuild).
	local lit
	lit=$(_dir lit) || die
	local nm="${lit}/node_modules"
	mkdir -p "${nm}"/terser "${nm}"/rollup-plugin-terser "${nm}"/@rollup || die
	_bundle cjs "${nm}/terser/index.js" terser-5.34:main.js acorn=external \
		@jridgewell/source-map=source-map:src/source-map.ts \
		@jridgewell/gen-mapping=gen-mapping:src/gen-mapping.ts \
		@jridgewell/trace-mapping=trace-mapping:src/trace-mapping.ts \
		@jridgewell/set-array=set-array:src/set-array.ts \
		@jridgewell/resolve-uri=resolve-uri:src/resolve-uri.ts \
		@jridgewell/sourcemap-codec=sourcemap-codec-1.4.15:src/sourcemap-codec.ts
	cp "${FILESDIR}"/rollup-plugin-terser-7.0.2.js "${nm}"/rollup-plugin-terser/index.js || die
	_bundle esm "${nm}/@rollup/plugin-replace/index.js" plugin-replace:packages/replace/src/index.js \
		@rollup/pluginutils=pluginutils-5.1:packages/pluginutils/src/index.ts \
		estree-walker=estree-walker-2:src/index.js picomatch=picomatch-2.3 \
		magic-string=magic-string-0.30.7:src/index.js \
		@jridgewell/sourcemap-codec=sourcemap-codec-1.4.15:src/sourcemap-codec.ts
	_bundle esm "${nm}/@rollup/plugin-virtual/index.js" plugin-virtual:packages/virtual/src/index.ts
	local stub
	for stub in \
		"rollup-plugin-summary:export function summary() { return { name: 'summary' }; }" \
		"rollup-plugin-copy:export default function copy() { return { name: 'copy' }; }" \
		"rollup-plugin-sourcemaps:export default function sourcemaps() { return { name: 'sourcemaps' }; }" \
		"@rollup/plugin-node-resolve:export default function nodeResolve() { return { name: 'node-resolve' }; }" \
		"@rollup/plugin-inject:export default function inject() { return { name: 'inject' }; }"
	do
		mkdir -p "${nm}/${stub%%:*}" || die
		echo "${stub#*:}" > "${nm}/${stub%%:*}/index.js" || die
	done
	local d
	for d in rollup-plugin-terser rollup-plugin-summary rollup-plugin-copy rollup-plugin-sourcemaps \
		@rollup/plugin-replace @rollup/plugin-virtual @rollup/plugin-node-resolve @rollup/plugin-inject; do
		echo '{"type": "module", "main": "index.js"}' > "${nm}/${d}/package.json" || die
	done
	echo '{"main": "index.js"}' > "${nm}/terser/package.json" || die
	local p f
	local -A lit_files=(
		[reactive-element]="@lit/reactive-element:css-tag.js reactive-element.js"
		[lit-html]="lit-html:async-directive.js directive-helpers.js directive.js directives/repeat.js is-server.js lit-html.js"
		[lit-element]="lit-element:lit-element.js"
		[lit]="lit:directives/repeat.js index.js"
	)
	for p in reactive-element lit-html lit-element lit; do
		pushd "${lit}/packages/${p}" >/dev/null || die
		# (types: test-only type packages; --noCheck: TypeScript 6 for its TypeScript 5 config)
		echo '{"extends": "./tsconfig.json", "compilerOptions": {"types": []}}' > tsconfig.gentoo.json || die
		edo "${BROOT}/usr/bin/tsc-6.0.2" -p tsconfig.gentoo.json --noCheck --ignoreDeprecations 6.0
		if [[ -f tsconfig.polyfill-support.json ]]; then
			echo '{"extends": "./tsconfig.polyfill-support.json", "compilerOptions": {"types": []}}' \
				> tsconfig.ps-gentoo.json || die
			edo "${BROOT}/usr/bin/tsc-6.0.2" -p tsconfig.ps-gentoo.json --noCheck --ignoreDeprecations 6.0
		fi
		edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" -c rollup.config.js --silent
		local dest
		for f in ${lit_files[${p}]#*:}; do
			dest="${WORKDIR}/image/${webui}/${lit_files[${p}]%%:*}/${f}"
			mkdir -p "${dest%/*}" || die
			cp "${f}" "${dest}" || die
		done
		popd >/dev/null || die
	done

	# DevTools: the generated npm packages its CSS minification (cssnano) and SVG
	# optimization (svgo) use, each replaced in place, its npm imports resolving
	# in the tree as before.
	local dt=third_party/devtools-frontend/src/node_modules
	# entities' decoding tables are generated by its scripts; regenerate them and
	# check them against the committed ones.
	local entities
	entities=$(_dir entities) || die
	cp -r "${entities}"/src/generated "${T}"/entities-generated || die
	local script
	for script in write-decode-map write-encode-map; do
		edo "${ESBUILD}" "${entities}/scripts/${script}.ts" --bundle --platform=node --format=cjs \
			--log-level=warning --outfile="${entities}/scripts/${script}.cjs"
		edo node "${entities}/scripts/${script}.cjs"
	done
	diff -r "${T}"/entities-generated "${entities}"/src/generated ||
		die "entities' scripts don't regenerate its tables identically"
	_bundle esm ${dt}/entities/lib/esm/index.js entities:src/index.ts
	_bundle esm ${dt}/domelementtype/lib/esm/index.js domelementtype:src/index.ts
	_bundle esm ${dt}/domhandler/lib/esm/index.js domhandler:src/index.ts --packages=external
	_bundle esm ${dt}/dom-serializer/lib/esm/index.js dom-serializer:src/index.ts --packages=external
	_bundle esm ${dt}/domutils/lib/esm/index.js domutils:src/index.ts --packages=external
	_bundle esm ${dt}/nth-check/lib/esm/index.js nth-check:src/index.ts --packages=external
	_bundle esm ${dt}/css-what/dist/esm/index.js css-what:src/index.ts
	_bundle esm ${dt}/css-select/dist/esm/index.js css-select:src/index.ts --packages=external
	_bundle esm ${dt}/@csstools/css-tokenizer/dist/index.mjs css-tokenizer:packages/css-tokenizer/src/index.ts
	_bundle cjs ${dt}/baseline-browser-mapping/dist/index.cjs baseline-browser-mapping:src/index.ts
	_bundle cjs ${dt}/caniuse-api/dist/index.js caniuse-api:src/index.ts --packages=external
	_bundle cjs-default ${dt}/postcss-selector-parser/dist/index.js postcss-selector-parser-7:src/index.js \
		cssesc="${T}/cssesc.js" \
		util-deprecate=util-deprecate:node.js
	# postcss-minify-selectors uses cssesc itself
	_copy_file() { mkdir -p "${WORKDIR}/image/${2%/*}" && cp "${1}" "${WORKDIR}/image/${2}" || die; }
	_copy_file "${T}/cssesc.js" ${dt}/cssesc/cssesc.js
	# npm's copy is git's hand-written file with its comments stripped
	_copy_file "$(_dir nanoid)/non-secure/index.cjs" ${dt}/nanoid/non-secure/index.cjs
	# Entry points sharing chunks, like its tsup build
	_split ${dt}/@colordx/core/dist colordx:src index.ts plugins/hwb.ts plugins/minify.ts plugins/names.ts -- \
		--platform=neutral --target=es2022 --out-extension:.js=.mjs

	# DevTools' build scripts. yargs, y18n and cliui are hand-written module
	# wrappers (kept) around their compiled TypeScript in build/lib.
	_split ${dt}/yargs/build/lib yargs:lib yargs-factory.ts utils/apply-extends.ts utils/process-argv.ts
	_split ${dt}/y18n/build/lib y18n:lib index.ts platform-shims/node.ts
	_split ${dt}/yargs/node_modules/cliui/build/lib cliui:lib index.ts
	_split ${dt}/yargs/node_modules/yargs-parser/build/lib yargs-parser-22:lib index.ts
	_bundle esm ${dt}/escalade/sync/index.mjs escalade:src/sync.js --packages=external
	edo "${ESBUILD}" "$(_dir get-caller-file)/index.ts" --format=cjs --platform=node --target=node18 \
		--log-level=warning --outfile="${WORKDIR}/image/${dt}/get-caller-file/index.js"
	_bundle esm ${dt}/js-yaml/dist/js-yaml.mjs js-yaml:src/index.ts --packages=external --target=es2015
	# uuid's Node.js build (src/ without the *-browser files)
	_bundle esm ${dt}/uuid/dist-node/index.js uuid:src/index.ts
	# esbuild's JavaScript API, as its scripts/esbuild.js builds lib/main.js
	_bundle cjs ${dt}/esbuild/lib/main.js esbuild:lib/npm/node.ts --target=node10 \
		--define:WASM=false --define:ESBUILD_VERSION=\"0.28.2\" esbuild=external

	local pkg
	for pkg in "${REPLACED_PACKAGES[@]}"; do
		echo "${pkg}" >> "${WORKDIR}/image/VERSIONS" || die
	done
}

src_test() {
	# Upstream's test suites need their dev dependencies; check that every
	# bundle loads and does something.
	local i=${WORKDIR}/image bidi=third_party/chromium-bidi/node_modules webui=third_party/node/node_modules
	local dt=third_party/devtools-frontend/src/node_modules
	cp "${i}/${dt}/uuid/dist-node/index.js" "${T}/uuid.mjs" || die
	# In Chromium's tree, a package.json next to it makes this one ESM.
	cp "${i}/${bidi}/@rollup/plugin-node-resolve/dist/es/index.js" "${T}/node-resolve.mjs" || die
	# rollup-plugin-license reads the package.json of the current directory.
	mkdir "${T}/smoke" || die
	echo '{"name": "smoke", "version": "1.0.0"}' > "${T}/smoke/package.json" || die
	cd "${T}/smoke" || die
	edo node -e '
		const [terser, psp, resolve, cleanup, license] = process.argv.slice(1);
		const assert = require("assert");
		(async () => {
			const t = require(terser);
			assert.equal((await t.minify("function add(first, second) { return first + second; }")).code,
			             "function add(n,d){return n+d}");
			assert.equal(require(psp)().processSync("a  >  b"), "a  >  b");
			const nodeResolve = await import(resolve);
			assert.equal(typeof nodeResolve.nodeResolve().resolveId.handler, "function");
			assert.equal(typeof require(cleanup)().transform, "function");
			assert.equal(typeof require(license)().renderChunk, "function");
			assert.equal((await import(process.argv[6])).load("a: [1, 2]").a[1], 2);
			assert.match((await import(process.argv[7])).v4(), /^[0-9a-f-]{36}$/);
		})().catch((e) => { console.error(e); process.exit(1); });
	' "${i}/${webui}/terser/dist/bundle.min.js" "${i}/${webui}/postcss-selector-parser/dist/index.js" \
		"${T}/node-resolve.mjs" "${i}/${bidi}/rollup-plugin-cleanup/dist/rollup-plugin-cleanup.js" \
		"${i}/${bidi}/rollup-plugin-license/dist/index.js" \
		"${i}/${dt}/js-yaml/dist/js-yaml.mjs" "${T}/uuid.mjs"
}

src_install() {
	insinto "/usr/lib/${PN}/${SLOT}"
	doins -r "${WORKDIR}/image/."
}
