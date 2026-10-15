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

# Sources: id, GitHub repository, then a commit, or a tag and the commit it points
# to (src_unpack checks that each archive was made from that commit).
JS_SOURCES=(
	# terser/dist/bundle.min.js
	"terser terser/terser v5.37.0 58ba5c163fa1684f2a63c7bc19b7ebcf85b74f73"
	"gen-mapping jridgewell/gen-mapping v0.3.3 7626d310002df682012dc29bdfa4d674027f1538"
	"resolve-uri jridgewell/resolve-uri v3.1.1 8189d8d3a10bccc7c7b425ca07aeb86999e90bcb"
	"set-array jridgewell/set-array v1.1.2 f1d9855dd0d7e34bcc02307249783589ed715661"
	"source-map jridgewell/source-map v0.3.5 25673db757fd740449d5f45d96648f30448662be"
	"sourcemap-codec-1.4.15 jridgewell/sourcemap-codec v1.4.15 f3d95b857d24fc3f1692dec4d1ed724fe12488a3"
	"trace-mapping jridgewell/trace-mapping v0.3.19 5ccfcfeeee9dfa3b13567bb0f95260ea32f2c269"
	# chromium-bidi: @rollup/plugin-node-resolve
	"node-resolve rollup/plugins node-resolve-v16.0.3 764910a09d57e3b55cb4d027765b717a50341253"
	"pluginutils rollup/plugins pluginutils-v5.3.0 ca4780995433fb55b709c91f28d5c13066ebf026"
	"deepmerge TehShrike/deepmerge v4.3.1 5b87756a5671635679001cbac72aa42f23472c81"
	"is-mergeable-object TehShrike/is-mergeable-object v1.1.0 0d3d3c837e74b03191850544abd1abf23e94ae89"
	"is-module component/is-module 1.0.0 b2179523cda03bb6d5aff525bfd6cabf2d22b13c"
	"resolve browserify/resolve v1.22.11 f24742ccc61eb20fadd50c3481321dfcdf95d77a"
	"is-core-module inspect-js/is-core-module v2.16.1 7c4284853357b2fcd49d42010d5a2b8a8420905f"
	"hasown inspect-js/hasOwn v2.0.2 d00d35005baf16a33d691a13f8ad627f35040742"
	"function-bind Raynos/function-bind v1.1.2 40197beb5f4cf89dd005f0b268256c1e4716ea81"
	"path-parse jbgutierrez/path-parse v1.0.7 9f1db2802ffbc572e6b447f66126697e33b0055e"
	"supports-preserve-symlinks-flag inspect-js/node-supports-preserve-symlinks-flag v1.0.0 1f7cac19c0c298cf40b3f2f3c735477ad579ac61"
	"estree-walker-2 Rich-Harris/estree-walker v2.0.2 3ac96d685ddedb1701009945d9911fa41d60b0ce"
	"picomatch-4 micromatch/picomatch 4.0.4 e5474fc1a4d7991870058170407dda8a42be5334"
	# chromium-bidi: rollup-plugin-cleanup
	"rollup-plugin-cleanup aMarCruz/rollup-plugin-cleanup 3.2.1 4988f5428afd7ed313f1e5c5fcd3634df12eb6c7"
	"js-cleanup aMarCruz/js-cleanup 1.2.0 8bff91d919147b8f26bb0d98d4581cb6eb0faa56"
	"rollup-pluginutils rollup/rollup-pluginutils 2.8.2 3038972a1295c9e8a251a6bd859aef7fd5906594"
	"estree-walker-0 Rich-Harris/estree-walker v0.6.1 090224a0273d85fb74a1006dd1171bde734f1ed7"
	"micromatch micromatch/micromatch 4.0.2 bdd32f41e07f401b12ae7c8b04d22b275c88c84b"
	"braces micromatch/braces 3.0.2 25791512d219b284bd62bb068cae85d8e68bd05b"
	# 7.0.1 isn't tagged; npm's gitHead for it
	"fill-range jonschlinkert/fill-range 39f421b499d5c97b62e955c179fa34c062aab2a5"
	"to-regex-range micromatch/to-regex-range 5.0.1 1191a52afa82f52983e684ceeb8f8d3a150fa881"
	"is-number jonschlinkert/is-number 7.0.0 98e8ff1da1a89f93d1397a24d7413ed15421c139"
	"picomatch-2 micromatch/picomatch 2.0.7 9eb9a71780035c5c3e2c1e67eafa3d967f2289b2"
	"magic-string-0.25 Rich-Harris/magic-string v0.25.9 69336fccbb46e721d58faa5c7a0d0b7ed6ee09d2"
	"sourcemap-codec-1.4.8 Rich-Harris/sourcemap-codec v1.4.8 b549c1ee22f79bdf777d7bfe6471fe4293cd6391"
	"perf-regexes aMarCruz/perf-regexes 1.0.1 1fa787b085ddd4c58514c455472f37eb421eb924"
	"skip-regex aMarCruz/skip-regex 1.0.2 1ce5518d347a519388edc965dc2537f80c1deae3"
	# chromium-bidi: rollup-plugin-license
	"rollup-plugin-license mjeanroy/rollup-plugin-license v3.7.1 6faf8f51c7e5f48f1a8dc0be313b038c054a84af"
	"commenting 3rd-Eden/commenting 1.1.0 b63e05164d3a63018ad6ec2f2ee914b43c02d32f"
	"fdir thecodrr/fdir v6.5.0 14c678e70e714f32e511cdf24c8d2392ac25ba0f"
	"lodash lodash/lodash 4.18.1 cb0b9b9212521c08e3eafe7c8cb0af1b42b6649e"
	"magic-string-0.30 Rich-Harris/magic-string v0.30.21 410fd4d080d8bf0b5be900c16c8ba11276fd8749"
	"sourcemap-codec-1.5.5 jridgewell/sourcemaps sourcemap-codec/1.5.5 e53a6dfb18f404a0cc77d1c92aa4bcc11dac16a6"
	"moment moment/moment 2.30.1 485d9a7d709bd5f3869a7ad24630cf0746d072dc"
	"package-name-regex dword-design/package-name-regex v2.0.6 9deb185730a583405231ece789b688f3d2312de6"
	"spdx-expression-validate kemitchell/spdx-expression-validate.js v2.0.0 a7c4716bba138dcfdde306be2ad2c99e95877784"
	"spdx-satisfies kemitchell/spdx-satisfies.js v5.0.1 77bab7cf13401bce9773ada2c39137fc21a33444"
	"spdx-compare kemitchell/spdx-compare.js v1.0.0 cb7853325dc0aafdeeec932590781c1dd4b40ff7"
	"spdx-expression-parse jslicense/spdx-expression-parse.js v3.0.1 d7daff468ce455f636838a8375d8699cf36be64d"
	"spdx-ranges kemitchell/spdx-ranges.js v2.1.1 e943260950eecbb8c96d05cd2a3fffc0c0d73604"
	"spdx-license-ids jslicense/spdx-license-ids v3.0.22 f369a267a02ecd01efd24e97dde27dd167706bc6"
	"spdx-exceptions kemitchell/spdx-exceptions.json v2.5.0 3aa64bec339abc6a3eca00c3436aaa7e154b8799"
	"array-find-index sindresorhus/array-find-index v1.0.2 983f4c827ad22fa0353182b1ddcbfaecd4412859"
	# WebUI's CSS minifier: postcss-selector-parser
	"postcss-selector-parser postcss/postcss-selector-parser v6.1.2 1b1e9c3bc10ccc3bc5f07a987caa7f2684c0b52f"
	"cssesc mathiasbynens/cssesc v3.0.0 cb894eb42f27c8d3cd793f16afe35b3ab38000a1"
	"regenerate mathiasbynens/regenerate v1.4.2 11567339f40fd262435934d544885bc047cb4220"
	"util-deprecate TooTallNate/util-deprecate 1.0.2 475fb6857cd23fafff20c1be846c1350abf8e6d4"
	# ts-proto (protoc plugin generating TypeScript); untagged ones by npm's gitHead
	"ts-proto stephenh/ts-proto v2.7.7 65dc52fdc390c4a6a373fa3212bac58aaa480713"
	"ts-proto-descriptors stephenh/ts-proto f828a779495538cdd5719d23d28d6697d86bdeb3"
	"ts-poet stephenh/ts-poet bda410a132645d243090bdd01cdb6559e4964ab2"
	"case-anything mesqueeb/case-anything 4ff82505a22d1f71fc2528ed8f9a5691ca1d0511"
	"bufbuild-protobuf bufbuild/protobuf-es v2.2.5 6a81dc6f398f44ba1c6f7fb7c48a0856ed07566d"
	# DevTools: CSS minification (cssnano) and SVG optimization (svgo)
	"entities fb55/entities v4.5.0 61afd4701eaa736978b13c7351cd3de9a96b04bc"
	"domelementtype fb55/domelementtype v2.3.0 687e8625885a3656d44c41e7640c86925417d91f"
	"domhandler fb55/domhandler v5.0.3 767c031b7db3ed79cde865dc368b2de930ae1934"
	"dom-serializer cheeriojs/dom-serializer v2.0.0 add044a9615207b80a389b44619e2ad4cc4b8cae"
	"domutils fb55/domutils v3.2.2 0ab8bcf1ecfc70dfc93291a4cb2496578ac25e9c"
	"nth-check fb55/nth-check v2.1.1 639fd2a4000b69f82350aad8c34cb43f77e483ba"
	"css-what fb55/css-what v7.0.0 47ba76df188c15e7c4e2ec314ecd9fe5337a6141"
	"css-select fb55/css-select v6.0.0 7bb0cda6593c9a69f4c9a5d2b076f26b0fe508c2"
	"css-tokenizer csstools/postcss-plugins 9256e22798ff1360e178912af9b57d59d0601c99"
	"baseline-browser-mapping web-platform-dx/baseline-browser-mapping v2.11.21 0e5ed80e21dda23cac3dc1f6ec37e6b5fc4ea734"
	"caniuse-api MoOx/caniuse-api 4.0.0 9a2a431214f5a5da3265afe31901bf664b3f3d05"
	"postcss-selector-parser-7 postcss/postcss-selector-parser 7.1.6 4eb3468e754f9f94d2092d103767bae98aa41438"
	"nanoid ai/nanoid 3.3.18 9ad98052b316c5e707f8098ace509d2ae165e54d"
	"colordx dkryaklin/colordx @colordx/core@6.4.0 2adb9dc85cecff9506629ebb7d0a9d576ccfcb25"
	# DevTools: build scripts (yargs, ...), esbuild's JavaScript API
	"yargs yargs/yargs v18.1.0 8878a894111e3fe7c98d84af546c0f34fa017492"
	"y18n yargs/y18n v5.0.5 b64ae70b3cf3d6fd95206f5913a2b3f2b3524f9c"
	"cliui yargs/cliui v9.0.1 2737977df41e728bd8c7d3ca0658498273cecce5"
	"yargs-parser-22 yargs/yargs-parser yargs-parser-v22.0.0 553c808cb0a8730980cacd23b8b8e3038ab7c61f"
	"escalade lukeed/escalade v3.2.0 fa5be167391581849cff04dbc75dc2978744b642"
	"get-caller-file stefanpenner/get-caller-file v2.0.5 2383bf9e98ed3c568ff69d7586cf59c0f1dcb9d3"
	"js-yaml nodeca/js-yaml 5.4.1 e5a3ba0efee53629b979f784cd53736f89ea61b6"
	"uuid uuidjs/uuid v14.0.0 7c1ea087a8149b57380fc8bb7f68c3a215cb6e4b"
	"esbuild evanw/esbuild v0.28.2 609683d892977362a0f99026cb74b96263d728a9"
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
	"json5 json5/json5 v2.2.3 c3a75242772a5026a49c4017a16d9b3543b62776"
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
	"terser-5.34 terser/terser v5.34.1 d3eac90c7573c80431109b8c1cc15de5b7cca6aa"
	"plugin-replace rollup/plugins replace-v5.0.7 7278248d5a87295df368116b4effe0d23f17964e"
	"plugin-virtual rollup/plugins virtual-v3.0.2 cdf9113a14c116520ef9f937a1151797666bbfa2"
	"pluginutils-5.1 rollup/plugins pluginutils-v5.1.0 02f9724ed74da05410dd500fc336cfb497b4563f"
	"magic-string-0.30.7 Rich-Harris/magic-string v0.30.7 44b0407a6a0812f50bcaf2e0ab86081cd1015775"
	"picomatch-2.3 micromatch/picomatch 2.3.1 5467a5a9638472610de4f30709991b9a56bb5613"
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
	"format-message format-message/format-message v6.2.0 ef02f024d2f3c5c0f0cd21a618f78c7d12d03fb3"
	"robots-parser samclarke/robots-parser dd032ec3da65e49bf2ba8d7224bd20883ef8ff34"
	"soft-navigation adamraine/lighthouse-plugin-soft-navigation b924172990ad3688da41b8f4cce22ede3c39dce6"
	"resolve-1.22.10 browserify/resolve d1e73275da515a3bc5d0064f15ebf09b3947199b"
	"magic-string-0.27 Rich-Harris/magic-string 69336fccbb46e721d58faa5c7a0d0b7ed6ee09d2"
	"builtin-modules sindresorhus/builtin-modules 0d234f3ad3965c57d8cc5b9ca198c505fe032452"
	"escape-string-regexp sindresorhus/escape-string-regexp 71083e89129bcf72a10656508de5442d3f97966d"
	"lh-fast-memoize formatjs/formatjs @formatjs/fast-memoize@2.2.0 61bb35ed3a3cfc0e225077b2f5697aca85a2cee3"
	"lh-icu-messageformat-parser formatjs/formatjs @formatjs/icu-messageformat-parser@2.6.2 6fa9d110465d334cae9a61edc1d90481c6bd9367"
	"lh-icu-skeleton-parser formatjs/formatjs @formatjs/icu-skeleton-parser@1.6.2 6fa9d110465d334cae9a61edc1d90481c6bd9367"
	"lh-intl-messageformat formatjs/formatjs intl-messageformat@10.5.3 5ee5777cf920767229cd02bd3cf2184a1b109766"
	"ajv-formats ajv-validator/ajv-formats 1fb3fa7d967f919ff924bb34aef73a2f39ab0de3"
	"ajv ajv-validator/ajv 0fba0b8e649909613cfce0999b149cd08f4a4987"
	"fast-deep-equal epoberezkin/fast-deep-equal d807ffc5013e710deb1c63d463a03f729bcd144d"
	"json-schema-traverse epoberezkin/json-schema-traverse 6b45983cd76270042cc79527da5c8972f13599ec"
	"fast-uri fastify/fast-uri 6f970b2951fd896aa0f3a7ff28eeb6640c137d33"
	"require-from-string floatdrop/require-from-string d1575a49065eb7a49b86b4de963f04f1a14dfd60"
	"csp-evaluator google/csp-evaluator 9189d07a58c40490fd21190541a9fbfd8fc3ad4b"
	"marky nolanlawson/marky 2fb66b09e6b19451fded98754a8a8f0215e15880"
	"speedline paulirish/speedline v1.4.3 1ad15e067d906d04aa35481c2a40e10db01aca58"
	"tldts remusao/tldts 200a338cf46f31c27ec2ab16914d683041f8e053"
	"third-party-web patrickhulce/third-party-web d60863a2ea913ed26ae0446296a0cb1cc6c71291"
	"lodash-4.17 lodash/lodash 4.17.21 f299b52f39486275a9e6483b60a410e06520c538"
	"polyfill-node FredKSchott/rollup-plugin-polyfill-node eb507a21ad82236255988548dea6120d7a277de2"
	"buffer-es6 calvinmetcalf/buffer-es6 3173686b2010f64a0f6286b4e1d5c6056d230fd9"
	"process-es6 calvinmetcalf/node-process-es6 6c218e5f68b918226380abec10c08587f240503e"
	"parse5-5 inikulin/parse5 v5.1.0 ac0c1b2882a25e43e8cbb9099bb3e3f6fdea6718"
	"dot olado/doT 6adbd819970d9093aa2ea24fcf56c7e370d9a468"
	"js-library-detector johnmichel/Library-Detector-for-Chrome e56bea2d4e0bf483a7255e5c51f4407923618f43"
	# axe-core 4.13.0 (Lighthouse inlines axe.min.js), its build tools and the packages it
	# bundles (versions from its pnpm-lock.yaml); emoji-regex's pattern is generated from
	# Unicode's emoji-test.txt
	"axe-core dequelabs/axe-core v4.13.0 1cc54b900413660610180d631feb73c9e74f4dc9"
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
	"lru-queue medikoo/lru-queue v0.1.0 08dde64384699438cc82150e2e779fc0ce770f6c"
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

inherit edo git-archive

DESCRIPTION="Generated files of Chromium's npm packages, built from source"
HOMEPAGE="https://www.chromium.org/"

# _js_source <spec>: sets src_id, src_repo, src_ref, src_commit, src_uri, src_distfile
# and src_dir (GitHub's archive directory: repository name, then the tag without a
# leading "v" and with "/" and "@" as "-", or the commit; Forgejo's: the
# repository name).
_js_source() {
	read -r src_id src_repo src_ref src_commit <<< "${1}"
	[[ ${src_ref} =~ ^[0-9a-f]{40}$ ]] && src_commit=${src_ref}
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
unset _spec src_id src_repo src_ref src_commit src_uri src_distfile src_dir
# webdriver-bidi-protocol's type declarations (puppeteer's TypeScript inlines its const
# enums; the package has no JavaScript, and its sources are generated from the WebDriver
# BiDi specification)
SRC_URI+="
	https://registry.npmjs.org/webdriver-bidi-protocol/-/webdriver-bidi-protocol-0.4.3.tgz
"
# DevTools sources, as files from its git repository: "@<commit>", then "<path in
# front_end/> <git blob ID>" for files at that commit (src_unpack checks the blob IDs
# and puts the files in devtools-frontend-<commit>/front_end/)
DEVTOOLS_FILES=(
	# what Lighthouse's build-cdt-lib.js and build-cdt-strings.js generate files from,
	# at the revisions its committed outputs were generated from
	@3f890ceb7ad70b5831621393574401b6e474fc73
	"core/sdk/SourceMap.ts fe0eaf38b1e71c1df81f48635f10cc490ea7b20b"
	"core/common/ParsedURL.ts 100d9ec45f0cc74590aa5fd86422447eeb55d4b9"
	@ced63b5ae0c00cd5e0d86ab47daeaa2072016ab6
	"generated/Deprecation.ts 6184d2330e845cb15cf1b6b6da68612a2cd73abb"
	"panels/application/components/BackForwardCacheStrings.ts e4bc353e2ac11dfbfab80944e778226e57fc5678"
	# @paulirish/trace_engine 0.0.65 (Lighthouse's copy of DevTools' models/trace and
	# what it imports) was published compiled from this commit, 25 minutes before it:
	# its source maps hold these files, with files/lighthouse-trace-engine-0.0.65-packaging.patch
	@845cad7f273101ef8ae5a8e741dccd78f6f14724
	"core/platform/api/api.ts 9fe7671866667d653970ff9d90b14f63a28a5bdc"
	"core/platform/api/HostRuntime.ts d51c587c9c0130c3f675e97f306ccfe582712495"
	"core/platform/ArrayUtilities.ts 93e8aacf752f2edafcb1c91573cbda11a685a345"
	"core/platform/Brand.ts 705164700e28c788a598127ee4decac71b19161f"
	"core/platform/browser/browser.ts 9fe7671866667d653970ff9d90b14f63a28a5bdc"
	"core/platform/browser/HostRuntime.ts 25c2bfe2e8d9d90a56f30b3444c3f8faa150ed01"
	"core/platform/Constructor.ts 88c77f0432cf2bcc153aa9218384b0a52efe8a8d"
	"core/platform/DateUtilities.ts 56dd6747085cff884e1a45aed9967bf4b0871713"
	"core/platform/DevToolsPath.ts ec6ff0d7301968f288658cc9ef084d66163e496d"
	"core/platform/HostRuntime.ts 989b3c0b9dff07311e3a2d420a6aa22952c08e98"
	"core/platform/KeyboardUtilities.ts b72042193118a49f5ebb4605a5c981b8d2b2e905"
	"core/platform/MapUtilities.ts cc7e3345344935fda67b04ac1323bc2701c95d36"
	"core/platform/MimeType.ts 776e937188757adb385605cb1e2b8066af71a6c2"
	"core/platform/node/HostRuntime.ts 09d3df9c508d5b95de109b7c376ef00ed052d44a"
	"core/platform/node/node.ts 9fe7671866667d653970ff9d90b14f63a28a5bdc"
	"core/platform/NumberUtilities.ts 5343c9f55d0252d1f3ac29a1cacd9019c2e01fb9"
	"core/platform/platform.ts 590e05987f83e5782db4da96bc7c01182080ff11"
	"core/platform/StringUtilities.ts d02659d8a7d2dd21833b982f5cf22ba7ca86d8c4"
	"core/platform/Timing.ts 079816ac479af039efd2928bf74025d190f4858c"
	"core/platform/TypedArrayUtilities.ts 136a8bde5bf4ef676c01f5fc6418b7c0d6974b2e"
	"core/platform/TypescriptUtilities.ts 0012118a98a320dd38116e28d7726639ba25a2f9"
	"core/platform/UIString.ts 64f760f091d36fc8a2d39ca5cda1742a3e3f08e4"
	"core/platform/UserVisibleError.ts 877ef6e414a1ed342c81ac3436a2a02249f60abe"
	"generated/protocol.ts ad313cb8150bedd3ee358b5386094db33db11048"
	"models/cpu_profile/CPUProfileDataModel.ts 3f64e414161a2b3f4d3973301fe4da77269935c6"
	"models/cpu_profile/cpu_profile.ts 6282177cb2acb2614a737856bf37fce6d59224e6"
	"models/cpu_profile/ProfileTreeModel.ts 669e0724cf2374c8be49202847a957d7fa6cf775"
	"models/trace/EntityMapper.ts 376b0bfb157c25c4ea4ba8927b3d52fd60eb84cd"
	"models/trace/EventsSerializer.ts ae3c619328ca9befa02bd6d54c99013fb2c361eb"
	"models/trace/extras/extras.ts 488f507b0e663597b9cb5d8ed7cbc204be8c40fa"
	"models/trace/extras/FilmStrip.ts d5c5df1bea2403a73c3ff82d4e713a7b0a038ee0"
	"models/trace/extras/Initiators.ts 26908361e3a3c11b88efb2981b7528d2d06c1cf6"
	"models/trace/extras/MainThreadActivity.ts 555bb5a57bcccce69209cbb8d81a0bb1a485dfdb"
	"models/trace/extras/ScriptDuplication.ts e59844e202f66894ecec1712bbabb54dc692dbd4"
	"models/trace/extras/StackTraceForEvent.ts 3448dbc6963e9fb8dbfa6fa232d6646ca0f7518a"
	"models/trace/extras/ThirdParties.ts 3496403551a63e964e38e62f3a79b66febcc31be"
	"models/trace/extras/TraceFilter.ts ca13f7a91d6b08307389d1183ea7e9a397bec62b"
	"models/trace/extras/TraceTree.ts 691f0dc1e03d1dece1596ea2b324b76a434cb303"
	"models/trace/handlers/AnimationFramesHandler.ts eee68e6b30cb814ad7e7dd1ee012fa9975fc0683"
	"models/trace/handlers/AnimationHandler.ts 8afd104ad15864161281f5157ec273eaa4ff4d68"
	"models/trace/handlers/AsyncJSCallsHandler.ts 8c533b01761e2a892563ac20698dc8c7e79dbd01"
	"models/trace/handlers/AuctionWorkletsHandler.ts 9069c3ce051e3007b2c637e0be98f91b85e49156"
	"models/trace/handlers/DOMStatsHandler.ts 56249aef636a965a8cb888d7696adbd69e4d056b"
	"models/trace/handlers/ExtensionTraceDataHandler.ts bbc726d3bd18c38ed6e37c9c79b028c188d536fc"
	"models/trace/handlers/FlowsHandler.ts e71f7ebaebf1eac979ff24d3248a4fecfa5709a3"
	"models/trace/handlers/FramesHandler.ts 181b4ed08c0fb4a84f7fd0a86610f761554a05ab"
	"models/trace/handlers/GPUHandler.ts b3b4b1dad6417c48abb7499f60b201215f21881d"
	"models/trace/handlers/handlers.ts dec4f2e5b117897391b8b2b6e7e9a091d4cfc86d"
	"models/trace/handlers/helpers.ts 62c5773f9abf1613d20cd8d2cf04fe7791f3d209"
	"models/trace/handlers/ImagePaintingHandler.ts 33e72884cc6215c4a82581167d913e15215749ca"
	"models/trace/handlers/InitiatorsHandler.ts 0f2c0afd1ac22b30a332dca488bb8dc77f9c4981"
	"models/trace/handlers/InvalidationsHandler.ts 31cb7ba4fc3f2e6d3ea09ed1b25645643c21fe44"
	"models/trace/handlers/LargestImagePaintHandler.ts b620283a0b9ed8f8386b45002c542bbfd4eb6b46"
	"models/trace/handlers/LargestTextPaintHandler.ts a93352baedf4ef210c3d68b02d160f01fb09a2ea"
	"models/trace/handlers/LayerTreeHandler.ts 86fa625e71c1007880f8849181c398dec0fcdd46"
	"models/trace/handlers/LayoutShiftsHandler.ts 98a2bb0eb8c522e6659fbd986442fd0d26eea280"
	"models/trace/handlers/MemoryHandler.ts 53c25ca0b064b8d52c267344c40833bb85d96f1e"
	"models/trace/handlers/MetaHandler.ts d87064d7020deff673ac344d2417d4373389e80a"
	"models/trace/handlers/ModelHandlers.ts c7a538426fde43282b7e9ced5fe8d6a16587d14f"
	"models/trace/handlers/NetworkRequestsHandler.ts 30ed3c3ba4b57cf0a83fd8ad242dff66ecd2d76e"
	"models/trace/handlers/PageFramesHandler.ts 3d80e1f267feffbb30ad00e571db9451e5a59a2d"
	"models/trace/handlers/PageLoadMetricsHandler.ts 0784a51c54c627264f1e566f5ddfcda3fdea4281"
	"models/trace/handlers/RendererHandler.ts 1e4b3d5399261bd1cf43aa5fd07bbbfbff1ba91d"
	"models/trace/handlers/SamplesHandler.ts 880ba4a6a16c57dfd057d1a4a13cd42814cc3bf3"
	"models/trace/handlers/ScreenshotsHandler.ts 4965b595926733f139f85ca27758d592133b686c"
	"models/trace/handlers/ScriptsHandler.ts 5449471dcae747d74356568e6f57afdf057a0008"
	"models/trace/handlers/SelectorStatsHandler.ts 01e451020d236ac6d7a2680ff35ddcaf28a03b82"
	"models/trace/handlers/Threads.ts 563309d082c7481ce54a5756dd6fa6e09cb37ffa"
	"models/trace/handlers/types.ts 68f064a215865ac8446324a6c51d3c2c5d82c733"
	"models/trace/handlers/UserInteractionsHandler.ts fadf26dc46129fd81b6a8cf83c0f82cecddd3594"
	"models/trace/handlers/UserTimingsHandler.ts a57a5e3e8f18181c2b55576b2dce78d56187f82d"
	"models/trace/handlers/WarningsHandler.ts 24751dfa3378432e2a1c566001f730ad5ece2ce9"
	"models/trace/handlers/WorkersHandler.ts c296397819e91bd04492160c51ee1014ae12d3fb"
	"models/trace/helpers/Extensions.ts a559898966707065fff5159bac53cb55bcf9b245"
	"models/trace/helpers/helpers.ts 78ede7f105a87abf4ef530b11b77c44e0e3661b5"
	"models/trace/helpers/Network.ts 6b713d45427f095934035de6a391ca87d26bf625"
	"models/trace/helpers/SamplesIntegrator.ts a3b1cfcd98c3d35b07fd68665d0a947727815d78"
	"models/trace/helpers/SyntheticEvents.ts a3e21be8a50cd4bca74336e2cc827697a0cd50e6"
	"models/trace/helpers/Timing.ts c6e3d033752ac4623be08d319ea9a77ddd22c965"
	"models/trace/helpers/Trace.ts b3b7c8c4ad3237ef37d9be7e43747b7d62e039a0"
	"models/trace/helpers/TreeHelpers.ts 0cfcf65e7dbab57f813f19d88b3b12e3d0e69a3e"
	"models/trace/insights/Cache.ts c6997a959336756eb38a015753537bb65975a7f2"
	"models/trace/insights/CharacterSet.ts 80055d1984b9e21a8c8e85a65d1bf677ca060146"
	"models/trace/insights/CLSCulprits.ts dab3653dedcb4f4e3375edee5392e90d27ad2657"
	"models/trace/insights/Common.ts 6c89370d7eca24ce2f27eaec80d04c7c28305f18"
	"models/trace/insights/DocumentLatency.ts 5bd36268f79a5656c4b9c62bf916a491bff74bd0"
	"models/trace/insights/DOMSize.ts 661be72e1c8151678be3a8cc484456e29a027093"
	"models/trace/insights/DuplicatedJavaScript.ts d6568dcc4e55bf8b30cef5b1981cf1b2a3686228"
	"models/trace/insights/FontDisplay.ts f6a01985b05f1d6076648835bf856ebe08fb2de2"
	"models/trace/insights/ForcedReflow.ts 6e3df635a301639b05e9a3a9de2aef82609e7507"
	"models/trace/insights/ImageDelivery.ts 95bf474c88f52b177be00cc2ff4accd9b6e00eaf"
	"models/trace/insights/INPBreakdown.ts 1cc48128e732ea6c8d96d4e6d6b0e9c50d8ebd36"
	"models/trace/insights/insights.ts 9576d05aed1839fc33655e8ec3c195fddf21b0f6"
	"models/trace/insights/LCPBreakdown.ts 31a368d28c52a1e83356e12cf3402df04861a88e"
	"models/trace/insights/LCPDiscovery.ts 9508640a9c83b7963711c2f9f5f5912ada28a4d0"
	"models/trace/insights/LegacyJavaScript.ts 2823128e768420f132bbb59196387a2b6ed6d0b6"
	"models/trace/insights/Models.ts dd287e4065e68ae7e2e340426f75223145a44178"
	"models/trace/insights/ModernHTTP.ts a948a43455a806296ef027fcb21d3dc2f97dd433"
	"models/trace/insights/NetworkDependencyTree.ts d4cb4c2eff5cacceafd0a0d8be09585809ca087a"
	"models/trace/insights/RenderBlocking.ts c5e47f383f709e13b47eba443a6d68acf0e96221"
	"models/trace/insights/SlowCSSSelector.ts a196cb6b0ac9efcece1e7bdee2b50a8b0e5c49a5"
	"models/trace/insights/Statistics.ts d078bd5ba5799157efb7a689b95127352e27d4a0"
	"models/trace/insights/ThirdParties.ts 56b350203b82d30304edfab874c7352fa1176d82"
	"models/trace/insights/types.ts 07ce5d8c5e18ccbbad2ebf0d3da773abdd33074c"
	"models/trace/insights/Viewport.ts 4de60b563a9687f3f82b49cf1b7268e4a6c7050c"
	"models/trace/LanternComputationData.ts 9ae47dc232e035191af184757b935baa9fc765d0"
	"models/trace/lantern/core/core.ts ef8666acfb1812d94123086b955ae1d63441037c"
	"models/trace/lantern/core/LanternError.ts 3148a7b0d96a8a48efd2a1486f5953f697431e91"
	"models/trace/lantern/core/NetworkAnalyzer.ts b6a3d96c9bd193150dba002c3b40b261fac2b9a0"
	"models/trace/lantern/graph/BaseNode.ts 00b718b46932c296e1ebd0eb18e732e044bae9ba"
	"models/trace/lantern/graph/CPUNode.ts 9c5ff34a5b78c82f2de75ebe6a0eeba5bdf7fbe5"
	"models/trace/lantern/graph/graph.ts 88a12fe89d681c205904296c9dab321807a3b04b"
	"models/trace/lantern/graph/NetworkNode.ts 1ee5b41a1a14a2f5c543ccba14c530c7932891b2"
	"models/trace/lantern/graph/PageDependencyGraph.ts cb75fd2bf406316d0bc5b8d55f67e87931814945"
	"models/trace/lantern/lantern.ts 0f031a504cd4d391185bab8fb01b68565d876863"
	"models/trace/lantern/metrics/FirstContentfulPaint.ts 92cfa096ef5d7b98422da377f0f19efa16396e34"
	"models/trace/lantern/metrics/Interactive.ts 1d384a75a7afe44df8b70e4f0383821407c8600d"
	"models/trace/lantern/metrics/LargestContentfulPaint.ts f7b93dd087629a4444110ef359a366caa38adc47"
	"models/trace/lantern/metrics/MaxPotentialFID.ts 50df995c80fec5a3e2079feb7e62e343ec98d6da"
	"models/trace/lantern/metrics/metrics.ts 63d0d3537fbcd3497347d496579d69410c597faa"
	"models/trace/lantern/metrics/Metric.ts 65008ab295062e540ac923fe8853aaf9fccf8cfa"
	"models/trace/lantern/metrics/SpeedIndex.ts c7edd004d6da6fd556a3e860471db278e2dc8367"
	"models/trace/lantern/metrics/TBTUtils.ts 931e2a4d1d25f6f0c5e6deba7b9caaa766196504"
	"models/trace/lantern/metrics/TotalBlockingTime.ts eec05dbc194b7ca88144356d271624ca6b99c989"
	"models/trace/lantern/simulation/ConnectionPool.ts 543538ff551ec58d69327b2616bc734a46f14526"
	"models/trace/lantern/simulation/Constants.ts d96a1b699e7249a10c2b2d89fd31f9751f6438a1"
	"models/trace/lantern/simulation/DNSCache.ts 9d08567c5fd55f88efd3a274bde862bcebbe6643"
	"models/trace/lantern/simulation/SimulationTimingMap.ts d7099a9d3cf0c3c61a229474d4fb1317ed133964"
	"models/trace/lantern/simulation/simulation.ts b15201d730fc6ca93b13274c3f75f37256f52a72"
	"models/trace/lantern/simulation/Simulator.ts 60dc5fd39ad7ea941f9cd3f1c0a6d2d550ccfa98"
	"models/trace/lantern/simulation/TCPConnection.ts db4daea24b11385f35020f6e470323892b484077"
	"models/trace/lantern/types/Lantern.ts 1d7640732b8d7357ded4739f68c19a3535dfb8db"
	"models/trace/lantern/types/types.ts 57325ab899a824705dd9b636b9634d803abea7fe"
	"models/trace/ModelImpl.ts a4735754995d0596dcd29d964f43ac38bf699ff6"
	"models/trace/Name.ts be2f3961af68a2f5bb698abc6e5a16e8769d7025"
	"models/trace/Processor.ts a57685278ab797fc92f488452ea2574fe1dc4160"
	"models/trace/Styles.ts 0ebc659691c825cc71f6b09169a13ac884a6b65b"
	"models/trace/trace.ts 353d7e2f32f9645e4c8fc5ba1685273167e391c2"
	"models/trace/types/Configuration.ts 4008475d5e62b0428645abd34568b30d2d5da8a8"
	"models/trace/types/Extensions.ts efca7c2be2216e58e380f34755443f7133fce8cb"
	"models/trace/types/File.ts 2928aa9780112e5411bf3241e68dcc94263808c4"
	"models/trace/types/Overlays.ts 32f4b728d425b48408ae52a4a93fc14a5cb0fcaa"
	"models/trace/types/Timing.ts cd4f49a763170f697cc5c46364eac444fdd42488"
	"models/trace/types/TraceEvents.ts 46bb3bb5e36595582fa7f94d153690f2063e08b6"
	"models/trace/types/types.ts 9babd35e04d109633539f6572d919211479eb30d"
)
# _devtools_files <function>: calls <function> <commit> <path> <blob ID> <distfile> for
# each of DEVTOOLS_FILES
_devtools_files() {
	local f commit path blob
	for f in "${DEVTOOLS_FILES[@]}"; do
		if [[ ${f} == @* ]]; then
			commit=${f#@}
			continue
		fi
		read -r path blob <<< "${f}"
		"${1}" "${commit}" "${path}" "${blob}" "devtools-frontend-${commit:0:8}-${path//\//-}"
	done
}
_devtools_uri() {
	SRC_URI+=" https://raw.githubusercontent.com/ChromeDevTools/devtools-frontend/${1}/front_end/${2} -> ${4}"
}
_devtools_files _devtools_uri
unset -f _devtools_uri
# @paulirish/trace_engine's package files that aren't compiled output (package.json,
# tsconfig files, locales, small shims); Unicode's emoji data
SRC_URI+="
	https://registry.npmjs.org/@paulirish/trace_engine/-/trace_engine-0.0.65.tgz
		-> paulirish-trace_engine-0.0.65.tgz
	https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt -> unicode-17.0.0-emoji-test.txt
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

# _devtools_unpack <commit> <path> <blob ID> <distfile>
_devtools_unpack() {
	local id dest=${WORKDIR}/devtools-frontend-${1}/front_end/${2}
	id=$({ printf 'blob %d\0' "$(stat -L -c %s "${DISTDIR}/${4}")" && cat "${DISTDIR}/${4}"; } | sha1sum) || die
	[[ ${id%% *} == "${3}" ]] || die "${4}: git blob ${id%% *}, expected ${3} (${2} at ${1})"
	mkdir -p "${dest%/*}" || die
	cp "${DISTDIR}/${4}" "${dest}" || die
}

src_unpack() {
	local spec src_id src_repo src_ref src_commit src_uri src_distfile src_dir
	for spec in "${JS_SOURCES[@]}"; do
		_js_source "${spec}"
		[[ -n ${src_commit} ]] || die "${src_id}: no commit for ${src_ref}"
		git-archive_verify "${src_distfile}" "${src_commit}"
	done
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
		esac
	done
}

# _dir <id>: the unpacked directory of a source
_dir() {
	local spec src_id src_repo src_ref src_commit src_uri src_distfile src_dir
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
	edo node "${FILESDIR}/emoji-test-regex-pattern.mjs" "${DISTDIR}/unicode-17.0.0-emoji-test.txt" \
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
	# @paulirish/trace_engine: DevTools' TypeScript it was compiled from (the files its
	# source maps name), with the edits DevTools' unpublished packaging script makes
	# (the patch: to the sources; the edits script: to the compiled package), compiled
	# as one program (for const enums, as in DevTools' build). Modules outside the
	# package are missing, so tsc reports type errors; the JavaScript it emits doesn't
	# depend on them.
	local te_src="${T}/trace_engine" te="${lh_nm}/@paulirish/trace_engine"
	local te_dt="${WORKDIR}/devtools-frontend-845cad7f273101ef8ae5a8e741dccd78f6f14724/front_end"
	local te_npm="${WORKDIR}/npm-paulirish-trace_engine-0.0.65"
	edo node "${FILESDIR}/lighthouse-trace-engine-sources.mjs" copy "${te_npm}" "${te_dt}" "${te_src}"
	pushd "${te_src}" >/dev/null || die
	eapply "${FILESDIR}/lighthouse-trace-engine-0.0.65-packaging.patch"
	popd >/dev/null || die
	edo node "${FILESDIR}/lighthouse-trace-engine-sources.mjs" check "${te_npm}" "${te_src}"
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
