#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Regenerate XNNPACK's checked-in generated code from its sources.

XNNPACK's micro-kernels under src/*/gen/ are generated: from templates (*.in) by its
tools/xngen, one invocation per output, as listed in its scripts/generate-*.sh, and the
assembly GEMM kernels by gemm_compiler. Delete everything under src/*/gen/, then run those
xngen invocations (only the xngen ones: the scripts also generate tests, which the tarball
doesn't have) and gemm_compiler; generated kernels that nothing recreates are left out (the
build fails if it needs one). Then regenerate build_identifier.c (a fingerprint of the
library's sources) with scripts/generate-build-identifier.py, from the source list it
records.

usage: chromium-xnnpack-regen.py THIRD_PARTY_XNNPACK_DIR JOBS
"""
import concurrent.futures
import glob
import os
import shlex
import subprocess
import sys

top, jobs = os.path.abspath(sys.argv[1]), int(sys.argv[2])
src = os.path.join(top, 'src')

commands = {}
for script in sorted(glob.glob(os.path.join(src, 'scripts', 'generate-*.sh'))):
    text = open(script).read().replace('\\\n', ' ')
    for line in text.splitlines():
        line = line.split(' #')[0].strip().rstrip('&').strip()
        if not line.startswith('tools/xngen'):
            continue
        args = shlex.split(line)
        commands.setdefault(args[args.index('-o') + 1], args[1:])
if len(commands) < 1000:
    sys.exit(f'only {len(commands)} xngen invocations found in scripts/generate-*.sh')


before = {os.path.relpath(p, src) for p in glob.glob(os.path.join(src, 'src', '**', 'gen', '*'), recursive=True)}
for rel in before:
    os.remove(os.path.join(src, rel))


def run(item):
    output, args = item
    r = subprocess.run([sys.executable, '-B', 'tools/xngen'] + args, cwd=src, capture_output=True, text=True)
    return output, r.returncode, r.stderr


failed = []
with concurrent.futures.ThreadPoolExecutor(jobs) as pool:
    for output, rc, err in pool.map(run, sorted(commands.items())):
        if rc:
            failed.append(f'{output}: {err.strip()[-300:]}')
if failed:
    sys.exit('xngen failed:\n' + '\n'.join(failed[:20]))
subprocess.run([sys.executable, '-B', '-m', 'gemm_compiler.generate_gemm_microkernels_main'], cwd=src, check=True)

after = {os.path.relpath(p, src) for p in glob.glob(os.path.join(src, 'src', '**', 'gen', '*'), recursive=True)}
missing = sorted(before - after)

# build_identifier.c lists its inputs as Bazel saw them (external/xnnpack+/<path in src/>).
bid = os.path.join(top, 'build_identifier.c')
prefix = '// - external/xnnpack+/'
inputs = [l[len(prefix):].rstrip('\n') for l in open(bid) if l.startswith(prefix)]
if not inputs:
    sys.exit('no inputs listed in build_identifier.c')
workdir = os.path.join(top, '.build-identifier')
os.makedirs(os.path.join(workdir, 'external'), exist_ok=True)
link = os.path.join(workdir, 'external', 'xnnpack+')
if not os.path.lexists(link):
    os.symlink(os.path.abspath(src), link)
listfile = os.path.join(workdir, 'inputs.txt')
with open(listfile, 'w') as f:
    f.write(''.join(f'external/xnnpack+/{p}\n' for p in inputs))
subprocess.run([sys.executable, '-B', os.path.join(src, 'scripts', 'generate-build-identifier.py'),
                '--output', os.path.abspath(bid), '--input_file_list', listfile], cwd=workdir, check=True)
os.remove(listfile)
os.remove(link)
os.rmdir(os.path.join(workdir, 'external'))
os.rmdir(workdir)
print(f'XNNPACK: {len(after)} generated kernels made from their sources; {len(missing)} that nothing generates '
      f'left out: {" ".join(missing)}; build_identifier.c from {len(inputs)} sources')
