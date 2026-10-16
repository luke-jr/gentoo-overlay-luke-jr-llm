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
	# DevTools' lit (lit and lit-html; lit-element and @lit/reactive-element)
	"lit-3.3.3 lit/lit 20afabd3c5bfd49fdcdf1b8518e05c7f99a46db6"
	"lit-4.2.2 lit/lit 0fc671bc390cac3b9900fc3616347eeeecd91d5a"
	# DevTools' vendored libraries (front_end/third_party); untagged ones by npm's gitHead
	# or README.chromium's revision
	"acorn acornjs/acorn 610d62d8f9cf44ca0e70c516b40c92452235c81b"
	"codemirror5 codemirror/codemirror5 eac70bb1a31a08201e5705c788cd72e6283958f0"
	"diff-match-patch google/diff-match-patch 0ae308daa77aeddb089cd6b7b0a443fca026266e"
	"formatjs formatjs/formatjs 51a665ca0a7c6129c0c93b6b7837603a8e31caa4"
	"json5 json5/json5 v2.2.3"
	"marked markedjs/marked 0a2cd54cbe91911890e4460ae4fd7b9966e05654"
	"wasmparser wasdk/wasmparser e0a3281fdd678e6e3d5624b6d939bdf7c3d215ad"
	# chromium-bidi's BiDi mapper bundles these
	"zod colinhacks/zod 50606616c0d291caf3210a7521da51271b918333"
	"mitt developit/mitt b240473b5707857ba2c6a8e6d707c28d1e39da49"
	# DevTools' puppeteer-core 25.12.0 and @puppeteer/replay 4.0.2, and the packages
	# puppeteer bundles (versions from its package-lock.json; by npm's gitHead).
	# urlpattern-polyfill 10.1.0's commit was never published: its latest public
	# commit is the change 10.1.0's build shows.
	"puppeteer puppeteer/puppeteer 15684eb7f1adf98c1c0c4a5d23a154b7995e947e"
	"replay puppeteer/replay 23ab6bc760bc6982d0dcbf3f832a2a7d54571f72"
	"parsel LeaVerou/parsel e10f9c11667ee18cd1ab0bf5002becb2fd4d1b6e"
	"rxjs ReactiveX/rxjs e5351d02e225e275ac0e497c7b66eaa5f0c88791"
	"urlpattern-polyfill kenchris/urlpattern-polyfill f147a0f42a94a29ec1dcd229b218f3a700377f91"
	# DevTools' codemirror.next: the packages it bundles (versions from its source maps;
	# npm's gitHead; "haverbeke:" repositories moved from GitHub to code.haverbeke.berlin),
	# and @lezer/generator 1.8.0 to make their parsers from the grammars
	"cm:@codemirror/autocomplete codemirror/autocomplete d0c97d3e8e37cb83c3c854d63f20902d71aac9a1"
	"cm:@codemirror/commands codemirror/commands b6d5695a3bcaf803aa1b077ecf91b2c3269e3596"
	"cm:@codemirror/lang-angular codemirror/lang-angular 9cdc0cdd47229c19c5df1b110270d060c31fbd28"
	"cm:@codemirror/lang-cpp codemirror/lang-cpp 972934ed5620a1d174dda48139c94afed3969dcf"
	"cm:@codemirror/lang-css codemirror/lang-css 8bad51270d44d030f6ca45700ad827839358f518"
	"cm:@codemirror/lang-html codemirror/lang-html c303dc95431a74ae1217730e4161fbb04d5d3973"
	"cm:@codemirror/lang-java codemirror/lang-java c2a19162a37b4155197d192b646a448e0ba1287f"
	"cm:@codemirror/lang-javascript codemirror/lang-javascript 61e1a8af1417f4cfebc9a0a3ab435ad1ffe18b44"
	"cm:@codemirror/lang-less codemirror/lang-less a07c8335e6094ec8ebf297c37d27f1fdbfacfc9c"
	"cm:@codemirror/lang-markdown codemirror/lang-markdown 90283323da269dcbc34a40b4dcab7fa1ab22d777"
	"cm:@codemirror/lang-php codemirror/lang-php 8edb24c525431ff5083bc25ffe4d7a0d0f19ae41"
	"cm:@codemirror/lang-python codemirror/lang-python d87154ec7014063e6c7e0dfe16c2a7be93471114"
	"cm:@codemirror/lang-sass codemirror/lang-sass ecf8367100b898a2ee8b0ba9fdeda787d0acced6"
	"cm:@codemirror/lang-vue codemirror/lang-vue 50efb40d5a538b9397953b4eb51d94d984ab9efa"
	"cm:@codemirror/lang-wast codemirror/lang-wast 3739cffcc59c4c0a443ef78329a2b281fe71ab7c"
	"cm:@codemirror/lang-xml codemirror/lang-xml ec7eeb6dadbf4840c0ecacee09d7377ec4bbd10d"
	"cm:@codemirror/language codemirror/language 241b1de4653131a73d357c45b6b51712176235d4"
	"cm:@codemirror/legacy-modes codemirror/legacy-modes ac35c73bd17e28c0c2515a189ace5139a18e987b"
	"cm:@codemirror/search codemirror/search 7a4a57e52b4af5807d195296c9933c4c7df947f5"
	"cm:@codemirror/state haverbeke:codemirror/state 651084c8a322b3a19b2bb3e00eee7d4a61d641af"
	"cm:@codemirror/view codemirror/view 4ac4cdbf900df11855f269f82a89273380ad25ca"
	"cm:@lezer/common lezer-parser/common 57c12197e2be3736ced20fa05ce6c53af8371324"
	"cm:@lezer/cpp haverbeke:lezer/cpp c6585ded0c374a238e5deb822df848ee145548f6"
	"cm:@lezer/css haverbeke:lezer/css 0cc0383ec2702695dd59026912918925fc917ae5"
	"cm:@lezer/highlight lezer-parser/highlight 95aa69ecd22bfc8b3e1c793610e0d5cda1174e61"
	"cm:@lezer/html lezer-parser/html 2ffc7dd12a206364a9fc549dc65a9f190cb61e29"
	"cm:@lezer/java haverbeke:lezer/java f8302ee35f5c4c7a1a3b63e70c802d977871e9bc"
	"cm:@lezer/javascript lezer-parser/javascript 371ae0e0659c18414a8e079c1eaa4586d400d9f0"
	"cm:@lezer/lr lezer-parser/lr a6c2d2efa31ca5d1cf43fb522e4cfc11bf120838"
	"cm:@lezer/markdown haverbeke:lezer/markdown f847886185e9262235ed3cf35b32bbb31bbe2f6d"
	"cm:@lezer/php haverbeke:lezer/php 5222344cf05e15c86d5bd480e2d523e611a30be5"
	"cm:@lezer/python haverbeke:lezer/python 618b4614b865777a012de28944bae6655383c393"
	"cm:@lezer/sass lezer-parser/sass 40ea285acf39d2db4b29c0ddff9f0e7bdeceb471"
	"cm:@lezer/xml lezer-parser/xml 99f043a01c6a034573cafd47f9cf3338744fea5e"
	"cm:@marijn/find-cluster-break haverbeke:marijn/find-cluster-break 098961685c964055851434a40cbffb815057cc06"
	"cm:@replit/codemirror-indentation-markers replit/codemirror-indentation-markers fee70fd4a6a2d80fbea9f2d6652e685fc215db82"
	"cm:@replit/codemirror-lang-svelte replit/codemirror-lang-svelte 2ebdf38e85eff50caf4e7f852a847210f9237f18"
	"cm:style-mod marijnh/style-mod 1325363c1fbc8490a351425cb0918951a30e7707"
	"cm:w3c-keyname marijnh/w3c-keyname 5ea93b04bb62230c7de4165e3a9b5c840f05cd44"
	"cm:crelt marijnh/crelt 25eabb104d50e160cd4e4acd9eed2eacb32b332b"
	"cm:@lezer/markdown+@lezer/common lezer-parser/common de5f96276a2954c249de1475e8b03f79c20d9ce4"
	"cm:@lezer/generator lezer-parser/generator 5ebf7e208f3c77f05f11ba6719ad819ab78f241c"
	"terser-5.34 terser/terser v5.34.1"
	"plugin-replace rollup/plugins replace-v5.0.7"
	"plugin-virtual rollup/plugins virtual-v3.0.2"
	"pluginutils-5.1 rollup/plugins pluginutils-v5.1.0"
	"magic-string-0.30.7 Rich-Harris/magic-string v0.30.7"
	"picomatch-2.3 micromatch/picomatch 2.3.1"
	# DevTools' Lighthouse 13.5.0 (lighthouse-dt-bundle.js, the report renderer and
	# generator) and legacy-javascript, and the npm packages Lighthouse's build bundles
	# (versions from its yarn.lock; untagged ones by npm's gitHead). acorn, hasown,
	# function-bind, is-core-module, path-parse, supports-preserve-symlinks-flag and
	# sourcemap-codec 1.4.8 are the ones above.
	"lighthouse GoogleChrome/lighthouse cb853a38a6410617518b363590c967b3fe211949"
	"debug debug-js/debug 7e3814cc603bf64fdd69e714e0cf5611ec31f43b"
	"ms vercel/ms 1c6264b795492e8fdecbc82cb8802fcfbfc08d26"
	"jpeg-js eugeneware/jpeg-js 9ccd35fb5f55a6c4f1902ac5b0f270f675750c27"
	"image-ssim darosh/image-ssim-js 13aa263ad13f69cdfaa31c5ff00e1d8eac9dc15b"
	"lighthouse-stack-packs GoogleChrome/lighthouse-stack-packs 0dd6b19c23b2b4de3946bc183f31eb040014c1f0"
	"format-message format-message/format-message v6.2.0"
	"robots-parser samclarke/robots-parser dd032ec3da65e49bf2ba8d7224bd20883ef8ff34"
	"soft-navigation adamraine/lighthouse-plugin-soft-navigation b924172990ad3688da41b8f4cce22ede3c39dce6"
	"resolve-1.22.10 browserify/resolve d1e73275da515a3bc5d0064f15ebf09b3947199b"
	"magic-string-0.27 Rich-Harris/magic-string 69336fccbb46e721d58faa5c7a0d0b7ed6ee09d2"
	"builtin-modules sindresorhus/builtin-modules 0d234f3ad3965c57d8cc5b9ca198c505fe032452"
	"escape-string-regexp sindresorhus/escape-string-regexp 71083e89129bcf72a10656508de5442d3f97966d"
	"lh-fast-memoize formatjs/formatjs @formatjs/fast-memoize@2.2.0"
	"lh-icu-messageformat-parser formatjs/formatjs @formatjs/icu-messageformat-parser@2.6.2"
	"lh-icu-skeleton-parser formatjs/formatjs @formatjs/icu-skeleton-parser@1.6.2"
	"lh-intl-messageformat formatjs/formatjs intl-messageformat@10.5.3"
	"ajv-formats ajv-validator/ajv-formats 1fb3fa7d967f919ff924bb34aef73a2f39ab0de3"
	"ajv ajv-validator/ajv 0fba0b8e649909613cfce0999b149cd08f4a4987"
	"fast-deep-equal epoberezkin/fast-deep-equal d807ffc5013e710deb1c63d463a03f729bcd144d"
	"json-schema-traverse epoberezkin/json-schema-traverse 6b45983cd76270042cc79527da5c8972f13599ec"
	"fast-uri fastify/fast-uri 6f970b2951fd896aa0f3a7ff28eeb6640c137d33"
	"require-from-string floatdrop/require-from-string d1575a49065eb7a49b86b4de963f04f1a14dfd60"
	"csp-evaluator google/csp-evaluator 9189d07a58c40490fd21190541a9fbfd8fc3ad4b"
	"marky nolanlawson/marky 2fb66b09e6b19451fded98754a8a8f0215e15880"
	"speedline paulirish/speedline v1.4.3"
	"tldts remusao/tldts 200a338cf46f31c27ec2ab16914d683041f8e053"
	"third-party-web patrickhulce/third-party-web d60863a2ea913ed26ae0446296a0cb1cc6c71291"
	"lodash-4.17 lodash/lodash 4.17.21"
	"polyfill-node FredKSchott/rollup-plugin-polyfill-node eb507a21ad82236255988548dea6120d7a277de2"
	"buffer-es6 calvinmetcalf/buffer-es6 3173686b2010f64a0f6286b4e1d5c6056d230fd9"
	"process-es6 calvinmetcalf/node-process-es6 6c218e5f68b918226380abec10c08587f240503e"
	"parse5-5 inikulin/parse5 v5.1.0"
	"dot olado/doT 6adbd819970d9093aa2ea24fcf56c7e370d9a468"
	"js-library-detector johnmichel/Library-Detector-for-Chrome e56bea2d4e0bf483a7255e5c51f4407923618f43"
	# axe-core 4.13.0 (Lighthouse inlines axe.min.js), its build tools and the packages it
	# bundles (versions from its pnpm-lock.yaml); emoji-regex's pattern is generated from
	# Unicode's emoji-test.txt (app-i18n/unicode-emoji)
	"axe-core dequelabs/axe-core v4.13.0"
	"clone pvorb/clone 765941803d27761a6008cb1aa32b199f0c42deb2"
	"deque-dot dequelabs/doT 6e4822b49c7f6355225e0d515749b9ab5789bf6f"
	"uglify-js mishoo/UglifyJS 3ea33afc72462a470466473208a33379b7204765"
	"html-entities mdevils/html-entities 58d1635d40d858efd5b6540f7b62c3a382a35bf1"
	"colorjs color-js/color.js 4a13fd3e970b59ca6d7776a586eaeac5a1b10faa"
	"css-selector-parser mdevils/css-selector-parser 5c9657644e340224a646a23eb42848d725d00a7e"
	"emoji-regex mathiasbynens/emoji-regex 70451eae5f7bbb7c211fec0887f88c444cd562a5"
	"emoji-test-regex-pattern mathiasbynens/emoji-test-regex-pattern 05a4771881f9673b7b0b5ded8ca7ecc03244c82a"
	"memoizee medikoo/memoizee 6aa37460d9c996e737cad3f127a7ed1b7af9d168"
	"d medikoo/d b11fe68c318dbb51b817a22a562175b29adf2e1f"
	"es5-ext medikoo/es5-ext f76b03d8c49ce4871f37f428c0e1d3ee6637fcc4"
	"es6-iterator medikoo/es6-iterator ae56bb258cf47c62f9b9a1b4bec29bee0e676fb1"
	"es6-symbol medikoo/es6-symbol c57f8d88070cec913ff4e3e0ed5192b2330373b2"
	"es6-weak-map medikoo/es6-weak-map ac5868ab3b511552dca5fca178b1d118fed93653"
	"esniff medikoo/esniff 8498674e0894acc27e606d6f55e732e628107596"
	"event-emitter medikoo/event-emitter b951397b8f0d55fc7ae8aea7fa7699e48132a53d"
	"ext medikoo/es5-ext 68c26d9918d0d970ca06a0d3912485d73d67e411"
	"is-promise then/is-promise 68d3d6871806162772b33e9629908ded6c8bf0b1"
	"lru-queue medikoo/lru-queue v0.1.0"
	"next-tick medikoo/next-tick ce6c733a67f82ea84ba8f30fc853217da80154e3"
	"timers-ext medikoo/timers-ext 5feea55d9820970daf5cd9c4a874053047940ac3"
	"type medikoo/type 253bf69b979e0f9bfcb2632db61ce7caa853da5f"
	"typedarray es-shims/typedarray bfa163321b8ccab9c5351ff7fa71826a9355614d"
	"weakmap-polyfill polygonplanet/weakmap-polyfill 2f2258b58ca3c73a884cf3b5c9101ad5a66f936d"
	"es6-promise stefanpenner/es6-promise 1e68dce6f674e5613f4a1797aedd55dc70ac1dcb"
	"core-js zloirock/core-js 80adfc415fa74e5e4f6ba2de6425aa577e3ad439"
	# Lighthouse's http-link-header 1.1.1 (its repository is gone; a fork still has the commit)
	"http-link-header xadhoom/node-http-link-header e5a4865982febd8c58307d51920adb15e2227719"
)

PYTHON_COMPAT=( python3_{12..15} )

inherit edo python-any-r1

DESCRIPTION="Generated files of Chromium's npm packages, built from source"
HOMEPAGE="https://www.chromium.org/"

# _js_source <spec>: sets src_id, src_repo, src_ref, src_uri, src_distfile and
# src_dir (GitHub's archive directory: repository name, then the tag without a
# leading "v" and with "/" and "@" as "-", or the commit; Forgejo's: the
# repository name).
_js_source() {
	# Called at global scope (SRC_URI), so no here-string: bash may need a
	# temporary file for it, which the metadata sandbox denies. Fields are
	# separated by single spaces.
	src_id=${1%% *}
	local rest=${1#* }
	src_repo=${rest%% *}
	src_ref=${rest#* }
	local ref=${src_ref//[\/@]/-}
	if [[ ${src_repo} == haverbeke:* ]]; then
		src_repo=${src_repo#haverbeke:}
		src_uri="https://code.haverbeke.berlin/${src_repo}/archive/${src_ref}.tar.gz"
		src_distfile="${src_repo//\//-}-${ref}.tar.gz"
		src_dir="${src_repo##*/}"
		return
	fi
	if [[ ${src_ref} =~ ^[0-9a-f]{40}$ ]]; then
		src_uri="https://github.com/${src_repo}/archive/${src_ref}.tar.gz"
	else
		src_uri="https://github.com/${src_repo}/archive/refs/tags/${src_ref}.tar.gz"
	fi
	src_distfile="${src_repo//\//-}-${ref}.gh.tar.gz"
	[[ ${ref} =~ ^v[0-9] ]] && ref=${ref#v}
	src_dir="${src_repo##*/}-${ref}"
}
SRC_URI=""
for _spec in "${JS_SOURCES[@]}"; do
	_js_source "${_spec}"
	SRC_URI+=" ${src_uri} -> ${src_distfile}"
done
unset _spec src_id src_repo src_ref src_uri src_distfile src_dir
# webdriver-bidi-protocol's type declarations (puppeteer's TypeScript inlines its const
# enums; the package has no JavaScript, and its sources are generated from the WebDriver
# BiDi specification)
SRC_URI+="
	https://registry.npmjs.org/webdriver-bidi-protocol/-/webdriver-bidi-protocol-0.4.3.tgz
"
# DevTools sources, as files from its git repository: "@<commit>", then the paths of
# files at that commit (src_unpack puts them in devtools-frontend-<commit>/)
DEVTOOLS_FILES=(
	# what Lighthouse's build-cdt-lib.js and build-cdt-strings.js generate files from,
	# at the revisions its committed outputs were generated from; front_end/generated/
	# Deprecation.ts is generated from Blink's deprecation.json5 (src_prepare)
	@3f890ceb7ad70b5831621393574401b6e474fc73
	front_end/core/sdk/SourceMap.ts
	front_end/core/common/ParsedURL.ts
	@ced63b5ae0c00cd5e0d86ab47daeaa2072016ab6
	front_end/panels/application/components/BackForwardCacheStrings.ts
	scripts/build/generate_deprecations.py
	third_party/blink/renderer/core/frame/deprecation/deprecation.json5
	# @paulirish/trace_engine 0.0.65 (Lighthouse's copy of DevTools' models/trace and
	# what it imports) was published compiled from this commit, 25 minutes before it.
	# Its sources come from the package's own source maps (files/lighthouse-trace-engine-
	# sources.mjs), except front_end/generated/protocol.ts, which has no map (it compiles
	# to nothing, but the compiled code inlines its const enum values): it is generated
	# from the protocol's definitions with this generator (src_prepare)
	@845cad7f273101ef8ae5a8e741dccd78f6f14724
	scripts/protocol_typescript/protocol_dts_generator.ts
)
# _devtools_files <function>: calls <function> <commit> <path> <distfile> for each of
# DEVTOOLS_FILES
_devtools_files() {
	local f commit
	for f in "${DEVTOOLS_FILES[@]}"; do
		if [[ ${f} == @* ]]; then
			commit=${f#@}
			continue
		fi
		local name=${f#front_end/}
		"${1}" "${commit}" "${f}" "devtools-frontend-${commit:0:8}-${name//\//-}"
	done
}
_devtools_uri() {
	SRC_URI+=" https://raw.githubusercontent.com/ChromeDevTools/devtools-frontend/${1}/${2} -> ${3}"
}
_devtools_files _devtools_uri
unset -f _devtools_uri
# The DevTools protocol's definitions (.pdl), which front_end/generated/protocol.ts is
# generated from: DevTools' copy at 845cad7 is Chromium's from main@{#1638082}; the
# closest devtools-protocol release (the definitions as Chromium has them, published
# for each change) is #1638241, which only differs in the Accessibility, CSS and Page
# domains. And inspector_protocol at DevTools' DEPS revision, whose
# concatenate_protocols.py turns them into the JSON that DevTools' generator reads (no
# GitHub mirror: Gitiles' base64 of the files).
DEVTOOLS_PROTOCOL_VER=0.0.1638241
INSPECTOR_PROTOCOL_COMMIT=c0045057ce801744c5e88596a2f1bab1802e39f0
SRC_URI+="
	https://registry.npmjs.org/devtools-protocol/-/devtools-protocol-${DEVTOOLS_PROTOCOL_VER}.tgz
"
for _f in concatenate_protocols.py pdl.py; do
	SRC_URI+=" https://chromium.googlesource.com/deps/inspector_protocol/+/${INSPECTOR_PROTOCOL_COMMIT}/${_f}?format=TEXT -> inspector_protocol-${INSPECTOR_PROTOCOL_COMMIT:0:8}-${_f}.b64"
done
unset _f
# @paulirish/trace_engine: the sources in its source maps, and its package files that
# aren't compiled output (package.json, tsconfig files, locales, small shims)
SRC_URI+="
	https://registry.npmjs.org/@paulirish/trace_engine/-/trace_engine-0.0.65.tgz
		-> paulirish-trace_engine-0.0.65.tgz
"
S="${WORKDIR}"

LICENSE="Apache-2.0 BSD-2 ISC MIT"
# axe-core; jpeg-js; Unicode's emoji data
LICENSE+=" MPL-2.0 BSD Unicode-3.0"
# spdx-license-ids, spdx-exceptions (data)
LICENSE+=" CC-BY-3.0 CC0-1.0"
SLOT="${PV%%.*}"
KEYWORDS="~amd64 ~arm64"
IUSE="test"
RESTRICT="!test? ( test )"

BDEPEND="
	${PYTHON_DEPS}
	$(python_gen_any_dep 'dev-python/json5[${PYTHON_USEDEP}]')
	>=app-i18n/unicode-emoji-17.0.0
	dev-lang/typescript:6.0.2
	dev-util/rollup:4.21.0
	dev-libs/protobuf
	dev-util/esbuild
	net-libs/nodejs
"

# npm packages whose files are replaced, as installed in VERSIONS (the Chromium ebuild
# checks their package.json's version, or if it has none, README.chromium's).
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
	"third_party/devtools-frontend/src/front_end/third_party/acorn/package 8.16.0"
	"third_party/devtools-frontend/src/front_end/third_party/codemirror/package 5.61.0"
	"third_party/devtools-frontend/src/front_end/third_party/intl-messageformat/package 9.8.0"
	"third_party/devtools-frontend/src/front_end/third_party/marked/package 18.0.4"
	"third_party/devtools-frontend/src/front_end/third_party/wasmparser/package 5.4.0"
	"third_party/chromium-bidi/node_modules/zod 3.25.76"
	"third_party/chromium-bidi/node_modules/mitt 3.0.1"
	"third_party/devtools-frontend/src/front_end/third_party/puppeteer/package 25.12.0"
	"third_party/devtools-frontend/src/front_end/third_party/puppeteer-replay/package 4.0.2"
	"third_party/devtools-frontend/src/front_end/third_party/lighthouse 13.5.0"
	"third_party/devtools-frontend/src/front_end/third_party/legacy-javascript 0.0.1"
)

# _devtools_unpack <commit> <path> <distfile>
_devtools_unpack() {
	local dest=${WORKDIR}/devtools-frontend-${1}/${2}
	mkdir -p "${dest%/*}" || die
	cp "${DISTDIR}/${3}" "${dest}" || die
}

python_check_deps() {
	python_has_version "dev-python/json5[${PYTHON_USEDEP}]"
}

src_unpack() {
	_devtools_files _devtools_unpack
	# npm's tarballs all have a package/ directory: unpack each to npm-<distfile name>.
	# Single files are used from DISTDIR.
	local a
	for a in ${A}; do
		case ${a} in
			*.tgz)
				mkdir "${WORKDIR}/npm-${a%.tgz}" || die
				tar -xzf "${DISTDIR}/${a}" --strip-components=1 -C "${WORKDIR}/npm-${a%.tgz}" ||
					die "Failed to unpack ${a}"
				;;
			*.tar.gz) unpack "${a}" ;;
			inspector_protocol-*.b64)
				local ip_file=${a#inspector_protocol-*-}
				mkdir -p "${WORKDIR}/inspector_protocol" || die
				base64 -d "${DISTDIR}/${a}" > "${WORKDIR}/inspector_protocol/${ip_file%.b64}" ||
					die "Failed to decode ${a}"
				;;
		esac
	done
}

# _dir <id>: the unpacked directory of a source
_dir() {
	local spec src_id src_repo src_ref src_uri src_distfile src_dir
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
# as it is), into ${WORKDIR}/image/tree/<output> (or <output>, if absolute).
# Arguments starting with "--" are passed to esbuild. Formats: esm, cjs,
# and cjs-default (module.exports is the entry's default export, as with
# rollup's "exports: default").
_bundle() {
	local format=${1} output=${2} entry=${3}
	shift 3
	entry="$(_dir "${entry%%:*}")/${entry#*:}"
	[[ ${output} == /* ]] || output="${WORKDIR}/image/tree/${output}"
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
# chunks, into ${WORKDIR}/image/tree/<output dir> (paths below the base kept). All
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
		--packages=external --log-level=warning --outbase="${base}" --outdir="${WORKDIR}/image/tree/${out}" "${@}"
}

src_prepare() {
	default

	# DevTools' generated files that the builds below use, made from their sources with
	# DevTools' own generators: front_end/generated/protocol.ts (for trace_engine) from the
	# protocol's .pdl definitions, via browser_protocol.json; Deprecation.ts (for
	# Lighthouse's deprecation strings) from Blink's deprecation.json5
	local dt="${WORKDIR}/devtools-frontend-845cad7f273101ef8ae5a8e741dccd78f6f14724"
	local pdl="${WORKDIR}/npm-devtools-protocol-${DEVTOOLS_PROTOCOL_VER}/pdl"
	mkdir -p "${dt}/third_party/blink/public/devtools_protocol" "${dt}/front_end/generated" || die
	edo "${EPYTHON}" "${WORKDIR}/inspector_protocol/concatenate_protocols.py" \
		"${pdl}/browser_protocol.pdl" "${pdl}/js_protocol.pdl" \
		"${dt}/third_party/blink/public/devtools_protocol/browser_protocol.json"
	edo node "${dt}/scripts/protocol_typescript/protocol_dts_generator.ts"
	local dtc="${WORKDIR}/devtools-frontend-ced63b5ae0c00cd5e0d86ab47daeaa2072016ab6"
	mkdir -p "${dtc}/front_end/generated" || die
	edo "${EPYTHON}" "${dtc}/scripts/build/generate_deprecations.py"
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
	cp "${WORKDIR}/image/tree/${webui}/ts-proto/build/src/plugin.js" "${T}/stage2/build/src/" || die
	_ts_proto_descriptors "${T}/stage2" "${T}/descriptors2"
	diff -r "${T}/descriptors1" "${T}/descriptors2" ||
		die "ts-proto doesn't regenerate its descriptors identically"

	# @bufbuild/protobuf's ES modules, which chrome://traces-internals bundles: its
	# build:esm is plain tsc. TypeScript 6 needs these flags for its TypeScript 5
	# configuration; type-checking (against newer lib*.d.ts) doesn't affect the output.
	pushd "$(_dir bufbuild-protobuf)/packages/protobuf" >/dev/null || die
	edo "${BROOT}/usr/bin/tsc-6.0.2" --project tsconfig.json --rootDir src \
		--ignoreDeprecations 6.0 --noCheck \
		--outDir "${WORKDIR}/image/tree/${webui}/@bufbuild/protobuf/dist/esm"
	popd >/dev/null || die

	# lit: compile each package (tsc --build: development/), then run its
	# rollup.config.js (../../rollup-common.js: minified files with a shared terser
	# name cache). The rollup plugins it imports: rollup-plugin-terser (in process,
	# files/), @rollup/plugin-replace and -virtual from source; the others (size
	# summary, test copies, source maps, the Node build's DOM shim and its bundled
	# polyfill-support) don't change the files Chromium uses, and are no-ops.
	local lit_tools="${T}/lit-tools/node_modules"
	mkdir -p "${lit_tools}"/terser "${lit_tools}"/rollup-plugin-terser "${lit_tools}"/@rollup || die
	_bundle cjs "${lit_tools}/terser/index.js" terser-5.34:main.js acorn=external \
		@jridgewell/source-map=source-map:src/source-map.ts \
		@jridgewell/gen-mapping=gen-mapping:src/gen-mapping.ts \
		@jridgewell/trace-mapping=trace-mapping:src/trace-mapping.ts \
		@jridgewell/set-array=set-array:src/set-array.ts \
		@jridgewell/resolve-uri=resolve-uri:src/resolve-uri.ts \
		@jridgewell/sourcemap-codec=sourcemap-codec-1.4.15:src/sourcemap-codec.ts
	cp "${FILESDIR}"/rollup-plugin-terser-7.0.2.js "${lit_tools}"/rollup-plugin-terser/index.js || die
	_bundle esm "${lit_tools}/@rollup/plugin-replace/index.js" plugin-replace:packages/replace/src/index.js \
		@rollup/pluginutils=pluginutils-5.1:packages/pluginutils/src/index.ts \
		estree-walker=estree-walker-2:src/index.js picomatch=picomatch-2.3 \
		magic-string=magic-string-0.30.7:src/index.js \
		@jridgewell/sourcemap-codec=sourcemap-codec-1.4.15:src/sourcemap-codec.ts
	_bundle esm "${lit_tools}/@rollup/plugin-virtual/index.js" plugin-virtual:packages/virtual/src/index.ts
	local stub
	for stub in \
		"rollup-plugin-summary:export function summary() { return { name: 'summary' }; }" \
		"rollup-plugin-copy:export default function copy() { return { name: 'copy' }; }" \
		"rollup-plugin-sourcemaps:export default function sourcemaps() { return { name: 'sourcemaps' }; }" \
		"@rollup/plugin-node-resolve:export default function nodeResolve() { return { name: 'node-resolve' }; }" \
		"@rollup/plugin-inject:export default function inject() { return { name: 'inject' }; }"
	do
		mkdir -p "${lit_tools}/${stub%%:*}" || die
		echo "${stub#*:}" > "${lit_tools}/${stub%%:*}/index.js" || die
	done
	local d
	for d in rollup-plugin-terser rollup-plugin-summary rollup-plugin-copy rollup-plugin-sourcemaps \
		@rollup/plugin-replace @rollup/plugin-virtual @rollup/plugin-node-resolve @rollup/plugin-inject; do
		echo '{"type": "module", "main": "index.js"}' > "${lit_tools}/${d}/package.json" || die
	done
	echo '{"main": "index.js"}' > "${lit_tools}/terser/package.json" || die

	# _lit <source id> <package>...: builds a lit commit's packages (all four are
	# compiled, for their TypeScript project references)
	_lit() {
		local lit p
		lit=$(_dir "${1}") || die
		shift
		cp -r "${lit_tools}" "${lit}/node_modules" || die
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
			if has "${p}" "$@"; then
				edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" -c rollup.config.js --silent
			fi
			popd >/dev/null || die
		done
	}

	# WebUI's lit (byte-identical to npm's; Chromium's lit_html.patch is applied by
	# the Chromium ebuild): the files in Chromium's tree
	_lit lit reactive-element lit-html lit-element lit
	local p f dest
	local -A lit_files=(
		[reactive-element]="@lit/reactive-element:css-tag.js reactive-element.js"
		[lit-html]="lit-html:async-directive.js directive-helpers.js directive.js directives/repeat.js is-server.js lit-html.js"
		[lit-element]="lit-element:lit-element.js"
		[lit]="lit:directives/repeat.js index.js"
	)
	for p in reactive-element lit-html lit-element lit; do
		for f in ${lit_files[${p}]#*:}; do
			dest="${WORKDIR}/image/tree/${webui}/${lit_files[${p}]%%:*}/${f}"
			mkdir -p "${dest%/*}" || die
			cp "$(_dir lit)/packages/${p}/${f}" "${dest}" || die
		done
	done

	# The lit DevTools' front_end/third_party/lit is built from (its package.json:
	# lit 3.3.3, which got lit-html 3.3.3, lit-element 4.2.2, @lit/reactive-element
	# 2.1.2): the npm packages' production files, for the Chromium ebuild to bundle
	# (build/devtools-lit/node_modules).
	_lit lit-3.3.3 lit-html lit
	_lit lit-4.2.2 reactive-element lit-element
	local -A devtools_lit=(
		[lit]="lit-3.3.3 lit" [lit-html]="lit-3.3.3 lit-html"
		[lit-element]="lit-4.2.2 lit-element" [@lit/reactive-element]="lit-4.2.2 reactive-element"
	)
	local name src
	for name in "${!devtools_lit[@]}"; do
		read -r src p <<< "${devtools_lit[${name}]}"
		dest="${WORKDIR}/image/build/devtools-lit/node_modules/${name}"
		mkdir -p "${dest}" || die
		pushd "$(_dir "${src}")/packages/${p}" >/dev/null || die
		cp package.json "${dest}/" || die
		find . -name '*.js' ! -path './development/*' ! -path './node/*' ! -path './test/*' \
			! -path './node_modules/*' -exec cp --parents {} "${dest}/" \; || die
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
	_copy_file() { mkdir -p "${WORKDIR}/image/tree/${2%/*}" && cp "${1}" "${WORKDIR}/image/tree/${2}" || die; }
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
		--log-level=warning --outfile="${WORKDIR}/image/tree/${dt}/get-caller-file/index.js"
	_bundle esm ${dt}/js-yaml/dist/js-yaml.mjs js-yaml:src/index.ts --packages=external --target=es2015
	# uuid's Node.js build (src/ without the *-browser files)
	_bundle esm ${dt}/uuid/dist-node/index.js uuid:src/index.ts
	# esbuild's JavaScript API, as its scripts/esbuild.js builds lib/main.js
	_bundle cjs ${dt}/esbuild/lib/main.js esbuild:lib/npm/node.ts --target=node10 \
		--define:WASM=false --define:ESBUILD_VERSION=\"0.28.2\" esbuild=external

	# DevTools' vendored libraries, shipped in DevTools (front_end/third_party), as
	# their own builds make them (without the ES5 down-levelling some of them did).
	local fe=third_party/devtools-frontend/src/front_end/third_party image="${WORKDIR}/image/tree"
	mkdir -p "${image}/${fe}"/{acorn/package/dist,codemirror/package/addon/runmode,diff,json5/lib} \
		"${image}/${fe}"/{intl-messageformat/package,marked/package/lib,wasmparser/package/dist/esm} || die
	# acorn and CodeMirror 5's runmode-standalone: their rollup.config.mjs/js
	pushd "$(_dir acorn)" >/dev/null || die
	edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" acorn/src/index.js --format es --silent \
		--file "${image}/${fe}/acorn/package/dist/acorn.mjs"
	popd >/dev/null || die
	pushd "$(_dir codemirror5)" >/dev/null || die
	edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" src/addon/runmode/runmode-standalone.js --format iife \
		--name CodeMirror --no-freeze --silent --file "${image}/${fe}/codemirror/package/addon/runmode/runmode-standalone.mjs"
	popd >/dev/null || die
	# diff-match-patch: DevTools' wrapper around (upstream's Closure-compiled build of)
	# its source, here around the source itself
	{
		cat <<-EOF
			// Note: the globals that this code exposes are relied on not only by
			// front_end/diff but also by front_endthird_party/codemirror

			// @ts-nocheck this is a legacy function that's beyond type-checking.
			(function(){
		EOF
		sed "s/^this\['\(diff_match_patch\|DIFF_DELETE\|DIFF_INSERT\|DIFF_EQUAL\)'\] = /globalThis['\1'] = /" \
			"$(_dir diff-match-patch)"/javascript/diff_match_patch_uncompressed.js
		echo '})()'
	} > "${image}/${fe}/diff/diff_match_patch.js" || die
	# intl-messageformat: its ESM bundle (with the formatjs packages it uses)
	local formatjs
	formatjs=$(_dir formatjs)/packages || die
	edo "${ESBUILD}" "${formatjs}/intl-messageformat/index.ts" --bundle --format=esm --platform=browser \
		--log-level=warning --outfile="${image}/${fe}/intl-messageformat/package/intl-messageformat.esm.js" \
		--alias:@formatjs/icu-messageformat-parser="${formatjs}/icu-messageformat-parser" \
		--alias:@formatjs/icu-skeleton-parser="${formatjs}/icu-skeleton-parser" \
		--alias:@formatjs/fast-memoize="${formatjs}/fast-memoize"
	# json5: DevTools' rebuild.sh (an ESM bundle of lib/index.js)
	edo "${ESBUILD}" "$(_dir json5)/lib/index.js" --bundle --format=esm --platform=browser --log-level=warning \
		--outfile="${image}/${fe}/json5/lib/index.js"
	# marked: its esbuild.config.js (ESM)
	edo "${ESBUILD}" "$(_dir marked)/src/marked.ts" --bundle --format=esm --platform=browser --minify \
		--log-level=warning --outfile="${image}/${fe}/marked/package/lib/marked.esm.js"
	# wasmparser: its build:esm (tsc)
	pushd "$(_dir wasmparser)" >/dev/null || die
	edo "${BROOT}/usr/bin/tsc-6.0.2" --ignoreConfig --preserveConstEnums --module es2015 --moduleResolution node \
		--target es2015 --noCheck --ignoreDeprecations 6.0 --outDir "${T}/wasmparser" \
		src/index.ts src/WasmParser.ts src/WasmDis.ts
	popd >/dev/null || die
	cp "${T}"/wasmparser/{WasmParser,WasmDis}.js "${image}/${fe}/wasmparser/package/dist/esm/" || die

	# chromium-bidi's BiDi mapper bundles zod's and mitt's ES modules. zod: its
	# build (zshy) is tsc of what its exports reach; mitt: dist/mitt.mjs.
	pushd "$(_dir zod)/packages/zod" >/dev/null || die
	edo "${BROOT}/usr/bin/tsc-6.0.2" --ignoreConfig --rootDir src --module esnext --moduleResolution bundler \
		--target es2020 --noCheck --ignoreDeprecations 6.0 --skipLibCheck \
		--outDir "${image}/${bidi}/zod" \
		src/index.ts src/v3/index.ts src/v4/index.ts src/v4-mini/index.ts src/v4/mini/index.ts \
		src/v4/core/index.ts src/v4/locales/index.ts src/v4/locales/*.ts
	popd >/dev/null || die
	edo "${ESBUILD}" "$(_dir mitt)/src/index.ts" --format=esm --platform=browser --log-level=warning \
		--outfile="${image}/${bidi}/mitt/dist/mitt.mjs"

	# DevTools' Puppeteer: what puppeteer-core's Herebyfile.mjs (generate:injected,
	# build:tsc, build) and rollup.config.mjs (build:es5) and @puppeteer/replay's
	# rollup.config.js do. The ES5 build is without @rollup/plugin-babel (which only
	# lowers newer syntax for old engines; DevTools doesn't load it). Puppeteer's lib/ is
	# installed in build/, for the Chromium ebuild to take the files DevTools has.
	local urlpattern puppeteer
	urlpattern=$(_dir urlpattern-polyfill) || die
	puppeteer=$(_dir puppeteer)/packages/puppeteer-core || die
	edo "${ESBUILD}" "${urlpattern}/src/url-pattern.ts" --bundle --format=esm --minify --keep-names \
		--target=es2022 --log-level=warning --outfile="${urlpattern}/dist/urlpattern.js"
	pushd "${puppeteer}" >/dev/null || die
	edo "${ESBUILD}" src/injected/injected.ts --bundle --format=cjs --target=chrome125,firefox125 --minify \
		--legal-comments=none --log-level=warning --outfile="${T}/injected.js"
	mkdir -p src/generated node_modules/webdriver-bidi-protocol || die
	edo node -e '
		const fs = require("fs");
		const tmpl = fs.readFileSync("src/templates/injected.ts.tmpl", "utf8");
		fs.writeFileSync("src/generated/injected.ts",
			tmpl.replace("SOURCE_CODE", JSON.stringify(fs.readFileSync(process.argv[1], "utf8"))));
	' "${T}/injected.js"
	cp "${WORKDIR}"/npm-webdriver-bidi-protocol-0.4.3/package.json node_modules/webdriver-bidi-protocol/ || die
	cp -r "${WORKDIR}"/npm-webdriver-bidi-protocol-0.4.3/out node_modules/webdriver-bidi-protocol/ || die
	find node_modules/webdriver-bidi-protocol -name '*.js' -delete || die
	local proj
	for proj in third_party .; do
		# (types: Node.js and Chrome extension types, for type-checking only)
		echo '{"extends": "./tsconfig.json", "compilerOptions": {"types": [], "typeRoots": []}}' \
			> "${proj}"/tsconfig.gentoo.json || die
		pushd "${proj}" >/dev/null || die
		edo "${BROOT}/usr/bin/tsc-6.0.2" -p tsconfig.gentoo.json --noCheck --ignoreDeprecations 6.0
		popd >/dev/null || die
	done
	local -A puppeteer_third_party=(
		[mitt]="$(_dir mitt)/src/index.ts:$(_dir mitt)/LICENSE"
		[parsel-js]="$(_dir parsel)/parsel.ts:$(_dir parsel)/LICENSE"
		[rxjs]="$(_dir rxjs)/src/index.ts:$(_dir rxjs)/LICENSE.txt"
		[urlpattern-polyfill]="${urlpattern}:${urlpattern}/LICENSE"
	)
	local name f
	for name in "${!puppeteer_third_party[@]}"; do
		f=lib/third_party/${name}/${name}.js
		edo "${ESBUILD}" "${f}" --outfile="${f}" --allow-overwrite --bundle --format=esm --target=node22 \
			--legal-comments=inline --log-level=warning --alias:"${name}=${puppeteer_third_party[${name}]%%:*}"
		{ printf '/**\n'; cat "${puppeteer_third_party[${name}]#*:}"; printf '\n*/\n'; cat "${f}"; } > "${f}.tmp" || die
		mv "${f}.tmp" "${f}" || die
	done
	mkdir -p "${T}"/puppeteer-rollup/node_modules/@rollup/plugin-node-resolve || die
	cp "${WORKDIR}/image/tree/${bidi}/@rollup/plugin-node-resolve/dist/es/index.js" \
		"${T}"/puppeteer-rollup/node_modules/@rollup/plugin-node-resolve/index.mjs || die
	echo '{"name": "@rollup/plugin-node-resolve", "exports": "./index.mjs"}' \
		> "${T}"/puppeteer-rollup/node_modules/@rollup/plugin-node-resolve/package.json || die
	sed -e '/plugin-babel/d' -e '/getBabelOutputPlugin(/,/^    }),$/d' rollup.config.mjs \
		> "${T}"/puppeteer-rollup/rollup.config.mjs || die
	grep -q babel "${T}"/puppeteer-rollup/rollup.config.mjs && die "rollup.config.mjs: Babel left"
	edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" -c "${T}"/puppeteer-rollup/rollup.config.mjs --silent
	# tools/patch.mjs, its JavaScript part (the rest is for api-extractor's type declarations)
	sed -n '1,/^fs.writeFileSync(genJs, file);$/p' ../../tools/patch.mjs > "${T}"/patch-js.mjs || die
	edo node "${T}"/patch-js.mjs lib/es5-iife/puppeteer-core-browser.js
	mkdir -p "${WORKDIR}/image/build/devtools-puppeteer" || die
	cp -r lib "${WORKDIR}/image/build/devtools-puppeteer/" || die
	popd >/dev/null || die
	pushd "$(_dir replay)" >/dev/null || die
	echo '{"extends": "./tsconfig.json", "compilerOptions": {"outDir": "tsc-out", "declaration": false, "declarationMap": false, "sourceMap": false, "types": []}}' \
		> tsconfig.gentoo.json || die
	edo "${BROOT}/usr/bin/tsc-6.0.2" -p tsconfig.gentoo.json --noCheck --ignoreDeprecations 6.0 \
		--module NodeNext --moduleResolution NodeNext
	mkdir -p "${image}/${fe}/puppeteer-replay/package/lib" || die
	edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" tsc-out/main.js --format es --external lighthouse,puppeteer \
		--silent --file "${image}/${fe}/puppeteer-replay/package/lib/main.js"
	popd >/dev/null || die

	# DevTools' codemirror.next: the npm packages it bundles, from their sources, as
	# their builds make them (one ES module per package, dist/index.js; Lezer parsers
	# generated from their grammars), into build/devtools-codemirror/node_modules for the
	# Chromium ebuild to bundle with DevTools' bundle.ts. TypeScript packages also get a
	# dist/index.d.ts re-exporting their sources, so that tsc knows which of bundle.ts's
	# re-exports are types.
	local cm="${WORKDIR}/image/build/devtools-codemirror/node_modules" cm_tools="${T}/cm-tools"
	mkdir -p "${cm}" "${cm_tools}/lr" || die
	# @lezer/generator (its grammar parser is hand-written), with @lezer/lr's constants
	ln -s "$(_dir cm:@lezer/lr)/src" "${cm_tools}/lr/src" || die
	ln -s src "${cm_tools}/lr/dist" || die
	echo '{"name": "@lezer/lr", "main": "src/index.ts"}' > "${cm_tools}/lr/package.json" || die
	edo "${ESBUILD}" "$(_dir cm:@lezer/generator)/src/index.ts" --bundle --format=esm --platform=node \
		--target=node18 --log-level=warning --outfile="${cm_tools}/lezer-generator.mjs" \
		--alias:@lezer/lr="${cm_tools}/lr" --alias:@lezer/common="$(_dir cm:@lezer/common)/src/index.ts"
	cat > "${cm_tools}/gen.mjs" <<-'EOF' || die
		// lezer-generator <grammar> -o <parser>: writes the parser and its .terms module
		import { buildParserFile } from './lezer-generator.mjs';
		import { readFileSync, writeFileSync } from 'fs';
		const [file, parserOut, termsOut] = process.argv.slice(2);
		const { parser, terms } = buildParserFile(readFileSync(file, 'utf8'), { fileName: file, moduleStyle: 'es' });
		writeFileSync(parserOut, parser);
		writeFileSync(termsOut, terms);
	EOF
	_cm_build() { # <package> <entry> [types entry]
		edo "${ESBUILD}" "${cm}/${1}/${2}" --bundle --format=esm --platform=neutral --target=es2020 \
			--packages=external --log-level=warning \
			--tsconfig-raw='{"compilerOptions":{"useDefineForClassFields":false}}' --outfile="${cm}/${1}/dist/index.js"
		if [[ -n ${3} ]]; then
			echo "export * from \"../${3%.ts}\";" > "${cm}/${1}/dist/index.d.ts" || die
		fi
	}
	local spec_cm id
	for spec_cm in "${JS_SOURCES[@]}"; do
		read -r id _ <<< "${spec_cm}"
		[[ ${id} == cm:* && ${id} != cm:@lezer/generator ]] || continue
		name=${id#cm:}
		name=${name//+//node_modules/}
		[[ ${name} == */* ]] && { mkdir -p "${cm}/${name%/*}" || die; }
		cp -r "$(_dir "${id}")" "${cm}/${name}" || die
		rm -rf "${cm}/${name}"/test "${cm}/${name}"/.github || die
	done
	pushd "${cm}" >/dev/null || die
	for p in cpp css html java javascript php python sass xml; do
		edo node "${cm_tools}/gen.mjs" @lezer/${p}/src/${p}.grammar @lezer/${p}/src/parser.js \
			@lezer/${p}/src/parser.terms.js
		f=src/parser.js
		[[ ${p} == html ]] && f=src/index.js
		_cm_build @lezer/${p} ${f}
	done
	local g b entry
	for spec_cm in @codemirror/autocomplete:src/index.ts @codemirror/commands:src/commands.ts \
		@codemirror/lang-angular:src/angular.ts @codemirror/lang-cpp:src/cpp.ts @codemirror/lang-css:src/css.ts \
		@codemirror/lang-html:src/html.ts @codemirror/lang-java:src/java.ts @codemirror/lang-javascript:src/index.ts \
		@codemirror/lang-less:src/less.ts @codemirror/lang-markdown:src/index.ts @codemirror/lang-php:src/php.ts \
		@codemirror/lang-python:src/python.ts @codemirror/lang-sass:src/sass.ts @codemirror/lang-vue:src/vue.ts \
		@codemirror/lang-wast:src/wast.ts @codemirror/lang-xml:src/xml.ts @codemirror/language:src/index.ts \
		@codemirror/search:src/search.ts @codemirror/state:src/index.ts @codemirror/view:src/index.ts \
		@lezer/common:src/index.ts @lezer/highlight:src/highlight.ts @lezer/lr:src/index.ts \
		@lezer/markdown:src/index.ts @lezer/markdown/node_modules/@lezer/common:src/index.ts \
		@replit/codemirror-indentation-markers:src/index.ts @replit/codemirror-lang-svelte:src/index.ts; do
		p=${spec_cm%%:*}
		entry=${spec_cm#*:}
		# cm-buildhelper's rollup plugin: "./X.grammar" (and ".terms") imports get the parser
		for g in "${p}"/src/*.grammar; do
			[[ -f ${g} ]] || continue
			b=${g##*/}
			edo node "${cm_tools}/gen.mjs" "${g}" "${g}.gen.js" "${g}.terms.gen.js"
			sed -i -e "s|\"\./${b}\"|\"./${b}.gen.js\"|g; s|\"\./${b}\.terms\"|\"./${b}.terms.gen.js\"|g" \
				-e "s|'\./${b}'|'./${b}.gen.js'|g; s|'\./${b}\.terms'|'./${b}.terms.gen.js'|g" \
				$(find "${p}/src" -maxdepth 1 -name '*.ts' -o -maxdepth 1 -name '*.js') || die
		done
		_cm_build "${p}" "${entry}" "${entry}"
	done
	# @codemirror/legacy-modes, style-mod, w3c-keyname, @marijn/find-cluster-break and crelt
	# are ES modules as they are.
	popd >/dev/null || die

	# axe-core 4.13.0's axe.min.js, which Lighthouse inlines: its build/run-build.mjs
	# steps for axe.js and axe.min.js (rule metadata, esbuild of lib/core, the rules
	# compiled with doT, concatenation, uglify-js), with the packages it bundles from
	# their sources. Babel (@babel/preset-env, lowering to ES5) is left out: Chromium runs
	# it. Its polyfills only apply where a feature is missing.
	# (esbuild's JavaScript API runs dev-util/esbuild)
	local -x ESBUILD_BINARY_PATH=${ESBUILD}
	local axe axe_nm
	axe=$(_dir axe-core) || die
	axe_nm=${axe}/node_modules
	mkdir -p "${axe_nm}"/{@deque,esbuild/lib,glob} || die
	_axe_pkg() { # <source dir> <name>
		cp -r "${1}" "${axe_nm}/${2}" || die
	}
	# Build tools: esbuild's JavaScript API (built above), glob as Node.js' fs.globSync
	cp "${WORKDIR}/image/tree/${dt}/esbuild/lib/main.js" "${axe_nm}/esbuild/lib/" || die
	echo '{"name": "esbuild", "version": "0.28.2", "main": "lib/main.js"}' > "${axe_nm}/esbuild/package.json" || die
	cat > "${axe_nm}/glob/index.mjs" <<-'JS' || die
		import fs from 'node:fs';
		import path from 'node:path';
		export function globSync(patterns, { cwd = process.cwd(), nodir = false } = {}) {
		  const out = new Set();
		  for (const p of [].concat(patterns)) {
		    for (const f of fs.globSync(p, { cwd })) {
		      if (!nodir || !fs.statSync(path.resolve(cwd, f)).isDirectory()) out.add(f.split(path.sep).join('/'));
		    }
		  }
		  return [...out];
		}
	JS
	echo '{"name": "glob", "type": "module", "exports": "./index.mjs"}' > "${axe_nm}/glob/package.json" || die
	_axe_pkg "$(_dir clone)" clone
	_axe_pkg "$(_dir deque-dot)" @deque/dot
	_axe_pkg "$(_dir uglify-js)" uglify-js
	_axe_pkg "$(_dir html-entities)" html-entities
	local f
	for f in commonjs:cjs esm:esm; do
		edo "${ESBUILD}" "${axe_nm}/html-entities/src/index.ts" --bundle --platform=node --format=${f#*:} \
			--log-level=warning --outfile="${axe_nm}/html-entities/dist/${f%%:*}/index.js"
	done
	# The packages axe.js bundles. colorjs.io: its sources, with axe-core's
	# patches/colorjs.io@0.4.3.patch (made for dist/color.js)
	_axe_pkg "$(_dir colorjs)" colorjs.io
	f=${axe_nm}/colorjs.io/src/display.js
	sed -i -e 's/^if (typeof CSS !== "undefined" && CSS\.supports) {$/if (typeof CSS !== "undefined" \&\& CSS?.supports) {/' \
		-e 's/if (typeof CSS === "undefined" || CSS\.supports("color", ret)/if (typeof CSS === "undefined" || CSS?.supports("color", ret)/' \
		"${f}" || die
	[[ $(grep -c 'CSS?\.supports' "${f}") == 2 ]] || die "colorjs.io's patch didn't apply"
	edo node -e '
		const f = process.argv[1], p = require(f);
		p.exports["."] = { import: "./src/index.js" };
		p.module = "./src/index.js";
		require("fs").writeFileSync(f, JSON.stringify(p));
	' "${axe_nm}/colorjs.io/package.json"
	_axe_pkg "$(_dir css-selector-parser)" css-selector-parser
	pushd "${axe_nm}/css-selector-parser" >/dev/null || die
	edo "${BROOT}/usr/bin/tsc-6.0.2" -p tsconfig.json --rootDir src --ignoreDeprecations 6.0
	popd >/dev/null || die
	# emoji-regex: its script/build.js fills in emoji-test-regex-pattern's pattern, which
	# that package makes with a PHP tool; files/ makes the same pattern from the same
	# sequences (Unicode's emoji-test.txt and the package's extra ones)
	_axe_pkg "$(_dir emoji-regex)" emoji-regex
	mkdir -p "${axe_nm}/emoji-regex/node_modules/emoji-test-regex-pattern/dist/latest" || die
	edo node "${FILESDIR}/emoji-test-regex-pattern.mjs" "${BROOT}/usr/share/unicode/emoji/emoji-test.txt" \
		"$(_dir emoji-test-regex-pattern)/script/get-sequences.js" \
		> "${axe_nm}/emoji-regex/node_modules/emoji-test-regex-pattern/dist/latest/javascript.txt"
	pushd "${axe_nm}/emoji-regex" >/dev/null || die
	rm index.js index.mjs || die
	edo node script/build.js
	popd >/dev/null || die
	local p
	for p in memoizee d es5-ext es6-iterator es6-symbol es6-weak-map esniff event-emitter ext is-promise \
		lru-queue next-tick timers-ext type typedarray weakmap-polyfill es6-promise; do
		_axe_pkg "$(_dir "${p}")" "${p}"
	done
	# es6-promise: its ES module sources (main is its rollup build)
	edo node -e '
		const f = process.argv[1], p = require(f);
		p.main = "lib/es6-promise.js";
		delete p.browser;
		require("fs").writeFileSync(f, JSON.stringify(p));
	' "${axe_nm}/es6-promise/package.json"
	# core-js-pure: core-js' modules with core-js-pure's overrides (scripts/clean-and-copy.mjs)
	local corejs
	corejs=$(_dir core-js)/packages || die
	cp -r "${corejs}/core-js-pure" "${axe_nm}/core-js-pure" || die
	cp -rn "${corejs}/core-js/." "${axe_nm}/core-js-pure/" || die
	cp -r "${corejs}/core-js-pure/override/." "${axe_nm}/core-js-pure/" || die
	pushd "${axe}" >/dev/null || die
	# Without Babel, lib/core/index.js's "const axe = axe || {}" has to be the var Babel makes it.
	grep -q '^const axe = axe || {};$' lib/core/index.js || die "axe-core's lib/core/index.js changed"
	sed -i 's/^const axe = axe || {};$/var axe = axe || {};/' lib/core/index.js || die
	cat > build-gentoo.mjs <<-'JS' || die
		import fs from 'node:fs';
		import { createBuildContext } from './build/build-context.mjs';
		import { runMetadataFunctionMap } from './build/run-build/metadata-function-map.mjs';
		import { runEsbuildCore } from './build/run-build/esbuild-core.mjs';
		import { runConcatEngine, runUglify } from './build/run-build/concat-uglify.mjs';
		import buildRules from './build/configure.mjs';
		const ctx = createBuildContext(process.cwd());
		const pkg = ctx.readJSON('package.json');
		runMetadataFunctionMap(ctx);
		await runEsbuildCore(ctx);
		await new Promise((resolve, reject) => buildRules(ctx, {
		  rules: ['lib/rules/**/*.json'], checks: ['lib/checks/**/*.json'], misc: ['lib/misc/**/*.json'],
		  blacklist: ['metadata'], tags: ''
		}, (result) => {
		  try { ctx.writeFile('tmp/rules.js', `axe._load(${result.auto});`); resolve(); } catch (e) { reject(e); }
		}));
		fs.copyFileSync('lib/core/index.js', 'tmp/core/index.js');
		// the year of the 4.13.0 release, for its copyright line
		runConcatEngine(ctx, [''], pkg, 2026);
		runUglify(ctx, ['']);
	JS
	edo node build-gentoo.mjs
	popd >/dev/null || die

	# Lighthouse: what its build/ scripts do for DevTools (build-bundle.js,
	# build-report.js, build-dt-report-resources.js; readme.md, "Building for DevTools"),
	# after regenerating its committed generated files, with the npm packages they
	# bundle built from their sources, in its node_modules.
	local lh lh_nm
	lh=$(_dir lighthouse) || die
	lh_nm=${lh}/node_modules
	mkdir -p "${lh_nm}" || die
	_lh_pkg() { # <source dir> <name>: a package that is its sources
		[[ ${2} == */* ]] && { mkdir -p "${lh_nm}/${2%/*}" || die; }
		cp -r "${1}" "${lh_nm}/${2}" || die
	}
	# _lh_tsc cjs|esm <target> <output dir> <file>...: tsc's emitter, in the current directory
	_lh_tsc() {
		local module=commonjs
		[[ ${1} == esm ]] && module=esnext
		edo node "${FILESDIR}/lighthouse-ts-transpile.cjs" "${BROOT}/usr/lib/typescript/6.0.2/lib/typescript.js" \
			"${module}" "${@:2}"
	}
	# TypeScript sources, without tests, scripts and declarations
	_lh_ts_sources() {
		find "$@" -name '*.ts' ! -name '*.d.ts' ! -name '*.test.ts' ! -name '*_test.ts' \
			! -path '*/tests/*' ! -path '*/test/*' ! -path '*/scripts/*' ! -path '*/node_modules/*' | sort
		assert
	}
	for p in debug ms jpeg-js lighthouse-stack-packs robots-parser resolve-1.22.10:resolve is-core-module \
		function-bind hasown path-parse supports-preserve-symlinks-flag builtin-modules escape-string-regexp \
		json-schema-traverse fast-uri require-from-string lodash-4.17:lodash dot js-library-detector \
		soft-navigation:lighthouse-plugin-soft-navigation; do
		_lh_pkg "$(_dir "${p%%:*}")" "${p#*:}"
	done
	_lh_pkg "$(_dir http-link-header)" http-link-header
	_lh_pkg "$(_dir format-message)/packages/lookup-closest-locale" lookup-closest-locale
	_lh_pkg "$(_dir speedline)/core" speedline-core
	ln -s ../lighthouse-logger "${lh_nm}/lighthouse-logger" || die
	# the soft-navigation plugin imports "lighthouse"
	ln -s .. "${lh_nm}/lighthouse" || die
	mkdir "${lh_nm}/axe-core" || die
	cp "${axe}"/{package.json,axe.js,axe.min.js,LICENSE} "${lh_nm}/axe-core/" || die
	# lodash-es is generated from lodash.js; Lighthouse imports three functions (files/)
	mkdir "${lh_nm}/lodash-es" || die
	cp "${FILESDIR}/lighthouse-lodash-es.js" "${lh_nm}/lodash-es/lodash.js" || die
	echo '{"name": "lodash-es", "version": "4.17.21", "type": "module", "main": "lodash.js", "sideEffects": false}' \
		> "${lh_nm}/lodash-es/package.json" || die
	# image-ssim: index.js is compiled from index.ts
	_lh_pkg "$(_dir image-ssim)" image-ssim
	pushd "${lh_nm}/image-ssim" >/dev/null || die
	rm index.js || die
	_lh_tsc cjs ES2017 . index.ts
	popd >/dev/null || die
	# formatjs: CommonJS next to package.json (main), ES modules in lib/ (module); compiled
	# where installed, for tsc to find the other packages' types
	local name files
	for p in fast-memoize icu-skeleton-parser icu-messageformat-parser intl-messageformat; do
		f=$(_dir "lh-${p}")/packages/${p} || die
		name=$(node -p "require('${f}/package.json').name") || die
		_lh_pkg "${f}" "${name}"
		pushd "${lh_nm}/${name}" >/dev/null || die
		files=$(_lh_ts_sources .) || die
		ES_MODULE_INTEROP=1 DECLARATION=1 _lh_tsc cjs ES2017 . ${files}
		_lh_tsc esm ES2017 lib ${files}
		popd >/dev/null || die
	done
	for p in tldts-core tldts-icann; do
		_lh_pkg "$(_dir tldts)/packages/${p}" "${p}"
		pushd "${lh_nm}/${p}" >/dev/null || die
		files=$(_lh_ts_sources index.ts src) || die
		DECLARATION=1 DECLARATION_DIR="${lh_nm}/${p}/dist/types" _lh_tsc cjs ES2017 dist/cjs ${files}
		_lh_tsc esm ES2017 dist/es6 ${files}
		popd >/dev/null || die
	done
	_lh_pkg "$(_dir csp-evaluator)" csp_evaluator
	pushd "$(_dir csp-evaluator)" >/dev/null || die
	files=$(_lh_ts_sources .) || die
	ES_MODULE_INTEROP=1 _lh_tsc cjs ES2020 "${lh_nm}/csp_evaluator/dist" ${files}
	popd >/dev/null || die
	_lh_pkg "$(_dir ajv)" ajv
	pushd "$(_dir ajv)/lib" >/dev/null || die
	files=$(_lh_ts_sources .) || die
	_lh_tsc cjs ES2018 "${lh_nm}/ajv/dist" ${files}
	find refs -name '*.json' -exec cp --parents {} "${lh_nm}/ajv/dist" \; || die
	popd >/dev/null || die
	_lh_pkg "$(_dir ajv-formats)" ajv-formats
	pushd "$(_dir ajv-formats)/src" >/dev/null || die
	files=$(_lh_ts_sources .) || die
	_lh_tsc cjs ES2018 "${lh_nm}/ajv-formats/dist" ${files}
	popd >/dev/null || die
	# fast-deep-equal: index.js etc. from src/index.jst, with doT
	_lh_pkg "$(_dir fast-deep-equal)" fast-deep-equal
	pushd "${lh_nm}/fast-deep-equal" >/dev/null || die
	edo node build.js
	popd >/dev/null || die
	_lh_pkg "$(_dir marky)" marky
	local v
	for v in cjs:cjs:false es:esm:false browser.cjs:cjs:true browser.es:esm:true; do
		IFS=: read -r name f p <<< "${v}"
		edo "${ESBUILD}" --log-level=warning --bundle --format="${f}" --define:process.browser="${p}" \
			"$(_dir marky)/src/index.js" --outfile="${lh_nm}/marky/lib/marky.${name}.js"
	done
	# Build-time only: magic-string (its rollup.config.js, without buble's ES5
	# transpiling), sourcemap-codec, acorn
	_lh_pkg "$(_dir sourcemap-codec-1.4.8)" sourcemap-codec
	for v in cjs:umd esm:es; do
		edo "${ESBUILD}" --log-level=warning --format=${v%%:*} "$(_dir sourcemap-codec-1.4.8)/src/sourcemap-codec.ts" \
			--outfile="${lh_nm}/sourcemap-codec/dist/sourcemap-codec.${v#*:}.js"
	done
	_lh_pkg "$(_dir magic-string-0.27)" magic-string
	pushd "$(_dir magic-string-0.27)" >/dev/null || die
	edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" -i src/index.js -f es -e sourcemap-codec \
		--intro 'var DEBUG = false;' -o "${lh_nm}/magic-string/dist/magic-string.es.js" --silent
	edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" -i src/index-legacy.js -f cjs --exports default \
		-e sourcemap-codec --intro 'var DEBUG = false;' -o "${lh_nm}/magic-string/dist/magic-string.cjs.js" --silent
	popd >/dev/null || die
	_lh_pkg "$(_dir acorn)/acorn" acorn
	edo "${ESBUILD}" --log-level=warning --bundle --format=esm "$(_dir acorn)/acorn/src/index.js" \
		--outfile="${lh_nm}/acorn/dist/acorn.mjs"
	edo "${ESBUILD}" --log-level=warning --bundle --format=cjs "$(_dir acorn)/acorn/src/index.js" \
		--outfile="${lh_nm}/acorn/dist/acorn.js"
	# rollup-plugin-polyfill-node supplies the Node.js polyfills: polyfills/{buffer,
	# process}-es6.js are rollup bundles of buffer-es6 and process-es6
	# (scripts/build-polyfills.js), embedded in src/polyfills.ts (scripts/collect-polyfills.js)
	local pn=${lh_nm}/rollup-plugin-polyfill-node
	_lh_pkg "$(_dir polyfill-node)" rollup-plugin-polyfill-node
	edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" -i "$(_dir buffer-es6)/index.js" -f es \
		-e crypto,vm,events,path,stream,util,buffer -o "${pn}/polyfills/buffer-es6.js" --silent
	edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" -i "$(_dir process-es6)/browser.js" -f es \
		-e crypto,vm,events,path,stream,util,buffer -o "${pn}/polyfills/process-es6.js" --silent
	edo node -e '
		const fs = require("fs"), path = require("path");
		const dir = process.argv[1] + "/polyfills", out = {};
		for (const f of fs.readdirSync(dir, { recursive: true }).sort()) {
			if (fs.statSync(path.join(dir, f)).isFile()) out[f] = fs.readFileSync(path.join(dir, f), "utf8");
		}
		fs.writeFileSync(process.argv[1] + "/src/polyfills.ts", "export default " + JSON.stringify(out));
	' "${pn}"
	pushd "${pn}" >/dev/null || die
	edo node "${BROOT}/usr/lib/rollup/4.21.0/rollup" -i src/polyfills.ts -f cjs --exports default \
		-o dist/polyfills.js --silent
	ES_MODULE_INTEROP=1 _lh_tsc cjs ES2019 dist/tmp src/modules.ts
	mv dist/tmp/src/modules.js dist/modules.js || die
	popd >/dev/null || die
	# third-party-web: dist/*.json from data/
	_lh_pkg "$(_dir third-party-web)" third-party-web
	pushd "${lh_nm}/third-party-web" >/dev/null || die
	edo node bin/convert-entities-db.js
	edo node bin/build-entity-json-files.js
	edo node -e '
		const fs = require("fs"), aliases = require("./package.json").config.exportAliases;
		for (const [name, target] of Object.entries(aliases)) {
			fs.writeFileSync(name + ".js", `module.exports = require("${target}")\n`);
		}
	'
	popd >/dev/null || die
	# @paulirish/trace_engine: the TypeScript it was compiled from, i.e. the text its
	# source maps hold, compiled as one program (for const enums, as in DevTools' build),
	# plus the edits DevTools' unpublished packaging script makes to the compiled package
	# (the edits script). That TypeScript is DevTools' files at the commit in
	# DEVTOOLS_FILES with files/lighthouse-trace-engine-0.0.65-packaging.patch applied,
	# the packaging script's edits to the sources (when updating, check with the
	# script's verify mode against such a checkout). Modules outside the
	# package are missing, so tsc reports type errors; the JavaScript it emits doesn't
	# depend on them.
	local te_src="${T}/trace_engine" te="${lh_nm}/@paulirish/trace_engine"
	local te_dt="${WORKDIR}/devtools-frontend-845cad7f273101ef8ae5a8e741dccd78f6f14724/front_end"
	local te_npm="${WORKDIR}/npm-paulirish-trace_engine-0.0.65"
	edo node "${FILESDIR}/lighthouse-trace-engine-sources.mjs" copy "${te_npm}" "${te_src}"
	# DevTools' protocol types (const enums the sources use), as a declaration file
	edo "${BROOT}/usr/bin/tsc-6.0.2" --ignoreConfig --declaration --emitDeclarationOnly --target esnext \
		--module esnext --outDir "${te_src}/generated" "${te_dt}/generated/protocol.ts"
	edo node "${FILESDIR}/lighthouse-trace-engine-edits.mjs" "${te_src}"
	mkdir -p "${te}" || die
	cat > "${te_src}/tsconfig.build.json" <<-EOF || die
		{
		  "compilerOptions": {
		    "module": "esnext", "target": "esnext", "moduleResolution": "bundler",
		    "experimentalDecorators": true, "lib": ["esnext", "dom"], "types": [],
		    "skipLibCheck": true, "noEmitOnError": false, "rootDir": ".", "outDir": "${te}"
		  },
		  "include": ["**/*.ts"]
		}
	EOF
	pushd "${te_src}" >/dev/null || die
	"${BROOT}/usr/bin/tsc-6.0.2" -p tsconfig.build.json > "${T}/trace_engine-tsc.log"
	find . -type f ! -name '*.ts' ! -name tsconfig.build.json -exec cp --parents {} "${te}" \; || die
	while IFS= read -r -d '' f; do
		[[ -f ${te}/${f%.ts}.js ]] || die "tsc didn't compile trace_engine's ${f}"
	done < <(find . -name '*.ts' ! -name '*.d.ts' -print0)
	popd >/dev/null || die
	# legacy-javascript (DevTools has 0.0.1, published from these sources); trace_engine imports it
	mkdir "${lh_nm}/legacy-javascript" || die
	pushd "${lh}" >/dev/null || die
	edo "${ESBUILD}" --log-level=warning --bundle --format=esm core/lib/legacy-javascript/legacy-javascript.js \
		--outfile="${lh_nm}/legacy-javascript/legacy-javascript.js"
	cp core/lib/legacy-javascript/package.json "${lh_nm}/legacy-javascript/" || die
	popd >/dev/null || die
	# Build tools: esbuild's JavaScript API and terser (built above), TypeScript, parse5
	# with a stand-in for jsdom (files/: what build-report-components.js uses),
	# placeholders for the modules build-bundle.js replaces with empty ones, and the
	# DevTools sources of build-cdt-lib.js and build-cdt-strings.js
	mkdir -p "${lh_nm}"/{esbuild/lib,terser,typescript,jsdom} || die
	cp "${WORKDIR}/image/tree/${dt}/esbuild/lib/main.js" "${lh_nm}/esbuild/lib/" || die
	echo '{"name": "esbuild", "version": "0.28.2", "main": "lib/main.js"}' > "${lh_nm}/esbuild/package.json" || die
	cp "${WORKDIR}/image/tree/${webui}/terser/dist/bundle.min.js" "${lh_nm}/terser/terser.js" || die
	echo '{"name": "terser", "version": "5.37.0", "main": "terser.js"}' > "${lh_nm}/terser/package.json" || die
	ln -s "${BROOT}/usr/lib/typescript/6.0.2/lib" "${lh_nm}/typescript/lib" || die
	echo '{"name": "typescript", "version": "6.0.2", "main": "lib/typescript.js"}' > "${lh_nm}/typescript/package.json" || die
	_lh_pkg "$(_dir parse5-5)/packages/parse5" parse5
	cp "${FILESDIR}/lighthouse-jsdom-shim.js" "${lh_nm}/jsdom/index.js" || die
	echo '{"name": "jsdom", "version": "12.2.0", "main": "index.js"}' > "${lh_nm}/jsdom/package.json" || die
	for p in puppeteer-core @sentry/node; do
		mkdir -p "${lh_nm}/${p}" || die
		echo "{\"name\": \"${p}\", \"main\": \"index.js\"}" > "${lh_nm}/${p}/package.json" || die
		echo '// Placeholder: build-bundle.js replaces this module.' > "${lh_nm}/${p}/index.js" || die
	done
	local cdt=${lh_nm}/chrome-devtools-frontend/front_end
	mkdir -p "${cdt}" || die
	cp -r "${WORKDIR}"/devtools-frontend-{3f890ceb7ad70b5831621393574401b6e474fc73,ced63b5ae0c00cd5e0d86ab47daeaa2072016ab6}/front_end/. \
		"${cdt}/" || die
	pushd "${lh}" >/dev/null || die
	# build-bundle.js reads the version from git, and a test helper
	eapply "${FILESDIR}/lighthouse-13.5.0-build-bundle.patch"
	# Lighthouse's committed generated files, regenerated by its scripts
	local regen
	for regen in \
		"build/build-report-components.js report/renderer/components.js" \
		"build/build-ard-schema.js third-party/ard/schema-validator.js" \
		"build/build-cdt-lib.js core/lib/cdt/generated/SourceMap.js core/lib/cdt/generated/ParsedURL.js" \
		"build/build-cdt-strings.js core/lib/deprecations-strings.js core/lib/bf-cache-strings.js"
	do
		set -- ${regen}
		rm "${@:2}" || die
		edo node "${1}" >/dev/null
		for f in "${@:2}"; do
			[[ -s ${f} ]] || die "${1} didn't regenerate ${f}"
		done
	done
	edo node build/build-report.js --standalone --esm
	# DevTools doesn't have the flow report; build-dt-report-resources.js only needs the
	# file to exist.
	echo '/* flow report not built */' > dist/report/flow.js || die
	mkdir -p dist/devtools || die
	LH_GIT_REF=v13.5.0 edo node build/build-bundle.js \
		clients/devtools/devtools-entry.js dist/devtools/lighthouse-dt-bundle.js
	# build-bundle.js inlines files read with fs.readFileSync, and silently keeps the
	# call when it can't resolve one: check the two from node_modules.
	grep -q 'd41d8cd98f00b204e9800998ecf8427e_LibraryDetectorTests' dist/devtools/lighthouse-dt-bundle.js ||
		die "js-library-detector isn't in lighthouse-dt-bundle.js"
	grep -q 'axe v4\.13\.0' dist/devtools/lighthouse-dt-bundle.js || die "axe-core isn't in lighthouse-dt-bundle.js"
	edo node build/build-dt-report-resources.js
	local lh_out="${image}/${fe}/lighthouse"
	mkdir -p "${lh_out}"/{report,report-assets,locales} "${image}/${fe}/legacy-javascript/lib" || die
	cp dist/devtools/lighthouse-dt-bundle.js "${lh_out}/" || die
	cp dist/report/bundle.esm.js "${lh_out}/report/bundle.js" || die
	cp dist/dt-report-resources/report-generator.mjs "${lh_out}/report-assets/" || die
	cp shared/localization/locales/*.json "${lh_out}/locales/" || die
	cp "${lh_nm}/legacy-javascript/legacy-javascript.js" "${image}/${fe}/legacy-javascript/lib/" || die
	popd >/dev/null || die

	local pkg
	for pkg in "${REPLACED_PACKAGES[@]}"; do
		echo "${pkg}" >> "${WORKDIR}/image/VERSIONS" || die
	done
}

src_test() {
	# Upstream's test suites need their dev dependencies; check that every
	# bundle loads and does something.
	local i=${WORKDIR}/image/tree bidi=third_party/chromium-bidi/node_modules webui=third_party/node/node_modules
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
