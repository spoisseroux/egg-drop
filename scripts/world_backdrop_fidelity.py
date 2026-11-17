"""Set the backdrop ring (W7_Backdrop__*) to RenderFidelity Precise in the native world pack.

  python scripts/world_backdrop_fidelity.py           (dry run: report)
  python scripts/world_backdrop_fidelity.py --write   (rewrite the pack, re-sign its sha)

v887 phone QA (2026-11-17): the cloud sea and far peaks are about 1,800 studs a mesh. At
Automatic fidelity a phone at a low graphics level drew a coarse LOD that rose through the
garden as a pink wall. RenderFidelity is not scriptable at runtime and Rojo syncs this pack
over any Studio edit, so the value lives here.

Only the MeshPart RenderFidelity property chunk is rewritten. Every other chunk must come out
byte-for-byte identical (the script refuses otherwise), so geometry, collision data and the
PhysicalConfigData strings are untouched. With --write the proof's nativeBytes / nativeSha256
move to the new pack and a fidelity note is recorded; nothing else in the proof changes.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from retexture_world_native import HEADER, chunks, pack, sha  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / "assets/world/WorldAssetsNative.rbxm"
PROOF = ROOT / "assets/world/world-v7-native-collision.json"
PRECISE = 1  # Enum.RenderFidelity: Automatic 0, Precise 1, Performance 2


def interleaved_u32(data, count):
    return [int.from_bytes(bytes(data[plane * count + i] for plane in range(4)), "big") for i in range(count)]


def interleave_u32(values):
    count = len(values)
    raw = [v.to_bytes(4, "big") for v in values]
    return bytes(raw[i][plane] for plane in range(4) for i in range(count))


def strings(data, count):
    out, pos = [], 0
    for _ in range(count):
        length = struct.unpack("<I", data[pos:pos + 4])[0]
        out.append(data[pos + 4:pos + 4 + length].decode())
        pos += 4 + length
    return out


def patch(data):
    parts = chunks(data)
    counts, classes = {}, {}
    for chunk in parts:
        if chunk["name"] == b"INST":
            body = chunk["body"]
            class_id, name_len = struct.unpack("<II", body[:8])
            classes[class_id] = body[8:8 + name_len].decode()
            counts[class_id] = struct.unpack("<I", body[9 + name_len:13 + name_len])[0]
    mesh_id = next((cid for cid, name in classes.items() if name == "MeshPart"), None)
    if mesh_id is None:
        raise SystemExit("no MeshPart class in the pack")
    count = counts[mesh_id]
    names, fidelity_index = None, None
    for index, chunk in enumerate(parts):
        if chunk["name"] != b"PROP":
            continue
        body = chunk["body"]
        class_id, name_len = struct.unpack("<II", body[:8])
        if class_id != mesh_id:
            continue
        prop_name = body[8:8 + name_len]
        if prop_name == b"Name":
            names = strings(body[9 + name_len:], count)
        elif prop_name == b"RenderFidelity":
            fidelity_index = index
    if names is None or fidelity_index is None:
        raise SystemExit("MeshPart Name or RenderFidelity chunk missing")
    chunk = parts[fidelity_index]
    body = chunk["body"]
    name_len = struct.unpack("<I", body[4:8])[0]
    head = body[:9 + name_len]
    values = interleaved_u32(body[9 + name_len:], count)
    changed = []
    for i, name in enumerate(names):
        if name.startswith("W7_Backdrop__") and values[i] != PRECISE:
            changed.append(f"{name}: {values[i]} -> {PRECISE}")
            values[i] = PRECISE
    backdrop = sum(1 for name in names if name.startswith("W7_Backdrop__"))
    new_body = head + interleave_u32(values)
    out = bytearray(data[:HEADER])
    for index, part in enumerate(parts):
        out += pack(part, new_body) if index == fidelity_index and changed else part["header"] + part["raw"]
    result = bytes(out)
    # Every other chunk byte-for-byte as before.
    again = chunks(result)
    if len(again) != len(parts):
        raise SystemExit("chunk count changed; refusing")
    for index, (a, b) in enumerate(zip(parts, again)):
        if index == fidelity_index:
            continue
        if a["header"] + a["raw"] != b["header"] + b["raw"]:
            raise SystemExit(f"chunk {index} ({a['name'].decode()}) changed; refusing")
    if changed and interleaved_u32(again[fidelity_index]["body"][9 + name_len:], count) != values:
        raise SystemExit("rewritten fidelity chunk does not read back; refusing")
    return result, changed, backdrop


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    native = NATIVE.read_bytes()
    proof = json.loads(PROOF.read_text())
    if sha(native) != proof["nativeSha256"]:
        raise SystemExit("canonical native pack does not match its proof; refusing")
    result, changed, backdrop = patch(native)
    print(f"backdrop meshes: {backdrop}; to change: {len(changed)}")
    for line in changed:
        print("  " + line)
    if not changed:
        return
    if not args.write:
        print("dry run; pass --write")
        return
    NATIVE.write_bytes(result)
    old = proof["nativeSha256"]
    proof["nativeBytes"], proof["nativeSha256"] = len(result), sha(result)
    proof["fidelity"] = {"note": "W7_Backdrop__* RenderFidelity Precise (scripts/world_backdrop_fidelity.py); only that property chunk moved",
                         "previousNativeSha256": old, "changed": changed}
    PROOF.write_text(json.dumps(proof, indent=2) + "\n")
    print("wrote pack and proof")


if __name__ == "__main__":
    main()
