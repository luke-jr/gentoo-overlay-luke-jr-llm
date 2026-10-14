// Gentoo: replaces dist/native.js of @rollup/wasm-node. Loads rollup's parser
// as a native Node.js addon built from source (dev-util/rollup-native, the
// same Rust code as the prebuilt dist/wasm-node/bindings_wasm_bg.wasm, which
// is deleted) instead of the WebAssembly build. The ebuild symlinks the addon
// to ./rollup.native.node.
const {
	parse,
	parseAsync,
	xxhashBase64Url,
	xxhashBase36,
	xxhashBase16
} = require('./rollup.native.node');

exports.parse = parse;
exports.parseAsync = parseAsync;
exports.xxhashBase64Url = xxhashBase64Url;
exports.xxhashBase36 = xxhashBase36;
exports.xxhashBase16 = xxhashBase16;
