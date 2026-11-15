"""Retexture the native world pack: swap texture asset ids only, then re-sign the native checkpoint.

  python scripts/retexture_world_native.py --previous OLD-uploads.json --stage DIR            (dry run)
  python scripts/retexture_world_native.py --previous OLD-uploads.json --stage DIR --write

Use after assets/world/world-v7-uploads.json "textures" has new ids (a colour re-grade, not a mesh change).
It is the deliberate promotion step for a texture-only change: scripts/world_native_collision.py never signs.

What it does:
  * maps every texture id that differs between --previous and the canonical uploads file;
  * rewrites those ids inside assets/world/WorldAssetsNative.rbxm, in exactly three property chunks:
    MeshPart.TextureContent, SurfaceAppearance.ColorMapContent, and SurfaceAppearance.TexturePackContent
    (the Studio-compiled pack of a retextured SurfaceAppearance is cleared, so the engine reads the new
    ColorMap instead of a stale pack; Studio recompiles packs on its own);
  * leaves every other chunk byte-for-byte alone. Geometry (MeshContent), sizes, CFrames, collision flags
    and the PhysicalConfigData shared strings are never decoded, and the script refuses if any other
    chunk's bytes differ after the rewrite;
  * runs build_world_v7_assets.py --stage-native-rebuild DIR and refuses unless the staged
    WorldAssets.rbxmx differs from canonical only on TextureID / ColorMap lines and the staged
    WorldV7Data.lua only in waterTexture / fallTexture;
  * with --write: replaces the native pack, WorldAssets.rbxmx and WorldV7Data.lua, and re-signs
    world-v7-native-collision.json (physicalConfigData kept as signed: those bytes did not move).

DIR must be outside src/ and assets/. Run `python scripts/world_native_collision.py --check` afterwards.
A connected Rojo session will patch Studio when the pack changes: re-check CollisionFidelity in Edit before
a save (a synced pack once dropped a part to Box).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

import lz4.block

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import world_native_collision as guard  # noqa: E402

HEADER = 32
CONTENT = 0x22
REPLACE = (b"TextureContent", b"ColorMapContent")
PACK = b"TexturePackContent"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def chunks(data):
    if data[:8] != b"<roblox!":
        raise ValueError("not a binary Roblox model")
    pos, out = HEADER, []
    while pos < len(data):
        name = data[pos:pos + 4]
        packed, size = struct.unpack("<II", data[pos + 4:pos + 12])
        raw = data[pos + 16:pos + 16 + (packed or size)]
        out.append({"name": name, "header": data[pos:pos + 16], "raw": raw,
                    "body": lz4.block.decompress(raw, uncompressed_size=size) if packed else raw})
        pos += 16 + (packed or size)
    return out


def pack(chunk, body):
    raw = lz4.block.compress(body, store_size=False)
    return chunk["name"] + struct.pack("<II", len(raw), len(body)) + b"\0\0\0\0" + raw


def prop(body):
    name_len = struct.unpack("<I", body[4:8])[0]
    return struct.unpack("<I", body[:4])[0], body[8:8 + name_len], body[8 + name_len], 9 + name_len


def read_content(body, start, count):
    """Content (0x22): interleaved zigzag int32 source types, then the URI strings, then object refs."""
    kinds = []
    for i in range(count):
        zig = int.from_bytes(bytes(body[start + plane * count + i] for plane in range(4)), "big")
        kinds.append((zig >> 1) ^ -(zig & 1))
    pos = start + 4 * count
    uri_count = struct.unpack("<I", body[pos:pos + 4])[0]
    pos += 4
    uris = []
    for _ in range(uri_count):
        length = struct.unpack("<I", body[pos:pos + 4])[0]
        uris.append(body[pos + 4:pos + 4 + length])
        pos += 4 + length
    if uri_count != sum(kind == 1 for kind in kinds):
        raise ValueError("Content chunk: URI count does not match its source types")
    return kinds, uris, body[pos:]


def write_content(head, kinds, uris, tail):
    count = len(kinds)
    zigs = [((kind << 1) ^ (kind >> 31)).to_bytes(4, "big") for kind in kinds]
    planes = b"".join(bytes(zig[plane] for zig in zigs) for plane in range(4))
    strings = b"".join(struct.pack("<I", len(uri)) + uri for uri in uris)
    return head + planes + struct.pack("<I", len(uris)) + strings + tail


def retexture(data, mapping):
    """Returns (new bytes, report). Only REPLACE / PACK property chunks are rebuilt."""
    parsed = chunks(data)
    counts = {}
    for chunk in parsed:
        if chunk["name"] == b"INST":
            body = chunk["body"]
            class_id = struct.unpack("<I", body[:4])[0]
            name_len = struct.unpack("<I", body[4:8])[0]
            counts[class_id] = struct.unpack("<I", body[9 + name_len:13 + name_len])[0]
    report = {"replaced": {}, "packsCleared": 0, "chunksRewritten": []}
    retextured = {}  # class id -> indexes whose ColorMap changed
    out = [None] * len(parsed)
    for index, chunk in enumerate(parsed):
        if chunk["name"] != b"PROP":
            continue
        class_id, name, kind, start = prop(chunk["body"])
        if name not in REPLACE:
            continue
        if kind != CONTENT:
            raise ValueError(name.decode() + " is not a Content property in this pack")
        kinds, uris, tail = read_content(chunk["body"], start, counts[class_id])
        slots = [i for i, k in enumerate(kinds) if k == 1]
        changed = []
        for slot, uri in zip(slots, list(uris)):
            if uri in mapping:
                uris[slots.index(slot)] = mapping[uri]
                changed.append(slot)
                report["replaced"][uri.decode()] = report["replaced"].get(uri.decode(), 0) + 1
        if name == b"ColorMapContent":
            retextured[class_id] = set(changed)
        if changed:
            out[index] = pack(chunk, write_content(chunk["body"][:start], kinds, uris, tail))
            report["chunksRewritten"].append(name.decode())
    for index, chunk in enumerate(parsed):
        if chunk["name"] != b"PROP":
            continue
        class_id, name, kind, start = prop(chunk["body"])
        if name != PACK or not retextured.get(class_id):
            continue
        kinds, uris, tail = read_content(chunk["body"], start, counts[class_id])
        slots = [i for i, k in enumerate(kinds) if k == 1]
        keep = [uri for slot, uri in zip(slots, uris) if slot not in retextured[class_id]]
        for slot in retextured[class_id]:
            if kinds[slot] == 1:
                kinds[slot] = 0
                report["packsCleared"] += 1
        out[index] = pack(chunk, write_content(chunk["body"][:start], kinds, keep, tail))
        report["chunksRewritten"].append(name.decode())
    result = data[:HEADER] + b"".join(new if new is not None else chunk["header"] + chunk["raw"]
                                      for new, chunk in zip(out, parsed))
    # Proof by construction, then checked: every chunk that is not one of the three is identical.
    after = chunks(result)
    if len(after) != len(parsed):
        raise RuntimeError("chunk count changed")
    for new, before, now in zip(out, parsed, after):
        if new is None and (before["header"], before["raw"]) != (now["header"], now["raw"]):
            raise RuntimeError("an untouched chunk changed")
        if new is not None and prop(now["body"])[1] not in REPLACE + (PACK,):
            raise RuntimeError("rewrote a chunk outside the texture properties")
    report["chunks"] = len(parsed)
    report["chunksIdentical"] = sum(new is None for new in out)
    return result, report


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--previous", type=Path, required=True, help="world-v7-uploads.json as the native pack was signed")
    parser.add_argument("--stage", type=Path, required=True, help="staging directory outside src/ and assets/")
    parser.add_argument("--evidence", type=Path, help="write the report as JSON")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    proof_path = ROOT / guard.PROOF
    proof = json.loads(proof_path.read_text(encoding="utf-8"))
    native = (ROOT / guard.NATIVE).read_bytes()
    if sha(native) != proof["nativeSha256"]:
        raise SystemExit("canonical native pack does not match its proof; refusing")
    stale = [name for name, value in guard.input_hashes(ROOT).items() if proof["inputs"].get(name) != value]
    if stale != ["assets/world/world-v7-uploads.json"]:
        raise SystemExit("expected only world-v7-uploads.json to differ from the signed inputs, found: " + ", ".join(stale or ["nothing"]))
    if sha(args.previous.read_bytes()) != proof["inputs"]["assets/world/world-v7-uploads.json"]:
        raise SystemExit("--previous is not the uploads file the native pack was signed with")
    old = json.loads(args.previous.read_text(encoding="utf-8"))
    new = json.loads((ROOT / "assets/world/world-v7-uploads.json").read_text(encoding="utf-8"))
    if {k: v for k, v in old.items() if k != "textures"} != {k: v for k, v in new.items() if k != "textures"}:
        raise SystemExit("only the \"textures\" block may change in a retexture")
    if set(old["textures"]) != set(new["textures"]):
        raise SystemExit("texture keys changed")
    pairs = {(old["textures"][key], new["textures"][key]) for key in old["textures"] if old["textures"][key] != new["textures"][key]}
    mapping = {}
    for before, after in pairs:
        if mapping.setdefault(before.encode(), after.encode()) != after.encode():
            raise SystemExit("one old id maps to two new ids: " + before)
    kept = {value for key, value in new["textures"].items() if old["textures"][key] == value}
    if kept & {before for before, _ in pairs}:
        raise SystemExit("an id is both kept and replaced; a blind id swap would be wrong")

    result, report = retexture(native, mapping)
    missing = sorted(before.decode() for before in mapping if before.decode() not in report["replaced"])
    left = sorted(before.decode() for before in mapping if before in result)
    if left:
        raise SystemExit("old ids still present in the pack: " + ", ".join(left))

    stage = guard.stage_directory(ROOT, args.stage)
    subprocess.run([sys.executable, str(ROOT / "scripts" / "build_world_v7_assets.py"), "--stage-native-rebuild", str(stage)],
                   check=True, cwd=ROOT, stdout=subprocess.DEVNULL)
    staged_xml, staged_lua = (stage / "WorldAssets.rbxmx").read_bytes(), (stage / "WorldV7Data.lua").read_bytes()
    old_xml, old_lua = (ROOT / guard.XML).read_bytes(), (ROOT / guard.LUA).read_bytes()
    a, b = old_xml.decode().split("\n"), staged_xml.decode().split("\n")
    if len(a) != len(b):
        raise SystemExit("staged WorldAssets.rbxmx changed its line count")
    xml_lines = [(x, y) for x, y in zip(a, b) if x != y]
    if any(not re.search(r'<Content name="(TextureID|ColorMap)">', x) for x, _ in xml_lines):
        raise SystemExit("staged WorldAssets.rbxmx differs outside TextureID / ColorMap")
    strip = lambda text: re.sub(rb'"(waterTexture|fallTexture)":"[^"]*"', b"", text)
    if strip(old_lua) != strip(staged_lua):
        raise SystemExit("staged WorldV7Data.lua differs outside waterTexture / fallTexture")

    report.update({
        "mapping": {before.decode(): after.decode() for before, after in sorted(mapping.items())},
        "idsNotInPack": missing,
        "old": {"nativeBytes": len(native), "nativeSha256": sha(native)},
        "new": {"nativeBytes": len(result), "nativeSha256": sha(result)},
        "xmlLinesChanged": len(xml_lines), "luaChanged": old_lua != staged_lua,
    })
    print(json.dumps({k: v for k, v in report.items() if k != "mapping"}, indent=1))
    if args.evidence:
        args.evidence.write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    if not args.write:
        print("dry run: nothing written (pass --write)")
        return
    (ROOT / guard.NATIVE).write_bytes(result)
    (ROOT / guard.XML).write_bytes(staged_xml)
    (ROOT / guard.LUA).write_bytes(staged_lua)
    proof["nativeBytes"], proof["nativeSha256"] = len(result), sha(result)
    proof["xmlSha256"], proof["luaSha256"] = sha(staged_xml), sha(staged_lua)
    proof["inputs"] = guard.input_hashes(ROOT)
    proof["provenance"] = dict(proof.get("provenance", {}), retexture={
        "previousNativeSha256": sha(native), "chunks": report["chunks"], "chunksIdentical": report["chunksIdentical"],
        "chunksRewritten": report["chunksRewritten"], "packsCleared": report["packsCleared"],
        "note": "Texture ids only (scripts/retexture_world_native.py). Geometry, collision flags and PhysicalConfigData chunks byte-identical; not re-exported from Studio.",
    })
    proof["promotion"] = "Explicit texture-only promotion (scripts/retexture_world_native.py); validator never rewrites this manifest."
    proof_path.write_bytes((json.dumps(proof, indent=2) + "\n").replace("\n", "\r\n").encode("utf-8"))
    guard.validate(ROOT)
    print("promoted: native pack, WorldAssets.rbxmx, WorldV7Data.lua and the native proof")


if __name__ == "__main__":
    main()
