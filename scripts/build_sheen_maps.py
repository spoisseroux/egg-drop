"""Customization Egg sheen stops (slice 3): four more constant roughness maps.

The seven stops, roughness out of 255 (lower is shinier):
  -3 Chalky 255 (existing white map, as BodyMatte)   +1 Satin  58 (new)
  -2 Matte  196 (new)                                 +2 Glossy 36 (existing, as BodyGloss)
  -1 Soft   138 (new)                                 +3 Glassy 14 (new)
   0 Original 82 (existing Body)
Writes assets/pet-materials/roughness-sheen-<value>.png, 32x32 RGB, no colour metadata
(the same constant-map recipe as scripts/build_pet_material_maps.py). No uploads.
Usage: python scripts/build_sheen_maps.py
"""
import hashlib
import os
import struct
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "pet-materials")
SIZE = 32
VALUES = (196, 138, 58, 14)


def chunk(kind, value):
    return struct.pack(">I", len(value)) + kind + value + struct.pack(">I", zlib.crc32(kind + value))


def png(pixel):
    rows = (b"\0" + bytes(pixel) * SIZE) * SIZE
    return b"\x89PNG\r\n\x1a\n" + b"".join((
        chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)),
        chunk(b"IDAT", zlib.compress(rows, level=9)),
        chunk(b"IEND", b""),
    ))


def main():
    for value in VALUES:
        data = png((value, value, value))
        path = os.path.join(OUT, "roughness-sheen-%03d.png" % value)
        with open(path, "wb") as handle:
            handle.write(data)
        print(path, hashlib.sha256(data).hexdigest())


if __name__ == "__main__":
    main()
