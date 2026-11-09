"""Author small constant PBR maps; no uploads, mounted assets, or runtime edits."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "pet-materials"
SIZE = 32


def chunk(kind: bytes, value: bytes) -> bytes:
    return struct.pack(">I", len(value)) + kind + value + struct.pack(">I", zlib.crc32(kind + value))


def png(pixel: tuple[int, ...]) -> bytes:
    # No color-management metadata: scalar maps are data, not photographed colors.
    color_type = {3: 2, 4: 6}[len(pixel)]
    rows = (b"\0" + bytes(pixel) * SIZE) * SIZE
    return b"\x89PNG\r\n\x1a\n" + b"".join((
        chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, color_type, 0, 0, 0)),
        chunk(b"IDAT", zlib.compress(rows, level=9)),
        chunk(b"IEND", b""),
    ))


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    definitions = (
        ("white", "white-opaque.png", (255, 255, 255, 255), "Opaque albedo and full emissive mask", 1.0),
        ("metalness", "metalness-zero.png", (0, 0, 0), "Nonmetal for every profile", 0.0),
        ("bodyRoughness", "roughness-body-032.png", (82, 82, 82), "Body, ordinary Secondary and charm roughness", .32),
        ("eyeRoughness", "roughness-eye-014.png", (36, 36, 36), "Protected glossy eye roughness", .14),
    )
    maps = {}
    for key, filename, pixel, purpose, target in definitions:
        data = png(pixel)
        (OUTPUT / filename).write_bytes(data)
        maps[key] = {
            "file": filename, "width": SIZE, "height": SIZE, "channels": len(pixel),
            "pixel": pixel, "purpose": purpose, "targetScalar": target,
            "encodedScalar": pixel[0] / 255, "sha256": hashlib.sha256(data).hexdigest(),
        }
    manifest = {
        "schemaVersion": 1, "materialVersion": 1,
        "authorship": "Original deterministic constant maps; no external imagery or mesh changes.",
        "generator": "scripts/build_pet_material_maps.py", "maps": maps,
        "profiles": {
            "Body": {"roughness": "bodyRoughness", "emissionDayDuskNight": [.02, .18, .34]},
            "Eye": {"roughness": "eyeRoughness", "emissionDayDuskNight": [0, 0, 0]},
            "Charm": {"roughness": "bodyRoughness", "emissionDayDuskNight": [.12, .49, .86]},
            "Catchlight": {"roughness": "eyeRoughness", "emissionDayDuskNight": [.10, .28, .46]},
        },
        "tintPolicy": "Opaque white albedo; runtime resolved role color applied once through SurfaceAppearance.Color. Trial EmissiveTint is white, subject to native hue probe.",
        "normalMap": None,
        "uploadedIds": {
            "white": "rbxassetid://132217078330162",
            "metalness": "rbxassetid://114363080604088",
            "bodyRoughness": "rbxassetid://90822949282078",
            "eyeRoughness": "rbxassetid://101362074171738",
        },
        "templatePack": {
            "file": "PetMaterials.rbxm",
            "sha256": hashlib.sha256((OUTPUT / "PetMaterials.rbxm").read_bytes()).hexdigest(),
            "provenance": "Native SerializationService Edit export; four profiles round-tripped with modern Content URLs.",
        } if (OUTPUT / "PetMaterials.rbxm").exists() else None,
        "uploadPolicy": "Root uploads these four files, records returned owned asset IDs, then invokes the Edit-only template builder. This generator does not upload or modify mounted assets.",
        "uvCaveat": "Uniform maps minimize UV assumptions; original Zivvi/Ovelle native render validation remains required.",
    }
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    for item in maps.values():
        print(OUTPUT / item["file"])


if __name__ == "__main__":
    main()
