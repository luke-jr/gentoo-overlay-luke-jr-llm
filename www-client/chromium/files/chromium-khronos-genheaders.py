#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Run an old Khronos genheaders.py (OpenGL-Registry, EGL-Registry) on today's
Python: time.clock, which it times its steps with, was removed in Python 3.8.

Usage: chromium-khronos-genheaders.py genheaders.py ARGS...  (in its directory)
"""
import runpy
import sys
import time

if not hasattr(time, "clock"):
    time.clock = time.process_time
sys.argv = sys.argv[1:]
sys.path.insert(0, ".")
runpy.run_path(sys.argv[0], run_name="__main__")
