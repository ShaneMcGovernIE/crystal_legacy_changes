#!/usr/bin/env python3
"""Phase 4b: convert CL overworld sprite art to gold's mode L 4-shade format.

CL's OW art (gfx/sprites/*.png sheets, gfx/icons/*.png icons) is stored as
indexed-color previews: 4 opaque colors per sprite (white, black, 2 accents)
with the accent colors matching the GBC OBP palette slots the objects use.
The gen1recomp runtime bakes mode L sheets through getObpImage, mapping the
four gray shades to an OBP palette (r>0.83 transparent, >0.5 colors[2],
>0.17 colors[3], else colors[4]).

So the faithful conversion is: rank the 4 source colors by luminance and map
them onto gold's canonical gray ladder {255, 170, 85, 0} (lightest -> 255).
The runtime bake then reproduces the GBC rendering exactly (e.g. Articuno's
sheet light-blue -> orange accent, dark-blue -> blue accent: the GBC OW bird
palette is orange+blue).

Sources (read-only):
  CL_source/gfx/sprites/{articuno,zapdos}.png   16x96  (6-frame walking sheets)
  CL_source/gfx/icons/{mew,celebi,electrode,murkrow}.png  16x32 (mon icons)

Output: assets/sprites/*.png, mode L, exactly the 4 shades {255,170,85,0}.
"""
import os
import sys
from PIL import Image

CL = os.path.expanduser("~/dev/CL_source")
OUT = os.path.expanduser("~/dev/crystal_legacy_changes/assets/sprites")

TARGETS = [
    ("gfx/sprites/articuno.png", "articuno.png", "16x96 sheet"),
    ("gfx/sprites/zapdos.png", "zapdos.png", "16x96 sheet"),
    ("gfx/icons/mew.png", "mew.png", "16x32 icon"),
    ("gfx/icons/celebi.png", "celebi.png", "16x32 icon"),
    ("gfx/icons/electrode.png", "electrode.png", "16x32 icon"),
    ("gfx/icons/murkrow.png", "murkrow.png", "16x32 icon"),
]

SHADES = (255, 170, 85, 0)  # gold's canonical gray ladder, lightest first


def luminance(rgb):
    r, g, b = rgb[:3]
    return 0.299 * r + 0.587 * g + 0.114 * b


def convert(src_rel, dst_name):
    im = Image.open(os.path.join(CL, src_rel)).convert("RGBA")
    pixels = list(im.getdata())
    # Unique opaque colors (CL art is exactly 4, no alpha).
    colors = {}
    for px in pixels:
        if px[3] > 0:
            colors[px[:3]] = True
    colors = list(colors.keys())
    if len(colors) != 4:
        sys.exit(f"{src_rel}: expected exactly 4 opaque colors, got {len(colors)}")
    # Rank by luminance ascending (darkest first), map onto the gray ladder.
    colors.sort(key=luminance)
    table = {}
    for rank, color in enumerate(colors):
        table[color] = SHADES[len(SHADES) - 1 - rank]  # darkest -> 0, lightest -> 255
    out = Image.new("L", im.size)
    out.putdata([table.get(px[:3], 0) for px in pixels])
    os.makedirs(OUT, exist_ok=True)
    dst = os.path.join(OUT, dst_name)
    out.save(dst)
    # Verify: exactly the 4 shades present.
    got = sorted(set(out.getdata()))
    if got != [0, 85, 170, 255]:
        sys.exit(f"{dst_name}: bad shade set {got}")
    print(f"OK {src_rel} -> {dst_name} {im.size} shades={got}")


if __name__ == "__main__":
    for src, dst, kind in TARGETS:
        convert(src, dst)
    print("done")
