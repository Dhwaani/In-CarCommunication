#!/usr/bin/env python3
"""Produce a self-contained .dsp with icc.lib inlined.

The FAUST Web IDE has no include path, so a design that says
`library("icc.lib")` cannot resolve it there. This rewrites that line into an
inline `environment { ... }` block containing the library body, giving a single
file that can be pasted into <https://faustide.grame.fr> and run with nothing
installed.

Usage:
    python3 tools/inline_lib.py dsp/icc_loop_demo.dsp > standalone.dsp
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def inline(dsp_path: pathlib.Path) -> str:
    lib = (ROOT / "lib" / "icc.lib").read_text()
    # `declare` statements are file-scoped metadata and are not valid inside an
    # environment block, so they are dropped rather than carried across.
    body = "\n".join(
        line for line in lib.splitlines() if not line.strip().startswith("declare ")
    )
    src = dsp_path.read_text()
    marker = 'ic = library("icc.lib");'
    if marker not in src:
        raise SystemExit(f"{dsp_path}: expected `{marker}` and did not find it")
    return src.replace(marker, "ic = environment {\n" + body + "\n};")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    sys.stdout.write(inline(pathlib.Path(sys.argv[1])))
