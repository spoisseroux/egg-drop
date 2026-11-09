"""Normalize actual Studio 100x FBX imports and retain the two existing templates verbatim."""
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/garden-babies/new-five-2026-11-09"
RAW = ROOT / "artifacts/aero-garden-2026-11-09/raw-native-baby-imports.json"
XML = ROOT / "assets/garden-babies/PetAssets.rbxmx"
REPAIR = ROOT / "scripts/RepairPetAssets.lua"
BEGIN, END = "    <!-- BEGIN FIVE AUTHORED BABIES -->", "    <!-- END FIVE AUTHORED BABIES -->"
IDENTITY = [1, 0, 0, 0, 1, 0, 0, 0, 1]


def prop(parent, tag, name, value):
    node = ET.SubElement(parent, tag, name=name)
    if isinstance(value, list):
        keys = ["X", "Y", "Z"] + ([f"R{r}{c}" for r in range(3) for c in range(3)] if len(value) == 12 else [])
        for key, number in zip(keys, value):
            ET.SubElement(node, key).text = str(number)
    elif tag == "Content":
        ET.SubElement(node, "url").text = value
    else:
        node.text = str(value)


def main():
    raw = json.loads(RAW.read_text(encoding="utf-8"))
    package = json.loads((SOURCE / "five-asset-manifest.json").read_text(encoding="utf-8"))
    models, repair_rows, report = [], [], []
    for family in package["families"]:
        key = family["template"]
        manifest = json.loads((SOURCE / family["manifest"]).read_text(encoding="utf-8"))
        assert hashlib.sha256((SOURCE / family["fbx"]).read_bytes()).hexdigest() == family["fbxSha256"], key + " FBX changed"
        expected = {p["name"]: p for p in manifest["objects"]}
        meshes = raw[key]["meshes"]
        assert {p["name"] for p in meshes} == expected.keys() and len(meshes) == len(expected), key + " semantic import differs"
        model_name = family["display"]
        model = ET.Element("Item", {"class": "Model", "referent": model_name})
        props = ET.SubElement(model, "Properties");prop(props, "string", "Name", model_name)
        origin = ET.SubElement(model, "Item", {"class": "CFrameValue", "referent": model_name + "Origin"})
        props = ET.SubElement(origin, "Properties");prop(props, "string", "Name", "PawsOrigin");prop(props, "CoordinateFrame", "Value", [0, 0, 0] + IDENTITY)
        for i, part in enumerate(sorted(meshes, key=lambda p: p["name"])):
            item = expected[part["name"]]
            assert re.fullmatch(r"rbxassetid://[1-9][0-9]*", part["meshId"]), "missing actual uploaded resource"
            assert all(abs(a-b) < 1e-6 for a, b in zip(part["relativeCFrame"][3:], IDENTITY)), "unreviewed baked orientation"
            size = [v / 100 for v in part["size"]]
            frame = [v / 100 for v in part["relativeCFrame"][:3]] + part["relativeCFrame"][3:]
            # The native importer bakes -Z front. Runtime applies exactly one Y-pi turn.
            actual_center = [-frame[0], frame[1], -frame[2]]
            error = max(abs(a-b) for a, b in zip(actual_center, item["centerRoblox"]))
            size_error = max(abs(a-b) for a, b in zip(size, item["sizeRoblox"]))
            assert error < .00001 and size_error < .00001, (key, part["name"], error, size_error)
            assert all(v > 0 for v in part["meshSize"])
            node = ET.SubElement(model, "Item", {"class": "MeshPart", "referent": model_name + str(i)})
            props = ET.SubElement(node, "Properties")
            prop(props, "string", "Name", part["name"]);prop(props, "Content", "MeshId", part["meshId"]);prop(props, "Content", "TextureID", "")
            prop(props, "Vector3", "Size", size);prop(props, "Vector3", "InitialSize", part["meshSize"]);prop(props, "CoordinateFrame", "CFrame", frame)
            for flag, value in (("Anchored", "true"), ("CanCollide", "false"), ("CanTouch", "false"), ("CanQuery", "false")):
                prop(props, "bool", flag, value)
            repair_rows.append({"model": model_name, "name": part["name"], "mesh": part["meshId"], "size": size, "meshSize": part["meshSize"], "cframe": frame})
            report.append({"model": model_name, "name": part["name"], "centerError": error, "sizeError": size_error, "mesh": part["meshId"]})
        ET.indent(model, space="  ", level=2);models.append("    " + ET.tostring(model, encoding="unicode"))
    text = XML.read_text(encoding="utf-8")
    if BEGIN in text:
        start = text.index(BEGIN);finish = text.index(END, start) + len(END)
        text = text[:start] + text[finish:].lstrip("\n")
    suffix = "  </Item>\n</roblox>"
    assert text.rstrip().endswith(suffix), "unexpected asset folder layout"
    text = text.rstrip()[:-len(suffix)] + BEGIN + "\n" + "\n".join(models) + "\n" + END + "\n" + suffix + "\n"
    # Parse before writing, and preserve every original template property/resource.
    ET.fromstring(text)
    repair = REPAIR.read_text(encoding="utf-8")
    pattern = r"JSONDecode\(\[=\[(.*?)\]=\]\)"
    match = re.search(pattern, repair, re.S);assert match
    prior = json.loads(match.group(1));prior = [p for p in prior if p["model"] in {"Zivvi", "Ovelle"}]
    assert len(prior) == 31
    replacement = "JSONDecode([=[" + json.dumps(prior + repair_rows, separators=(",", ":")) + "]=])"
    repair = repair[:match.start()] + replacement + repair[match.end():]
    XML.write_text(text, encoding="utf-8");REPAIR.write_text(repair, encoding="utf-8")
    output = ROOT / "artifacts/aero-garden-2026-11-09/canonical-baby-import-comparison.json"
    output.write_text(json.dumps({"scale": 100, "oldMeshes": 31, "newMeshes": len(repair_rows), "totalMeshes": 31 + len(repair_rows), "maxCenterError": max(p["centerError"] for p in report), "maxSizeError": max(p["sizeError"] for p in report), "parts": report}, indent=2) + "\n", encoding="utf-8")
    print(f"Normalized {len(repair_rows)} actual uploaded meshes; kept31 old resources; max center error {max(p['centerError'] for p in report):.9f} stud.")


if __name__ == "__main__":
    main()
