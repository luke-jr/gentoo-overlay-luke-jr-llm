#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Regenerate ANGLE's checked-in generated code from its sources.

ANGLE checks in the output of ~30 code generators (scripts/run_code_generation.py's list):
entry points, format and enum tables, the shader translator's lexers/parsers, its built-in
symbol tables and its Vulkan back-end's internal shaders (compiled SPIR-V). Run them all,
as run_code_generation.py does when inputs change, then format the C/C++ outputs and GN
files as its `git cl format` step does.

Inputs the release tarball doesn't have are passed in: the Khronos registries' XML files
(ANGLE's DEPS revisions), perfect_hash (the version its built-in symbols generator is
written for), and a glslang validator (the system's: the compiled shaders differ from
upstream's, which a 2020 glslang made), plus flex and bison.

usage: chromium-angle-regen.py SRC_ROOT XML_DIR PERFECT_HASH_DIR GLSLANG FLEX BISON CLANG_FORMAT GN
  SRC_ROOT: the Chromium tree; XML_DIR: gl.xml glx.xml wgl.xml egl.xml cl.xml vk.xml;
  CLANG_FORMAT may be empty (formatting only changes the layout)
"""
import os
import re
import shutil
import subprocess
import sys

root, xml, perfect_hash, glslang, flex, bison, clang_format, gn = sys.argv[1:]
angle = os.path.join(root, 'third_party', 'angle')

# The registries, where ANGLE's generators look for them (its own third_party/, which inside
# Chromium holds no sources: Vulkan's and SPIR-V's headers are Chromium's).
inputs = {
    'third_party/OpenGL-Registry/src/xml': ['gl.xml', 'glx.xml', 'wgl.xml'],
    'third_party/EGL-Registry/src/api': ['egl.xml'],
    'third_party/OpenCL-Docs/src/xml': ['cl.xml'],
}
for d, files in inputs.items():
    os.makedirs(os.path.join(angle, d), exist_ok=True)
    for f in files:
        shutil.copy(os.path.join(xml, f), os.path.join(angle, d, f))
shutil.copy(os.path.join(xml, 'vk.xml'), os.path.join(root, 'third_party', 'vulkan-headers', 'src', 'registry'))
for dep in ('vulkan-headers', 'spirv-headers'):
    link = os.path.join(angle, 'third_party', dep, 'src')
    if not os.path.lexists(link):
        os.symlink(os.path.join(root, 'third_party', dep, 'src'), link)

# Tools, where ANGLE's generators look for its prebuilt ones.
tools = {
    'tools/flex-bison/linux/flex': flex,
    'tools/flex-bison/linux/bison': bison,
    'tools/glslang/glslang_validator': glslang,
}
for path, tool in tools.items():
    path = os.path.join(angle, path)
    if os.path.lexists(path):
        os.remove(path)
    os.symlink(tool, path)

env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', PYTHONPATH=perfect_hash)
driver = open(os.path.join(angle, 'scripts', 'run_code_generation.py')).read()
table = driver[driver.index('generators = {'):driver.index('\ndef main')]
generators = dict(re.findall(r"'([^']+)':\s*\n?\s*'([^']+\.py)'", table))
generators.update(re.findall(r"'([^']+)':\s*'([^']+\.py)'", table[table.index('hashless_generators'):]))
# Not for Linux builds: Metal's shaders need Xcode; the restricted traces and dEQP's file lists
# are test data.
skip = {'Metal default shaders', 'restricted traces', 'GL CTS (dEQP) build files'}
if len(generators) < 25:
    sys.exit(f'only {len(generators)} generators found in run_code_generation.py')



def snapshot():
    mtimes = {}
    for d, _, files in os.walk(angle):
        for f in files:
            p = os.path.join(d, f)
            if not os.path.islink(p):
                mtimes[p] = os.stat(p).st_mtime_ns
    return mtimes


before = snapshot()
count = 0
for name, script in sorted(generators.items()):
    if name in skip:
        continue
    cwd = os.path.join(angle, os.path.dirname(script))
    base = os.path.basename(script)
    r = subprocess.run([sys.executable, base], cwd=cwd, env=env, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f'ANGLE generator "{name}" ({script}) failed:\n{r.stdout}{r.stderr}')
    count += 1

# Format what the generators wrote (they don't all list everything they write), as
# `git cl format` does after run_code_generation.py; it leaves .inc files alone.
written = [p for p, m in snapshot().items() if before.get(p) != m]
for path in written:
    if path.endswith(('.cpp', '.h', '.c', '.mm')):
        if clang_format:
            subprocess.run([clang_format, '-i', '--style=file', path], cwd=angle, check=True)
    elif path.endswith(('.gn', '.gni')):
        subprocess.run([gn, 'format', path], capture_output=True, check=True)
print(f'ANGLE: {count} code generators run, {len(written)} files written')
