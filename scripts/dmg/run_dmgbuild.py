#!/usr/bin/env python3
"""Run dmgbuild without the Tahoe-stale pBBk bookmark.

macOS 26 Finder prefers .DS_Store pBBk over the portable icvp alias.
That bookmark points at the temporary build volume, so the background
drops and the window stays white. Skip the bookmark (dmgbuild 1.6.7+).
"""

from __future__ import annotations

import argparse
import sys

import dmgbuild.core as dmgbuild_core


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--settings", required=True)
    parser.add_argument("-D", dest="defines", action="append", default=[])
    parser.add_argument("volume_name")
    parser.add_argument("output")
    args = parser.parse_args()

    defines = {}
    for item in args.defines:
        key, _, value = item.partition("=")
        defines[key] = value

    dmgbuild_core.Bookmark.for_file = lambda *_a, **_k: None
    dmgbuild_core.build_dmg(
        args.output,
        args.volume_name,
        settings_file=args.settings,
        defines=defines,
        lookForHiDPI=False,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
