#!/bin/bash
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
#
# Regenerates the generated files of Chromium's bundled ICU (third_party/icu)
# from their inputs, the way ICU and Chromium make them:
# - ICU's Unicode data (source/data/unidata: ppucd.txt, the norm2 inputs and
#   copies of UCD files; genprops' pnames_data.h) from Unicode's release files,
#   with ICU's tools/unicode/py/preparseucd.py
# - the property, normalization and collation data built from those
#   (source/data/in/*.icu, *.nrm, coll/*.icu; common/*_props_data.h,
#   propname_data.h, norm2_nfc_data.h; i18n/collationfcd.cpp), with gennorm2 and
#   tools/unicode/c's genprops and genuca (source/data/unidata/generate.sh)
# - i18n/collunsafe.h (tools/gencolusb), common/rbbirpt.h and i18n/regexcst.h
#   (rbbicst.pl, regexcst.pl), common/unicode/urename.h (tools/genren)
# - common/icudtl.dat, with Chromium's filter (scripts/make_data_all.sh)
#
# Usage: chromium-icu-regen.sh ICU_DIR WORK_DIR UNICODE_DIR TOOLS_DIR JOBS
#   ICU_DIR      third_party/icu
#   WORK_DIR     an empty directory for the builds
#   UNICODE_DIR  Unicode's release files (UCD, idna, security, emoji)
#   TOOLS_DIR    ICU's tools/unicode: py/preparseucd.py, c/genprops, c/genuca
# CC and CXX (and CFLAGS, CXXFLAGS, LDFLAGS) are used for the host builds.

set -euo pipefail

icu=$(realpath "$1")
work=$(realpath "$2")
unicode=$(realpath "$3")
tools=$(realpath "$4")
jobs=$5
src=${icu}/source
export PYTHONDONTWRITEBYTECODE=1

step() { echo ">>> ICU: $*"; }

step "removing the pseudo locales (as make_data_all.sh does)"
find "${src}/data" \( -name 'en_XA*' -o -name 'ar_XB*' \) -delete

# preparseucd.py takes the root of an ICU checkout: icu4c/ and tools/.
step "preparseucd.py: Unicode data"
mkdir -p "${work}/root/tools/unicode/c"
ln -s "${icu}" "${work}/root/icu4c"
cp -r "${tools}/c/genprops" "${tools}/c/genuca" "${work}/root/tools/unicode/c/"
python3 -B "${tools}/py/preparseucd.py" "${unicode}" "${work}/root" > "${work}/preparseucd.log"
genprops_dir=${work}/root/tools/unicode/c/genprops
genuca_dir=${work}/root/tools/unicode/c/genuca

# A release build (gennorm2 asserts in debug builds) with Chromium's data
# filter. The data is built last, from the regenerated inputs, as an archive
# only (packaging it as a library would run the compiler with this ICU's
# libraries in LD_LIBRARY_PATH, which breaks one that loads the system's ICU).
step "building ICU's libraries and tools"
mkdir -p "${work}/build"
cd "${work}/build"
ICU_DATA_FILTER_FILE="${icu}/filters/common.json" "${src}/configure" \
	--with-data-packaging=archive --disable-tests --disable-samples --disable-extras --disable-layoutex \
	--prefix="${work}/build/prefix" > "${work}/configure.log"
mkdir -p lib bin  # made by the top-level Makefile
for d in stubdata common i18n io tools; do
	make -j"${jobs}" -C "${d}" > "${work}/make-${d}.log"
done
# Runs one of ICU's tools (not exported for everything: the compiler may load the
# system's ICU, through libxml2).
icu() { LD_LIBRARY_PATH=${work}/build/lib "$@"; }
bin=${work}/build/bin

step "gennorm2: normalization data"
in=${src}/data/in
norm2=${src}/data/unidata/norm2
rm "${src}"/common/norm2_nfc_data.h "${src}"/common/propname_data.h "${src}"/common/*_props_data.h
rm "${in}"/*.icu "${in}"/*.nrm "${in}"/coll/*.icu "${src}"/i18n/collationfcd.cpp
icu "${bin}/gennorm2" -o "${src}/common/norm2_nfc_data.h" -s "${norm2}" nfc.txt --csource
icu "${bin}/gennorm2" -o "${in}/nfc.nrm" -s "${norm2}" nfc.txt
icu "${bin}/gennorm2" -o "${in}/nfkc.nrm" -s "${norm2}" nfc.txt nfkc.txt
icu "${bin}/gennorm2" -o "${in}/nfkc_cf.nrm" -s "${norm2}" nfc.txt nfkc.txt nfkc_cf.txt
icu "${bin}/gennorm2" -o "${in}/nfkc_scf.nrm" -s "${norm2}" nfc.txt nfkc.txt nfkc_scf.txt
icu "${bin}/gennorm2" -o "${in}/uts46.nrm" -s "${norm2}" nfc.txt uts46.txt

step "genprops and genuca: property and collation data"
inc=( -I"${src}/common" -I"${src}/i18n" -I"${src}/tools/toolutil" -I"${work}/build/common" )
libs=( -L"${work}/build/lib" -licutu -licui18n -licuuc -licudata )
for t in genprops genuca; do
	d=${work}/root/tools/unicode/c/${t}
	# shellcheck disable=SC2086
	${CXX} ${CXXFLAGS:-} -std=c++17 "${inc[@]}" -o "${work}/${t}" "${d}"/*.cpp ${LDFLAGS:-} "${libs[@]}"
done
icu "${work}/genprops" "${icu}" > "${work}/genprops.log"
for args in "--hanOrder implicit" "--hanOrder radical-stroke" \
	"--icu4x --hanOrder implicit" "--icu4x --hanOrder radical-stroke"; do
	# shellcheck disable=SC2086
	icu "${work}/genuca" ${args} "${icu}" >> "${work}/genuca.log"
done

# extract_unsafe_backwards must run against an i18n library built with an empty
# collunsafe.h (gencolusb's Makefile: reset-icu).
step "gencolusb: collunsafe.h"
: > "${src}/i18n/collunsafe.h"
make -j"${jobs}" -C i18n > "${work}/make-i18n-reset.log"
# shellcheck disable=SC2086
${CXX} ${CXXFLAGS:-} -std=c++17 -I"${src}/common" -I"${src}/i18n" -o "${work}/extract_unsafe_backwards" \
	"${src}/tools/gencolusb/extract_unsafe_backwards.cpp" ${LDFLAGS:-} -L"${work}/build/lib" -licuuc -licui18n -licudata
icu "${work}/extract_unsafe_backwards" > "${work}/collunsafe.h"
mv "${work}/collunsafe.h" "${src}/i18n/collunsafe.h"

step "rbbicst.pl and regexcst.pl: rule parser state tables"
(cd "${src}/common" && perl rbbicst.pl < rbbirpt.txt > rbbirpt.h.new && mv rbbirpt.h.new rbbirpt.h)
(cd "${src}/i18n" && perl regexcst.pl < regexcst.txt > regexcst.h.new && mv regexcst.h.new regexcst.h)

# genren lists the exported symbols of an ICU built without renaming (its
# Makefile). Without the layout engine, which Chromium doesn't build, so its
# pl_ names are not listed.
step "genren: urename.h"
mkdir -p "${work}/unrenamed"
cd "${work}/unrenamed"
CPPFLAGS="-DU_DISABLE_RENAMING=1 -DUCONFIG_ENABLE_PLUGINS" "${src}/configure" \
	--with-data-packaging=archive --enable-tests=no --disable-samples --disable-extras \
	--disable-layoutex --prefix="${work}/unrenamed/prefix" > "${work}/configure-unrenamed.log"
mkdir -p lib bin
for d in stubdata common i18n io; do
	make -j"${jobs}" -C "${d}" all-local > "${work}/make-unrenamed-${d}.log"
done
(cd "${work}" && perl "${src}/tools/genren/genren.pl" -o urename.h \
	"${work}"/unrenamed/lib/libicu{uc,i18n,io}.so > "${work}/genren.log")
mv "${work}/urename.h" "${src}/common/unicode/urename.h"

# The libraries and tools again with the regenerated headers, then the data.
step "icudtl.dat"
cd "${work}/build"
for d in common i18n tools data; do
	make -j"${jobs}" -C "${d}" > "${work}/make-${d}-final.log"
done
major=$(sed -n 's/^#define U_ICU_VERSION_MAJOR_NUM \([0-9]*\)$/\1/p' "${src}/common/unicode/uvernum.h")
cp "${work}/build/data/out/icudt${major}l.dat" "${icu}/common/icudtl.dat"
step "done"
