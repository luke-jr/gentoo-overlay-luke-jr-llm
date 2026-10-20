#!/usr/bin/env python3
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
"""Regenerate one of FFmpeg's checked-in configurations
(third_party/ffmpeg/chromium/config/BRANDING/linux/ARCH/) the way Chromium does:
media/ffmpeg/scripts/build_ffmpeg.py --config-only, then the files that
robo_build.py's CopyConfigPythonTranslation() copies. build_ffmpeg.py takes its
paths from robo_lib's RoboConfiguration, a developer-checkout helper (it reads
/etc/os-release to install packages, checks git branches, ...), so this provides
a minimal one instead.

Usage: chromium-ffmpeg-config.py CHROMIUM_SRC BUILD_DIR BRANDING ARCH
"""
import os
import platform
import shutil
import sys
import types

src, build, branding, arch = sys.argv[1:5]
src = os.path.abspath(src)
build = os.path.abspath(build)
scripts = os.path.join(src, "media", "ffmpeg", "scripts")
ffmpeg = os.path.join(src, "third_party", "ffmpeg")


class RoboConfiguration:
    def chrome_src(self):
        return src

    def ffmpeg_home(self):
        return ffmpeg

    def ffmpeg_src(self):
        return ffmpeg

    def get_script_path(self, *parts):
        return os.path.join(scripts, *parts)

    def host_operating_system(self):
        return "linux"

    def host_architecture(self):
        return {"x86_64": "x64", "aarch64": "arm64"}[platform.machine()]

    def target_config_directory(self, arch, opsys, target):
        return os.path.join(build, f"build.{arch}.{opsys}", target)


robo_lib = types.ModuleType("robo_lib")
robo_lib.config = types.ModuleType("robo_lib.config")
robo_lib.config.RoboConfiguration = RoboConfiguration
sys.modules["robo_lib"] = robo_lib
sys.modules["robo_lib.config"] = robo_lib.config
sys.path[:0] = [scripts, os.path.join(src, "build")]
import build_ffmpeg  # noqa: E402

ret = build_ffmpeg.main(["linux", arch, "--config-only", "--branding=" + branding])
if ret:
    sys.exit(ret)
# robo_build.py: CopyConfigPythonTranslation()
config = os.path.join(build, f"build.{arch}.linux", branding)
dest = os.path.join(ffmpeg, "chromium", "config", branding, "linux", arch)
for f in ("config.h", "config_components.asm", "config_components.h", "config.asm",
          "libavutil/avconfig.h", "libavutil/ffversion.h", "libavcodec/bsf_list.c",
          "libavcodec/codec_list.c", "libavcodec/parser_list.c", "libavformat/demuxer_list.c",
          "libavformat/muxer_list.c", "libavformat/protocol_list.c"):
    if os.path.exists(os.path.join(config, f)):
        os.makedirs(os.path.dirname(os.path.join(dest, f)), exist_ok=True)
        shutil.copy(os.path.join(config, f), os.path.join(dest, f))
