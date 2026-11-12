"""Build the Bear's attachment data (anchors, slots, horns, wings, wearables) and its template.

Inputs (assets/garden-babies/attachments/):
- attachments-manifest.json: 46 anchors in Blender pet-local coordinates, every attachment mesh with
  its slot, anchor, channel, colour role and feature stage, plus the exclusions
  (built by scripts/export_bear_attachments.py from pet-bear-attachments.blend).
- bear-attachments-studio-import.json: mesh asset ids and raw 100x MeshSize from the Studio import of
  bear-attachments.fbx (Open Cloud asset recorded in the file).

Outputs:
- `definition_extension()` is merged into src/shared/BearRigDefinition.lua by build_bear_assets.py
  (anchors, anchorFrames, attachments, slots, features, exclusions).
- PetAssets.rbxmx: a `BearAttachments` Model between the BEAR ATTACHMENTS markers, sibling of `Bear`.
  Same axes and pivot as the Bear template (front -Z, PawsOrigin at the paws).

Axis mapping as build_bear_assets.py: Blender (x, y, z) -> template (-x, z, y), definition (x, z, -y).
Size = MeshSize/100, InitialSize = raw MeshSize. Run this script, then build_bear_assets.py.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "garden-babies"
FOLDER = ASSETS / "attachments"

# Colour roles the runtime understands. "own:#hex" keeps the wearable's own colour.
ROLE = {"secondary": "secondary", "wingTexture": "secondary", "eyeTexture": "face", "face": "face"}
FLAGS = ("coversHorns", "hidesEars", "openCrown", "lowBrim", "printedChest", "noEyewear")
# A swap hides the default pieces it replaces.
REPLACES = {"Eyes": {"L": ["EyeL"], "R": ["EyeR"]}, "Mouth": {"": ["MouthSmile"]}, "Tail": {"": ["Tail"]}}


def to_def(c):
    return [round(c[0], 6), round(c[2], 6), round(-c[1], 6)]


def to_template(c):
    return (-c[0], c[2], c[1])


def size_of(s):
    return [round(s[0], 6), round(s[2], 6), round(s[1], 6)]


def runtime_rotation(axes):
    """Blender local axes (world vectors) -> runtime CFrame components, row major.

    Runtime local X = M ax, local Y (leaves the surface) = M az, local Z (front) = M (-ay),
    with M (x, y, z) = (x, z, -y)."""
    def m(v):
        return [v[0], v[2], -v[1]]
    x, y, z = m(axes["x"]), m(axes["z"]), m([-a for a in axes["y"]])
    return [round(v, 6) for v in (x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2])]


def item_of(mesh):
    if mesh.get("variant"):
        return mesh["variant"].lower()
    short = mesh["name"].split("__", 1)[1]
    return short.split("_")[1].lower()


def definition_extension(manifest):
    anchors, frames = {}, {}
    for a in manifest["anchors"]:
        anchors[a["name"]] = to_def(a["positionBlender"])
        frames[a["name"]] = {"position": to_def(a["positionBlender"]), "channel": a["channel"], "kind": a["kind"],
                             "slot": a["slot"], "rotation": runtime_rotation(a["axesBlender"])}
    slots = manifest["slots"]
    attachments = []
    for mesh in manifest["meshes"]:
        name = mesh["name"].split("__", 1)[1]
        role = mesh["colorRole"]
        entry = {"name": name, "slot": mesh["slot"], "anchor": mesh["anchor"], "channel": mesh["channel"],
                 "colorRole": "own" if role.startswith("own:") else ROLE[role],
                 "center": to_def(mesh["centerBlender"]), "size": size_of(mesh["sizeBlender"])}
        if role.startswith("own:"):
            entry["color"] = role[4:]
        if role == "eyeTexture":
            entry["texture"] = "eye"
        if mesh.get("feature"):
            entry["feature"], entry["stage"] = mesh["feature"], mesh["stage"]
            entry["side"] = mesh["anchor"][-1]
        else:
            entry["item"] = item_of(mesh)
            side = mesh["anchor"][-1] if mesh["anchor"][-1] in "LR" and mesh["anchor"][-2:-1].islower() else ""
            if slots.get(mesh["slot"], {}).get("perSide") or mesh["slot"] in REPLACES:
                entry["side"] = side or None
                if entry["side"] is None:
                    del entry["side"]
            replaces = REPLACES.get(mesh["slot"], {}).get(side) or REPLACES.get(mesh["slot"], {}).get("")
            if replaces:
                entry["replaces"] = replaces
            flags = {f: True for f in FLAGS if mesh.get(f)}
            if flags:
                entry["flags"] = flags
        attachments.append(entry)
    features = {fid: {"slot": f["slot"], "anchors": f["anchors"], "stages": f["stages"]}
                for fid, f in manifest["features"].items()}
    exclusions = []
    for rule in manifest["exclusions"]["hides"]:
        if rule["blocker"] not in slots:
            continue  # future blockers (mittens) are not slots yet
        row = {"blocker": rule["blocker"], "hides": rule["hides"]}
        for key in ("whenFlag", "unlessFlag"):
            if key in rule:
                row[key] = rule[key]
        exclusions.append(row)
    return {"anchorPositions": anchors, "anchorFrames": frames, "attachmentTemplate": "BearAttachments",
            "attachmentTextures": {"eye": "rbxassetid://75513553871906"}, "attachments": attachments,
            "slots": slots, "features": features, "exclusions": exclusions,
            "charmLift": {"feature": "horns", "fromStage": 4, "lift": 0.10}}


def vec(tag, v):
    return f"          <Vector3 name=\"{tag}\">\n            <X>{v[0]!r}</X>\n            <Y>{v[1]!r}</Y>\n            <Z>{v[2]!r}</Z>\n          </Vector3>\n"


def xml_block(manifest, studio) -> str:
    parts = studio["parts"]
    eye = studio["textures"]["eyeTexture"]
    out = ["    <!-- BEGIN BEAR ATTACHMENTS (generated by scripts/build_bear_attachments.py) -->\n",
           "    <Item class=\"Model\" referent=\"BearAttachments\">\n      <Properties>\n        <string name=\"Name\">BearAttachments</string>\n      </Properties>\n"
           "      <Item class=\"CFrameValue\" referent=\"BearAttachmentsOrigin\">\n        <Properties>\n          <string name=\"Name\">PawsOrigin</string>\n"
           "          <CoordinateFrame name=\"Value\">\n            <X>0</X>\n            <Y>0</Y>\n            <Z>0</Z>\n"
           "            <R00>1</R00>\n            <R01>0</R01>\n            <R02>0</R02>\n            <R10>0</R10>\n            <R11>1</R11>\n"
           "            <R12>0</R12>\n            <R20>0</R20>\n            <R21>0</R21>\n            <R22>1</R22>\n          </CoordinateFrame>\n"
           "        </Properties>\n      </Item>\n"]
    for index, mesh in enumerate(manifest["meshes"]):
        key = mesh["name"]
        p = parts[key]
        raw = p["ms"]
        size = [raw[0] / 100, raw[1] / 100, raw[2] / 100]
        pos = to_template(mesh["centerBlender"])
        texture = eye if mesh["colorRole"] == "eyeTexture" else ""
        out.append(f"      <Item class=\"MeshPart\" referent=\"BearAtt{index}\">\n        <Properties>\n"
                   f"          <string name=\"Name\">{key}</string>\n"
                   f"          <Content name=\"MeshId\">\n            <url>{p['id']}</url>\n          </Content>\n"
                   "          <Content name=\"TextureID\">\n            " + (f"<url>{texture}</url>" if texture else "<url />") + "\n          </Content>\n"
                   + vec("Size", size) + vec("InitialSize", raw) +
                   "          <CoordinateFrame name=\"CFrame\">\n"
                   f"            <X>{pos[0]!r}</X>\n            <Y>{pos[1]!r}</Y>\n            <Z>{pos[2]!r}</Z>\n"
                   "            <R00>1</R00>\n            <R01>0</R01>\n            <R02>0</R02>\n            <R10>0</R10>\n            <R11>1</R11>\n"
                   "            <R12>0</R12>\n            <R20>0</R20>\n            <R21>0</R21>\n            <R22>1</R22>\n          </CoordinateFrame>\n"
                   "          <bool name=\"Anchored\">true</bool>\n          <bool name=\"CanCollide\">false</bool>\n"
                   "          <bool name=\"CanTouch\">false</bool>\n          <bool name=\"CanQuery\">false</bool>\n"
                   "        </Properties>\n      </Item>\n")
    out.append("    </Item>\n    <!-- END BEAR ATTACHMENTS -->\n")
    return "".join(out)


def main() -> None:
    manifest = json.loads((FOLDER / "attachments-manifest.json").read_text())
    studio = json.loads((FOLDER / "bear-attachments-studio-import.json").read_text())
    missing = {m["name"] for m in manifest["meshes"]} ^ set(studio["parts"])
    assert not missing, f"manifest and Studio import disagree: {sorted(missing)}"
    path = ASSETS / "PetAssets.rbxmx"
    text = path.read_text()
    block = xml_block(manifest, studio)
    if "<!-- BEGIN BEAR ATTACHMENTS" in text:
        start = text.index("    <!-- BEGIN BEAR ATTACHMENTS")
        end = text.index("<!-- END BEAR ATTACHMENTS -->") + len("<!-- END BEAR ATTACHMENTS -->\n")
        text = text[:start] + block + text[end:]
    else:
        marker = "    <!-- END BEAR -->\n"
        assert marker in text, "PetAssets.rbxmx layout changed"
        text = text.replace(marker, marker + block, 1)
    path.write_text(text, newline="\r\n")  # the file is CRLF
    print("wrote the BearAttachments template")
    # The rig definition carries the anchors and attachment data.
    subprocess.run([sys.executable, str(Path(__file__).with_name("build_bear_assets.py"))], check=True)


if __name__ == "__main__":
    main()
