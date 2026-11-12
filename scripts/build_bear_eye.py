"""Bear eye texture: white sclera, smaller dark pupil, one catchlight. Writes bear-textures/bear-eye.png.

The eye mesh UVs span about 0.07-0.93, so the pupil radius sets how much white ring shows.
The first texture (pupil radius 0.35) left a ring too thin to read in Roblox at garden distance.
"""
from pathlib import Path
import struct, zlib, math

OUT = Path(__file__).resolve().parents[1] / "assets" / "garden-babies" / "bear-textures" / "bear-eye.png"
SIZE = 128
PUPIL_R = 0.27          # fraction of the texture width
PUPIL_COLOR = (26, 20, 24)
GLINT_C, GLINT_R = (0.41, 0.38), 0.07   # image coords (x right, y down)


def coverage(x, y, cx, cy, r):
    # 4x4 supersampled coverage for soft edges
    hits = 0
    for sy in range(4):
        for sx in range(4):
            px = (x + (sx + 0.5) / 4) / SIZE
            py = (y + (sy + 0.5) / 4) / SIZE
            hits += (px - cx) ** 2 + (py - cy) ** 2 <= r * r
    return hits / 16


def main():
    rows = b""
    for y in range(SIZE):
        row = b"\0"
        for x in range(SIZE):
            p = coverage(x, y, 0.5, 0.5, PUPIL_R)
            g = coverage(x, y, *GLINT_C, GLINT_R)
            c = [255 * (1 - p) + PUPIL_COLOR[i] * p for i in range(3)]
            c = [v * (1 - g) + 255 * g for v in c]
            row += bytes(int(round(v)) for v in c)
        rows += row
    png = b"\x89PNG\r\n\x1a\n"
    def chunk(k, v): return struct.pack(">I", len(v)) + k + v + struct.pack(">I", zlib.crc32(k + v))
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")
    OUT.write_bytes(png)
    print(OUT)


if __name__ == "__main__":
    main()
