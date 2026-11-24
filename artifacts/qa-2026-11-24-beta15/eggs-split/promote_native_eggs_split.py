"""Eggs station split (EGG-CORNER-BUILD-PLAN 6.2): promote the staged world files and re-sign the native proof.

Explicit, one-off promotion (2026-11-24), adapted from artifacts/qa-2026-11-14-v685/w2-lamp/promote_native.py with the
architect review's asserts (EGG-STATION-SPLIT-PLAN.md). The validator (scripts/world_native_collision.py) never signs.

Inputs:
  --native EXPORT.rbxm   Studio Edit export (SerializationService:SerializeInstancesAsync) of an unparented clone of
                         ServerStorage.WorldAssets after the split, saved outside assets/.
  --staged DIR           artifacts/qa-2026-11-24-beta15/eggs-split/staged
  --readback JSON        artifacts/qa-2026-11-24-beta15/eggs-split/upload-readback.json

It refuses unless, against the current canonical native pack:
  * descendants and MeshParts grew by exactly 4, SurfaceAppearances are unchanged;
  * the MeshPart names lost exactly the 2 dropped and gained exactly the 6 added, all parented to WorldV7;
  * every untouched MeshPart (and every other instance) keeps every property byte-identical, its collision buffer too;
  * the 2 renamed parts are their sources with only Name changed (same mesh, same buffer, same SurfaceAppearance);
  * the 4 changed parts changed MeshId from the readback's previous ids to the readback ids, and only mesh-derived
    properties moved; the 4 new parts match their sibling in every property that is not mesh-derived or placement;
  * every MeshPart matches the staged WorldAssets.rbxmx by name (mesh, texture, size, raw size, CFrame, flags, material,
    colour, transparency, SurfaceAppearance children), and the 3 new colliding parts carry a real collision buffer;
  * the staged XML differs from canonical only in the 10 split parts, the staged Lua only in their part entries (by
    meaning, motion included), the staged pending confirms exactly the 10;
  * the proof inputs that change on --write are exactly manifest, pending, studio-import, both FBXs and dressing-import.
With --write it copies the staged XML, Lua and pending into place, replaces WorldAssetsNative.rbxm and rewrites
world-v7-native-collision.json. Run `python scripts/world_native_collision.py --check` after.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
import world_native_collision as guard  # noqa: E402

HERE = "artifacts/qa-2026-11-24-beta15/eggs-split"
CHANGED = ("W7_Stations__marble", "W7_Stations__marble_smooth", "W7_Stations__palette", "W7_Stations__trim")
NEW = {"W7_EggsStation__marble": "W7_Stations__marble", "W7_EggsStation__marble_smooth": "W7_Stations__marble_smooth",
       "W7_EggsStation__palette": "W7_Stations__palette", "W7_EggsStation__trim": "W7_Stations__trim"}
RENAMED = {"W7_EggsStation__foliage": "W7_Stations__foliage", "W7_EggsStation__glow_warm": "W7_NestHalo__glow_warm"}
SPLIT = set(CHANGED) | set(NEW) | set(RENAMED)
DROPPED = set(RENAMED.values())
COLLIDING_NEW = ("W7_EggsStation__marble", "W7_EggsStation__marble_smooth", "W7_EggsStation__trim")
# Properties a new mesh legitimately moves (Studio recomputes them from the mesh and its collision bake).
MESH_DERIVED = {"AeroMeshData", "MeshContent", "InitialSize", "PhysicalConfigData", "PhysicsData", "UnscaledCofm",
                "UnscaledVolInertiaDiags", "UnscaledVolInertiaOffDiags", "UnscaledVolume", "VertexCount"}
PLACEMENT = {"Name", "CFrame", "size", "TextureContent", "Material", "Color3uint8", "CanCollide", "CanQuery",
             "CastShadow", "DoubleSided", "Transparency"}
# Engine noise this Studio adds on any re-serialization (none of it authored, none of it collision):
#  * TexturePackContent on a SurfaceAppearance: an engine-generated packed copy of its maps (RobloxScript-only: scripts
#    can neither read nor write it). The old pack (an older Studio) has it null.
#  * float32 rounding of placement (e.g. 39.0789 -> 39.078896, a 8.7e-8 rotation term -> 0): within 1e-6 relative or 1e-5 stud.
#  * cached mass properties recomputed from an unchanged collision buffer (Unscaled*, VertexCount), only where
#    PhysicalConfigData is byte-identical (the lamp-3 promotion saw the same on its parts).
ENGINE_DERIVED = {"TexturePackContent"}
CACHED_MASS = {"UnscaledCofm", "UnscaledVolInertiaDiags", "UnscaledVolInertiaOffDiags", "UnscaledVolume", "VertexCount"}
NUMERIC_TOLERANCE = 1e-6   # code review: ~8 float32 steps; only float / Vector3 / CFrame leaves
NUMERIC_TAGS = {"float", "Vector3", "CoordinateFrame"}
NUMERIC_FLOOR = 1e-5       # studs: Studio's re-serialized CFrames move up to 7.5e-6 near the origin
CHANGED_INPUTS = {"assets/world/" + n for n in ("world-v7-manifest.json", "world-v7-pending.json",
                                                "world-v7-studio-import.json", "world-v7.fbx", "world-v7-declutter.fbx",
                                                "world-dressing-import.json")}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def to_xml(native_bytes: bytes, work: Path) -> Path:
    """Rojo re-serializes the binary model as XML (properties and shared strings intact)."""
    (work / "model.rbxm").write_bytes(native_bytes)
    project = work / "model.project.json"
    project.write_text(json.dumps({"name": "WorldAssets", "tree": {"$path": "model.rbxm"}}), encoding="utf-8")
    out = work / "model.rbxmx"
    subprocess.run(["rojo", "build", str(project), "-o", str(out)], check=True, cwd=ROOT, capture_output=True)
    return out


def canon(prop, shared):
    """A property as comparable text: shared strings by content hash, everything else by its XML."""
    if prop.tag == "SharedString":
        return "shared:" + sha(shared[prop.text])
    return ET.tostring(prop, encoding="unicode").strip()


def read_model(path: Path):
    root = ET.parse(path).getroot()
    shared = {n.attrib["md5"]: base64.b64decode(n.text or "") for n in root.iter("SharedString") if "md5" in n.attrib}
    insts, counts = {}, {"descendants": 0, "meshParts": 0, "surfaceAppearances": 0}

    def walk(item, path, depth):
        cls = item.attrib.get("class")
        props = item.find("Properties")
        name = next(p.text for p in props if p.attrib.get("name") == "Name")
        key = path + "/" + name
        if key in insts:
            raise SystemExit("duplicate instance path: " + key)
        facts = {"class": cls, "props": {p.attrib["name"]: canon(p, shared) for p in props}, "raw": props,
                 "children": sorted((c.attrib["class"], c.find("Properties").find("string[@name='Name']").text)
                                    for c in item.findall("Item"))}
        if cls == "MeshPart":
            counts["meshParts"] += 1
            blob = shared[props.find("SharedString[@name='PhysicalConfigData']").text]
            facts["bytes"], facts["sha256"] = len(blob), sha(blob)
        if cls == "SurfaceAppearance":
            counts["surfaceAppearances"] += 1
        if depth:
            counts["descendants"] += 1
        insts[key] = facts
        for child in item.findall("Item"):
            walk(child, key, depth + 1)

    tops = root.findall("Item")
    if len(tops) != 1 or tops[0].attrib.get("class") != "Folder":
        raise SystemExit("the export must be exactly one Folder (WorldAssets)")
    walk(tops[0], "", 0)
    return insts, counts


def mesh_parts(insts):
    out = {}
    for key, facts in insts.items():
        if facts["class"] == "MeshPart":
            name = key.rsplit("/", 1)[1]
            if name in out:
                raise SystemExit("duplicate MeshPart name: " + name)
            out[name] = dict(facts, path=key)
    return out


def numbers_close(a, b):
    """Two property elements of the same type whose numeric leaves agree within NUMERIC_TOLERANCE."""
    if a is None or b is None or a.tag != b.tag or a.tag not in NUMERIC_TAGS:
        return False
    la, lb = list(a.iter()), list(b.iter())
    if len(la) != len(lb) or any(x.tag != y.tag for x, y in zip(la, lb)):
        return False
    for x, y in zip(la, lb):
        tx, ty = (x.text or "").strip(), (y.text or "").strip()
        if tx == ty:
            continue
        try:
            if abs(float(tx) - float(ty)) > max(NUMERIC_FLOOR, NUMERIC_TOLERANCE * abs(float(ty))):
                return False
        except ValueError:
            return False
    return True


def classify(old, new, same_buffer, noise):
    """Property names that really differ between two instances; engine noise is tallied in `noise`, not returned."""
    real = []
    for k in sorted(set(old["props"]) | set(new["props"])):
        if old["props"].get(k) == new["props"].get(k):
            continue
        a, b = old["raw"].find(f"*[@name='{k}']"), new["raw"].find(f"*[@name='{k}']")
        if k in ENGINE_DERIVED:
            noise[k] = noise.get(k, 0) + 1
        elif k in CACHED_MASS and same_buffer:
            noise["cached mass (" + k + ")"] = noise.get("cached mass (" + k + ")", 0) + 1
        elif numbers_close(a, b):
            noise["float32 " + k] = noise.get("float32 " + k, 0) + 1
        else:
            real.append(k)
    return real


def num(text):
    return float(text)


def vec(prop):
    return [num(prop.find(a).text) for a in ("X", "Y", "Z")]


def cf(prop):
    return [num(prop.find(a).text) for a in ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]


def uri(prop):
    node = prop.find("uri") if prop.find("uri") is not None else prop.find("url")
    return (node.text or "") if node is not None else ""


def close(a, b):
    return len(a) == len(b) and all(abs(x - y) <= 1e-5 * max(1.0, abs(y)) for x, y in zip(a, b))


def staged_parts(path: Path):
    root = ET.parse(path).getroot()
    out, owners = {}, {}
    for item in root.iter("Item"):
        for child in item.findall("Item"):
            owners[child] = item
    for item in root.iter("Item"):
        if item.attrib["class"] != "MeshPart":
            continue
        props = {p.attrib["name"]: p for p in item.find("Properties")}
        parent = owners.get(item)
        parent_name = parent.find("Properties").find("string[@name='Name']").text if parent is not None else None
        out[props["Name"].text] = {"props": props, "parent": parent_name, "children": sorted(
            (c.attrib["class"], c.find("Properties").find("string[@name='Name']").text,
             tuple(sorted(uri(q) for q in c.find("Properties") if q.tag == "Content"))) for c in item.findall("Item"))}
    return out


def compare_to_staged(name, part, model, staged):
    """Every authored property of one MeshPart against the staged XML."""
    want, have, problems = staged["props"], part["raw"], []
    get = lambda n: have.find(f"*[@name='{n}']")  # noqa: E731
    checks = [
        ("MeshId", uri(get("MeshContent")) == uri(want["MeshId"])),
        ("TextureID", uri(get("TextureContent")) == uri(want["TextureID"])),
        ("Size", close(vec(get("size")), vec(want["Size"]))),
        ("InitialSize", close(vec(get("InitialSize")), vec(want["InitialSize"]))),
        ("Material", get("Material").text == want["Material"].text),
        ("Color", int(get("Color3uint8").text) & 0xFFFFFF == int(want["Color3uint8"].text) & 0xFFFFFF),
        ("parent", part["path"].rsplit("/", 2)[1] == staged["parent"] and (name not in SPLIT or staged["parent"] == "WorldV7")),
    ]
    # The dressing templates (W7D_*) carry no CFrame/Transparency in the XML (they are placed at runtime).
    if "CFrame" in want:
        checks.append(("CFrame", close(cf(get("CFrame")), cf(want["CFrame"]))))
    if "Transparency" in want:
        checks.append(("Transparency", close([num(get("Transparency").text)], [num(want["Transparency"].text)])))
    for flag in ("Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "DoubleSided"):
        checks.append((flag, get(flag).text == want[flag].text))
    kids = []
    for cls, child in part["children"]:
        facts = model[part["path"] + "/" + child]
        kids.append((cls, child, tuple(sorted(uri(q) for q in facts["raw"]
                                             if q.tag == "Content" and uri(q) and q.attrib["name"] not in ENGINE_DERIVED))))
    checks.append(("SurfaceAppearance children", sorted(kids) == sorted(
        (c, n, tuple(u for u in us if u)) for c, n, us in staged["children"])))
    problems += [f"{name}.{label} differs from the staged XML" for label, ok in checks if not ok]
    return problems


def lua_parts(data: bytes):
    text = data.decode("utf-8")
    body = json.loads(re.search(r"\[=\[(.*)\]=\]", text, re.S).group(1))
    return body, re.sub(r"\[=\[.*\]=\]", "", text, flags=re.S).replace("\r", "")


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
    if sha(old_native) != proof["nativeSha256"]:
        raise SystemExit("canonical native pack does not match its own proof; refusing to compare against it")
    new_native = args.native.read_bytes()
    readback = json.loads(args.readback.read_text(encoding="utf-8"))
    want_ids = {p["name"]: "rbxassetid://" + str(p["meshId"]) for p in readback["parts"]}
    previous_ids = {n: "rbxassetid://" + str(v) for n, v in readback["checkpoint"]["previousMeshIds"].items()}
    problems = []
    if set(want_ids) != SPLIT or set(previous_ids) != set(CHANGED):
        problems.append("upload readback does not name exactly the 10 split parts / the 4 changed")

    with tempfile.TemporaryDirectory() as tmp:
        old_dir, new_dir = Path(tmp) / "old", Path(tmp) / "new"
        old_dir.mkdir()
        new_dir.mkdir()
        old_all, old_counts = read_model(to_xml(old_native, old_dir))
        new_all, new_counts = read_model(to_xml(new_native, new_dir))
    old_parts, new_parts = mesh_parts(old_all), mesh_parts(new_all)

    # counts and names
    expect = {"descendants": old_counts["descendants"] + 4, "meshParts": old_counts["meshParts"] + 4,
              "surfaceAppearances": old_counts["surfaceAppearances"]}
    if new_counts != expect:
        problems.append(f"instance counts {new_counts}, expected {expect}")
    if set(old_parts) - set(new_parts) != DROPPED or set(new_parts) - set(old_parts) != set(NEW) | set(RENAMED):
        problems.append("MeshPart names: removed " + ", ".join(sorted(set(old_parts) - set(new_parts))) +
                        "; added " + ", ".join(sorted(set(new_parts) - set(old_parts))))
    for name, facts in old_parts.items():
        if {"bytes": facts["bytes"], "sha256": facts["sha256"]} != proof["physicalConfigData"].get(name):
            problems.append("canonical pack disagrees with its proof at " + name)

    # every untouched instance: every property identical (MeshParts by name, the rest by path)
    renamed_paths = {old_parts[src]["path"]: new_parts[dst]["path"] for dst, src in RENAMED.items()
                     if src in old_parts and dst in new_parts}
    untouched, noise = 0, {}
    for key, old in old_all.items():
        if old["class"] == "MeshPart" and key.rsplit("/", 1)[1] in SPLIT | DROPPED:
            continue
        moved = next((renamed_paths[p] + key[len(p):] for p in renamed_paths if key.startswith(p + "/")), key)
        new = new_all.get(moved)
        if new is None:
            problems.append("instance missing after the split: " + key)
            continue
        same_children = old["children"] == new["children"] or key.endswith("/WorldV7")
        same_buffer = old.get("sha256") == new.get("sha256")
        diff = classify(old, new, same_buffer, noise)
        if diff or not same_children:
            problems.append(f"untouched {key} changed: {diff or 'children'}")
        untouched += 1
    v7_children = {n for _, n in new_all["/WorldAssets/WorldV7"]["children"]}
    old_v7 = {n for _, n in old_all["/WorldAssets/WorldV7"]["children"]}
    if v7_children != (old_v7 - DROPPED) | set(NEW) | set(RENAMED):
        problems.append("WorldV7 children are not the old set minus the dropped plus the split parts")

    # renamed: the source with only Name changed (children too)
    for dst, src in RENAMED.items():
        if src not in old_parts or dst not in new_parts:
            continue
        o, n = old_parts[src], new_parts[dst]
        diff = classify(o, n, o["sha256"] == n["sha256"], noise)
        if diff != ["Name"] or o["children"] != n["children"] or o["sha256"] != n["sha256"]:
            problems.append(f"renamed {dst} differs from {src} beyond its Name: {diff}")
        for cls, child in o["children"]:
            if classify(old_all[o["path"] + "/" + child], new_all[n["path"] + "/" + child], True, noise):
                problems.append(f"renamed {dst}'s {child} changed")
        if want_ids.get(dst) != uri(n["raw"].find("*[@name='MeshContent']")):
            problems.append(f"renamed {dst} mesh is not the readback's kept id")

    # changed: new mesh from the readback, only mesh-derived properties moved
    for name in CHANGED:
        if name not in old_parts or name not in new_parts:
            continue
        o, n = old_parts[name], new_parts[name]
        if uri(o["raw"].find("*[@name='MeshContent']")) != previous_ids.get(name):
            problems.append(f"{name} previous mesh is not the readback's previous id")
        if uri(n["raw"].find("*[@name='MeshContent']")) != want_ids.get(name):
            problems.append(f"{name} mesh is not the uploaded id")
        diff = set(classify(o, n, False, noise))
        if diff - MESH_DERIVED or "MeshContent" not in diff:
            problems.append(f"{name} moved more than mesh-derived properties: {sorted(diff - MESH_DERIVED)}")
        if o["children"] != n["children"]:
            problems.append(f"{name} children changed")

    # new: the sibling's settings in everything that is not mesh-derived or placement; no attributes, tags, children
    for name, sibling in NEW.items():
        if name not in new_parts:
            continue
        n, s = new_parts[name], new_parts[sibling]
        diff = {k for k in set(n["props"]) | set(s["props"]) if n["props"].get(k) != s["props"].get(k)}
        if diff - MESH_DERIVED - PLACEMENT:
            problems.append(f"new {name} differs from its sibling {sibling} in {sorted(diff - MESH_DERIVED - PLACEMENT)}")
        raw = n["raw"]
        if (raw.find("*[@name='AttributesSerialize']").text or "").strip() or (raw.find("*[@name='Tags']").text or "").strip():
            problems.append(f"new {name} carries attributes or tags")
        if n["children"]:
            problems.append(f"new {name} has children")
        if uri(raw.find("*[@name='MeshContent']")) != want_ids.get(name):
            problems.append(f"new {name} mesh is not the uploaded id")

    # every MeshPart against the staged XML by name; real collision on the colliding split parts
    staged_xml_path = args.staged / "WorldAssets.rbxmx"
    staged = staged_parts(staged_xml_path)
    if set(staged) != set(new_parts):
        problems.append("staged XML MeshPart names differ from the export: " + ", ".join(sorted(set(staged) ^ set(new_parts))))
    # Untouched parts are held to the old pack above (which already differs from the XML in Studio's own ways, e.g. a
    # flat glow's raw height 0.001 for 0); the split parts are held to the staged XML.
    for name in sorted(SPLIT & set(staged) & set(new_parts)):
        problems += compare_to_staged(name, new_parts[name], new_all, staged[name])
    for name in COLLIDING_NEW + ("W7_Stations__marble", "W7_Stations__marble_smooth", "W7_Stations__trim"):
        part = new_parts.get(name, {})
        if part.get("raw") is None or part["raw"].find("*[@name='CanCollide']").text != "true" or part.get("bytes", 0) <= 15:
            problems.append(f"{name} has no real collision buffer")
    buffer_changed = sorted(n for n in set(old_parts) & set(new_parts)
                            if (old_parts[n]["bytes"], old_parts[n]["sha256"]) != (new_parts[n]["bytes"], new_parts[n]["sha256"]))
    if set(buffer_changed) - set(CHANGED):
        problems.append("protected collision buffers changed: " + ", ".join(sorted(set(buffer_changed) - set(CHANGED))))

    # staged XML vs canonical: only the split parts (by name; referents shift)
    canon_xml = staged_parts(ROOT / guard.XML)
    xml_changed = sorted(n for n in set(canon_xml) | set(staged)
                         if n not in canon_xml or n not in staged or
                         {k: ET.tostring(v) for k, v in canon_xml[n]["props"].items()} !=
                         {k: ET.tostring(v) for k, v in staged[n]["props"].items()} or
                         canon_xml[n]["children"] != staged[n]["children"])
    if set(xml_changed) != SPLIT | DROPPED:
        problems.append("staged XML differs from canonical in: " + ", ".join(sorted(set(xml_changed) ^ (SPLIT | DROPPED))))
    for name in CHANGED:
        if name in canon_xml and name in staged:
            diff = sorted(k for k in canon_xml[name]["props"] if ET.tostring(canon_xml[name]["props"][k]) !=
                          ET.tostring(staged[name]["props"].get(k, ET.Element("x"))))
            if diff != ["InitialSize", "MeshId"]:
                problems.append(f"staged XML {name} moved {diff} (expected MeshId, InitialSize)")
    for dst, src in RENAMED.items():
        a, b = canon_xml.get(src), staged.get(dst)
        if a and b:
            diff = sorted(k for k in a["props"] if ET.tostring(a["props"][k]) != ET.tostring(b["props"].get(k, ET.Element("x"))))
            if diff != ["Name"] or a["children"] != b["children"]:
                problems.append(f"staged XML {dst} differs from {src} beyond its Name: {diff}")

    # staged Lua vs canonical by meaning
    staged_lua = (args.staged / "WorldV7Data.lua").read_bytes()
    old_body, old_shell = lua_parts((ROOT / guard.LUA).read_bytes())
    new_body, new_shell = lua_parts(staged_lua)
    if old_shell != new_shell:
        problems.append("staged Lua differs outside its JSON")
    if {k: v for k, v in old_body.items() if k not in ("parts", "meshParts")} != \
            {k: v for k, v in new_body.items() if k not in ("parts", "meshParts")}:
        problems.append("staged Lua top-level data changed")
    if new_body.get("meshParts") != old_body.get("meshParts", 0) + 4:
        problems.append("staged Lua meshParts is not +4")
    op, np_ = old_body["parts"], new_body["parts"]
    if set(op) - set(np_) != DROPPED or set(np_) - set(op) != set(NEW) | set(RENAMED):
        problems.append("staged Lua part names are not the split")
    if any(op[k] != np_[k] for k in set(op) & set(np_)):
        problems.append("staged Lua changed existing entries: " + ", ".join(k for k in sorted(set(op) & set(np_)) if op[k] != np_[k]))
    if np_.get("W7_EggsStation__glow_warm") != op.get("W7_NestHalo__glow_warm"):
        problems.append("halo Lua entry is not the old NestHalo entry (region and motion must be kept)")
    if np_.get("W7_EggsStation__foliage") != dict(op.get("W7_Stations__foliage", {}), region="EggsStation"):
        problems.append("foliage Lua entry is not the old Stations entry with region EggsStation")
    for name in NEW:
        entry = np_.get(name, {})
        if entry.get("region") != "EggsStation" or "motion" in entry or entry.get("collide") != (name in COLLIDING_NEW):
            problems.append(f"Lua {name} region/collide/motion wrong: {entry}")

    # staged pending
    staged_pending = (args.staged / "world-v7-pending.json").read_bytes()
    pending = json.loads(staged_pending.decode("utf-8"))
    if (set(pending.get("changed", [])) != set(CHANGED) or set(pending.get("added", [])) != set(NEW) | set(RENAMED)
            or set(pending.get("dropped", [])) != DROPPED or set(pending.get("confirmedImport", {})) != SPLIT):
        problems.append("staged pending does not confirm exactly the split")

    # the proof inputs that move
    after = guard.input_hashes(ROOT)
    after["assets/world/world-v7-pending.json"] = sha(staged_pending)
    moved_inputs = {k for k in guard.INPUTS if proof["inputs"].get(k) != after[k]}
    if moved_inputs != CHANGED_INPUTS:
        problems.append("proof inputs moving: " + ", ".join(sorted(moved_inputs)) + " (expected exactly the split's six)")

    report = {
        "old": {"nativeBytes": len(old_native), "nativeSha256": sha(old_native), "counts": old_counts},
        "new": {"nativeBytes": len(new_native), "nativeSha256": sha(new_native), "counts": new_counts},
        "changed": {n: {"from": uri(old_parts[n]["raw"].find("*[@name='MeshContent']")),
                        "to": uri(new_parts[n]["raw"].find("*[@name='MeshContent']")),
                        "bufferFrom": old_parts[n]["bytes"], "bufferTo": new_parts[n]["bytes"]}
                    for n in CHANGED if n in old_parts and n in new_parts},
        "added": {n: {"mesh": uri(new_parts[n]["raw"].find("*[@name='MeshContent']")), "buffer": new_parts[n]["bytes"],
                      "canCollide": new_parts[n]["raw"].find("*[@name='CanCollide']").text}
                  for n in sorted(set(NEW) | set(RENAMED)) if n in new_parts},
        "renamed": RENAMED,
        "dropped": sorted(DROPPED),
        "untouchedInstancesIdentical": untouched,
        "engineNoiseAllowed": noise,
        "protectedBuffersIdentical": len(set(old_parts) & set(new_parts)) - len(buffer_changed),
        "stagedXmlPartsChanged": xml_changed,
        "proofInputsMoving": sorted(moved_inputs),
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

    staged_xml = staged_xml_path.read_bytes()
    (ROOT / guard.XML).write_bytes(staged_xml)
    (ROOT / guard.LUA).write_bytes(staged_lua)
    (ROOT / "assets/world/world-v7-pending.json").write_bytes(staged_pending)
    (ROOT / guard.NATIVE).write_bytes(new_native)
    proof["nativeBytes"], proof["nativeSha256"] = len(new_native), sha(new_native)
    proof["xmlSha256"], proof["luaSha256"] = sha(staged_xml), sha(staged_lua)
    proof["inputs"] = guard.input_hashes(ROOT)
    proof["physicalConfigData"] = {name: {"bytes": f["bytes"], "sha256": f["sha256"]} for name, f in new_parts.items()}
    previous = proof.get("provenance", {})
    proof["provenance"] = {
        "source": HERE + "/" + args.native.name,
        "method": "Studio Edit SerializationService:SerializeInstancesAsync of an unparented clone of ServerStorage.WorldAssets "
                  "after the Eggs station split: 4 Stations parts ApplyMesh, 4 new parts cloned from their sibling + ApplyMesh, "
                  "2 renamed (EGG-CORNER-BUILD-PLAN 6.2). The place's own WorldAssets was not modified.",
        "descendants": new_counts["descendants"], "meshParts": new_counts["meshParts"],
        "surfaceAppearances": new_counts["surfaceAppearances"],
        "previousNativeSha256": report["old"]["nativeSha256"],
        "changedMeshParts": list(CHANGED), "addedMeshParts": sorted(NEW), "renamedMeshParts": RENAMED,
        "droppedMeshParts": sorted(DROPPED),
        "protectedBuffersIdentical": report["protectedBuffersIdentical"],
        "uploadReadback": HERE + "/upload-readback.json",
        "evidence": HERE + "/native-promotion.json",
        "dressingImportRebound": "world-dressing-import.json was stale since 2f60802; its regenerated XML/Lua equal canonical "
                                 "(checked: staged XML/Lua differ only in the split parts)",
        "note": args.note,
    }
    if "retexture" in previous:
        proof["provenance"]["retexture"] = previous["retexture"]
    proof["promotion"] = ("Explicit Eggs station split promotion (2026-11-24, " + HERE + "/promote_native_eggs_split.py); "
                          "validator never rewrites this manifest.")
    proof_path.write_bytes((json.dumps(proof, indent=2) + "\n").replace("\n", "\r\n").encode("utf-8"))
    print("promoted; now run: python scripts/world_native_collision.py --check")


if __name__ == "__main__":
    main()
