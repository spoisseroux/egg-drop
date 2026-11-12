"""Write the two-tone body ColorMap: white RGB, alpha = how much secondary shows.

Used with SurfaceAppearance AlphaMode=Overlay: alpha 0 shows the MeshPart's Color (primary),
alpha 1 shows ColorMap x SurfaceAppearance.Color (secondary). The gradient follows UV v the
same way on every pet (PET-STYLE-GUIDE.md): v=0 (image bottom) fully secondary, v>=0.64
fully primary. No uploads; writes only assets/pet-materials/two-tone-gradient.png.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "pet-materials" / "two-tone-gradient.png"
SIZE = 32
PRIMARY_FROM_V = 0.64


def chunk(kind: bytes, value: bytes) -> bytes:
    return struct.pack(">I", len(value)) + kind + value + struct.pack(">I", zlib.crc32(kind + value))


def secondary_amount(row: int) -> float:
    # PNG row 0 is the top of the image, which is UV v = 1.
    v = 1 - (row + 0.5) / SIZE
    return max(0.0, min(1.0, 1 - v / PRIMARY_FROM_V))


def main() -> None:
    rows = b""
    for row in range(SIZE):
        alpha = round(secondary_amount(row) * 255)
        rows += b"\0" + bytes((255, 255, 255, alpha)) * SIZE
    data = b"\x89PNG\r\n\x1a\n" + b"".join((
        chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)),
        chunk(b"IDAT", zlib.compress(rows, level=9)),
        chunk(b"IEND", b""),
    ))
    OUT.write_bytes(data)
    print(OUT, hashlib.sha256(data).hexdigest())


if __name__ == "__main__":
    main()
