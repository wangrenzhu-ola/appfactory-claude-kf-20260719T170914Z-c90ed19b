#!/usr/bin/env python3
"""Draw the ArrowTune app icon: WA-style target rings with one signal-orange
impact and a fine crosshair on paper white. Simple asset conversion only."""
import struct
import zlib
import math
import os

SIZE = 1024
CX = CY = SIZE / 2

# Palette (matches the in-app design language)
PAPER = (250, 249, 246)
RING_FILL = {
    1: (237, 234, 229), 2: (237, 234, 229),
    3: (158, 163, 168), 4: (158, 163, 168),
    5: (41, 107, 158), 6: (41, 107, 158),
    7: (199, 61, 56), 8: (199, 61, 56),
    9: (230, 173, 51), 10: (230, 173, 51),
}
INK = (16, 35, 58)
SIGNAL = (232, 106, 44)


def ring_for_radius(r, max_r):
    frac = r / max_r
    if frac > 1.0:
        return 0
    return min(10, max(1, 10 - int(frac * 10)))


def main():
    max_r = SIZE * 0.46
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)  # filter type
        for x in range(SIZE):
            dx, dy = x - CX, y - CY
            r = math.hypot(dx, dy)
            px = PAPER
            if r <= max_r:
                px = RING_FILL[ring_for_radius(r, max_r)]
            # ring hairlines
            for k in range(1, 11):
                if abs(r - max_r * k / 10) < 1.2:
                    px = tuple(int(c * 0.75) for c in INK)
            # fine crosshair
            if (abs(dx) < 1.4 or abs(dy) < 1.4) and r < max_r * 0.09:
                px = INK
            # one signal-orange impact, off-center left-high like a real group
            if math.hypot(x - (CX - max_r * 0.23), y - (CY - max_r * 0.17)) < max_r * 0.045:
                px = SIGNAL
            rows.extend(px)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
           + chunk(b"IEND", b""))
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(here, "ArrowTune/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as fh:
        fh.write(png)
    print(out)


if __name__ == "__main__":
    main()
