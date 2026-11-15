"""QA v685 W2 (lamp 3): promote the staged world files and re-sign the native proof.

Explicit, one-off promotion by the W2 owner (2026-11-15). The validator
(scripts/world_native_collision.py) never signs; this script is the deliberate step.

Inputs:
  --native EXPORT.rbxm   Studio Edit export of ServerStorage.WorldAssets
                         (SerializationService:SerializeInstancesAsync), saved outside assets/.
  --staged DIR           artifacts/qa-2026-11-14-v685/w2-lamp/staged
  --readback JSON        artifacts/qa-2026-11-14-v685/w2-lamp/upload-readback.json

It refuses unless, against the current canonical native pack:
  * the export has the same 202 descendants / 170 MeshParts / 30 SurfaceAppearances;
  * exactly the three lamp parts changed MeshId, to the ids in the upload readback;
  * every other MeshPart keeps its exact PhysicalConfigData (bytes and sha256);
  * the staged WorldV7Data.lua is byte-identical to src/shared/WorldV7Data.lua and the
    staged WorldAssets.rbxmx differs from canonical only in those three parts.
Then (with --write) it copies the staged XML and pending JSON into assets/world,
replaces WorldAssetsNative.rbxm and rewrites world-v7-native-collision.json.
Without --write it only reports. Run `python scripts/world_native_collision.py --check` after.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
import world_native_collision as guard  # noqa: E402

CHANGED = ("W7_LampOrbs__glow_warm", "W7_Stations__marble_smooth", "W7_Stations__palette")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def to_xml(native: Path, work: Path) -> Path:
    """Rojo re-serializes the binary model as XML (properties and shared strings intact)."""
    local = work / (native.stem + ".rbxm")
    if local.resolve() != native.resolve():
        shutil.copyfile(native, local)
    project = work / (native.stem + ".project.json")
    project.write_text(json.dumps({"name": "WorldAssets", "tree": {"$path": local.name}}), encoding="utf-8")
    out = work / (native.stem + ".rbxmx")
    subprocess.run(["rojo", "build", str(project), "-o", str(out)], check=True, cwd=ROOT, capture_output=True)
    return out


def read_model(path: Path):
    root = ET.parse(path).getroot()
    shared = {n.attrib["md5"]: base64.b64decode(n.text or "") for n in root.iter("SharedString") if "md5" in n.attrib}
    parts, counts = {}, {"descendants": 0, "meshParts": 0, "surfaceAppearances": 0}

    def walk(item, depth):
        cls = item.attrib.get("class")
        if depth:
            counts["descendants"] += 1
        props = item.find("Properties")
        name = next((p.text for p in props if p.attrib.get("name") == "Name"), None) if props is not None else None
        if cls == "SurfaceAppearance":
            counts["surfaceAppearances"] += 1
        if cls == "MeshPart":
            counts["meshParts"] += 1
            facts = {}
            for p in props:
                n = p.attrib.get("name")
                if n == "PhysicalConfigData":
                    blob = shared[p.text]
                    facts["bytes"], facts["sha256"] = len(blob), sha(blob)
                elif n in ("MeshId", "MeshContent"):
                    node = p.find("url") if p.find("url") is not None else p.find("uri")
                    facts["mesh"] = node.text if node is not None else None
                elif n in ("CollisionFidelity", "CanCollide", "CanQuery", "Anchored"):
                    facts[n] = p.text
            if name in parts:
                raise SystemExit("duplicate MeshPart name: " + str(name))
            parts[name] = facts
        for child in item.findall("Item"):
            walk(child, depth + 1)

    tops = root.findall("Item")
    if len(tops) != 1 or tops[0].attrib.get("class") != "Folder":
        raise SystemExit("the export must be exactly one Folder (WorldAssets)")
    walk(tops[0], 0)
    return parts, counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", type=Path, required=True)
    parser.add_argument("--staged", type=Path, required=True)
    parser.add_argument("--readback", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, help="write the comparison as JSON")
    parser.add_argument("--note", default="", help="free text recorded in the proof's provenance (probes, method)")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    proof_path = ROOT / guard.PROOF
    proof = json.loads(proof_path.read_text(encoding="utf-8"))
    old_native = (ROOT / guard.NATIVE).read_bytes()
    already = sha(old_native) != proof["nativeSha256"]
    if already:
        raise SystemExit("canonical native pack does not match its own proof; refusing to compare against it")
    new_native = args.native.read_bytes()
    readback = json.loads(args.readback.read_text(encoding="utf-8"))
    want_ids = {p["name"]: "rbxassetid://" + str(p["meshId"]) for p in readback["parts"]}
    previous_ids = {name: "rbxassetid://" + str(value) for name, value in readback["checkpoint"]["previousMeshIds"].items()}
    if set(want_ids) != set(CHANGED):
        raise SystemExit("upload readback does not name exactly the three lamp parts")

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        old_dir, new_dir = work / "old", work / "new"
        old_dir.mkdir(); new_dir.mkdir()
        (old_dir / "model.rbxm").write_bytes(old_native)
        (new_dir / "model.rbxm").write_bytes(new_native)
        old_parts, old_counts = read_model(to_xml(old_dir / "model.rbxm", old_dir))
        new_parts, new_counts = read_model(to_xml(new_dir / "model.rbxm", new_dir))

    problems = []
    if old_counts != new_counts:
        problems.append(f"instance counts changed: {old_counts} -> {new_counts}")
    if set(old_parts) != set(new_parts):
        problems.append("MeshPart name set changed: " + ", ".join(sorted(set(old_parts) ^ set(new_parts))))
    for name, facts in old_parts.items():
        if {"bytes": facts.get("bytes"), "sha256": facts.get("sha256")} != proof["physicalConfigData"].get(name):
            problems.append("canonical pack disagrees with its proof at " + name)
    mesh_changed, buffer_changed, flag_changed = [], [], []
    for name in sorted(set(old_parts) & set(new_parts)):
        old, new = old_parts[name], new_parts[name]
        if old.get("mesh") != new.get("mesh"):
            mesh_changed.append(name)
        if (old.get("bytes"), old.get("sha256")) != (new.get("bytes"), new.get("sha256")):
            buffer_changed.append(name)
        for key in ("CollisionFidelity", "CanCollide", "CanQuery", "Anchored"):
            if old.get(key) != new.get(key):
                flag_changed.append(f"{name}.{key}: {old.get(key)} -> {new.get(key)}")
    if sorted(mesh_changed) != sorted(CHANGED):
        problems.append("MeshId changed on: " + ", ".join(mesh_changed) + " (expected exactly the three lamp parts)")
    for name in CHANGED:
        if name in new_parts and new_parts[name].get("mesh") != want_ids[name]:
            problems.append(f"{name} MeshId {new_parts[name].get('mesh')} is not the uploaded {want_ids[name]}")
        if name in old_parts and old_parts[name].get("mesh") != previous_ids.get(name):
            problems.append(f"{name} previous MeshId {old_parts[name].get('mesh')} is not the readback's {previous_ids.get(name)}")
    protected = [name for name in buffer_changed if name not in CHANGED]
    if protected:
        problems.append("protected collision buffers changed: " + ", ".join(protected))
    if flag_changed:
        problems.append("collision flags changed: " + "; ".join(flag_changed))
    for name in CHANGED:
        if name in new_parts and new_parts[name].get("bytes") is None:
            problems.append(name + " has no PhysicalConfigData in the export")
    solid = new_parts.get("W7_Stations__marble_smooth", {})
    if solid.get("CanCollide") != "true" or (solid.get("bytes") or 0) <= 15:
        problems.append("W7_Stations__marble_smooth (the solid post) has no real collision buffer")

    staged_xml = (args.staged / "WorldAssets.rbxmx").read_bytes()
    staged_lua = (args.staged / "WorldV7Data.lua").read_bytes()
    staged_pending = (args.staged / "world-v7-pending.json").read_bytes()
    canonical_xml = (ROOT / guard.XML).read_bytes()
    canonical_lua = (ROOT / guard.LUA).read_bytes()
    if staged_lua != canonical_lua:
        problems.append("staged WorldV7Data.lua is not byte-identical to src/shared/WorldV7Data.lua")
    old_lines = canonical_xml.replace(b"\r\n", b"\n").split(b"\n")
    new_lines = staged_xml.replace(b"\r\n", b"\n").split(b"\n")
    xml_diff = [i + 1 for i, (a, b) in enumerate(zip(old_lines, new_lines)) if a != b]
    if len(old_lines) != len(new_lines) or len(xml_diff) != 6:
        problems.append(f"staged WorldAssets.rbxmx differs from canonical on {len(xml_diff)} lines (expected 6: three MeshIds, three InitialSizes)")
    else:
        for i in xml_diff:
            line = new_lines[i - 1]
            if b'name="MeshId"' not in line and b'name="InitialSize"' not in line:
                problems.append(f"staged WorldAssets.rbxmx line {i} is not a MeshId/InitialSize change")
        for mesh in want_ids.values():
            if mesh.encode() not in staged_xml:
                problems.append("staged WorldAssets.rbxmx lacks " + mesh)
    pending = json.loads(staged_pending.decode("utf-8"))
    if sorted(pending.get("changed", [])) != sorted(CHANGED) or sorted(pending.get("confirmedImport", {})) != sorted(CHANGED):
        problems.append("staged pending file does not confirm exactly the three lamp parts")

    report = {
        "old": {"nativeBytes": len(old_native), "nativeSha256": sha(old_native), "counts": old_counts},
        "new": {"nativeBytes": len(new_native), "nativeSha256": sha(new_native), "counts": new_counts},
        "meshIdChanged": {name: {"from": old_parts[name].get("mesh"), "to": new_parts[name].get("mesh")} for name in mesh_changed if name in new_parts},
        "collisionBufferChanged": {name: {"from": {"bytes": old_parts[name].get("bytes"), "sha256": old_parts[name].get("sha256")},
                                           "to": {"bytes": new_parts[name].get("bytes"), "sha256": new_parts[name].get("sha256")}} for name in buffer_changed},
        "protectedBuffersIdentical": len(old_parts) - len(buffer_changed),
        "stagedXmlLinesChanged": xml_diff,
        "problems": problems,
    }
    if args.evidence:
        args.evidence.write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=1))
    if problems:
        raise SystemExit("REFUSED: " + "; ".join(problems))
    if not args.write:
        print("dry run: nothing written (pass --write)")
        return

    (ROOT / guard.XML).write_bytes(staged_xml)
    (ROOT / "assets/world/world-v7-pending.json").write_bytes(staged_pending)
    (ROOT / guard.NATIVE).write_bytes(new_native)
    proof["nativeBytes"], proof["nativeSha256"] = len(new_native), sha(new_native)
    proof["xmlSha256"], proof["luaSha256"] = sha(staged_xml), sha(canonical_lua)
    proof["inputs"] = guard.input_hashes(ROOT)
    proof["physicalConfigData"] = {name: {"bytes": facts["bytes"], "sha256": facts["sha256"]} for name, facts in new_parts.items()}
    proof["provenance"] = {
        "source": str(args.native.resolve().relative_to(ROOT)).replace("\\", "/") if ROOT in args.native.resolve().parents else args.native.name,
        "method": "Studio Edit SerializationService:SerializeInstancesAsync({ServerStorage.WorldAssets}) after ApplyMesh of the three lamp-3 parts (QA v685 W2)",
        "descendants": new_counts["descendants"], "meshParts": new_counts["meshParts"], "surfaceAppearances": new_counts["surfaceAppearances"],
        "previousNativeSha256": report["old"]["nativeSha256"],
        "changedMeshParts": list(CHANGED),
        "protectedBuffersIdentical": report["protectedBuffersIdentical"],
        "uploadReadback": "artifacts/qa-2026-11-14-v685/w2-lamp/upload-readback.json",
        "evidence": "artifacts/qa-2026-11-14-v685/w2-lamp/native-promotion.json",
        "note": args.note,
    }
    proof["promotion"] = "Explicit W2 lamp-3 promotion (2026-11-15, artifacts/qa-2026-11-14-v685/w2-lamp/promote_native.py); validator never rewrites this manifest."
    # Same shape as the previous proof file: two-space indent, CRLF.
    proof_path.write_bytes((json.dumps(proof, indent=2) + "\n").replace("\n", "\r\n").encode("utf-8"))
    print("promoted; now run: python scripts/world_native_collision.py --check")


if __name__ == "__main__":
    main()
