// Gentoo: replaces rollup's native.js, which loads the parser from a platform
// package (@rollup/rollup-<platform>). The addon is built from source by this
// package and installed next to the CLI as ./rollup.native.node.
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
