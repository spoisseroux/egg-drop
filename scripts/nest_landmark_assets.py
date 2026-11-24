"""The Sleepy Nest landmark's asset gate (NEST-LANDMARK-LOOK, NEST-LANDMARK-BUILD-PLAN): binds the uploaded Model to
this exact FBX and manifest, then writes the template clients clone and its data module. Never touches the island,
its manifest or the native checkpoint. The egg machine's gate (scripts/egg_machine_assets.py), with the architect's
review of the nest's contract.

  python scripts/nest_landmark_assets.py record ASSET OPERATION MODERATION PARTS_JSON --uploaded FBX_SHA256
  python scripts/nest_landmark_assets.py --confirm   writes assets/world/NestLandmark.rbxmx, src/shared/NestLandmarkData.lua
  python scripts/nest_landmark_assets.py --check     fails when either output is stale

Template: Model `NestLandmark`, every part placed nest-local (front -Z, origin on the ground at the bowl's centre):
  Body            SurfaceAppearance (atlas, roughness), no collision, casts a shadow
  Awning          SurfaceAppearance, no collision; pivot and lift axis in the data module
  Moon            SurfaceAppearance with the emissive mask (EmissiveStrength 0: the code drives Strength and Tint at
                  dusk / ready; game scripts can write those, not the mask), no collision, no shadow
  BlanketDraped   SurfaceAppearance, double-sided, hidden (Transparency 1) until the code tucks
  BlanketSlipped  SurfaceAppearance, double-sided, hidden: the ready pose
  BlanketFolded   SurfaceAppearance, shown: the template's default state (napping, not tucked)
  Collider        a plain cylinder Part (radius 2.4, 2.75 high), invisible, CanCollide (and so queryable: Roblox ignores
                  CanQuery while CanCollide is on; the code side keeps pet and trail rays off it with a collision group
                  or its exclude list); the Model's PrimaryPart with PivotOffset = its CFrame inverse, so GetPivot() is
                  the origin without WorldPivotData (which Rojo will not take as a plain CFrame)
  LandmarkVersion IntValue = NestLandmarkData.version: a stale template falls back to the twig nest
All meshes Box collision fidelity (none of them collides). The Roblox import turns each mesh by pi about Y; the CFrames
carry that turn.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "assets" / "world" / "nest-landmark"
FBX, MANIFEST, READBACK = DIR / "nest-landmark.fbx", DIR / "nest-landmark-manifest.json", DIR / "nest-landmark-readback.json"
XML_OUT = ROOT / "assets" / "world" / "NestLandmark.rbxmx"
LUA_OUT = ROOT / "src" / "shared" / "NestLandmarkData.lua"
ID = re.compile(r"^rbxassetid://([1-9][0-9]{0,19})$")
# Filled in from the Studio upload of each image (Open Cloud Decal -> image id), then --confirm.
TEXTURE = "rbxassetid://109068066768047"    # nest-landmark.png
ROUGH = "rbxassetid://103072598458589"      # nest-landmark-rough.png (.85; bowl .8, quilt .9)
EMISSIVE = "rbxassetid://117442342557145"   # nest-landmark-emissive.png (the crescent and its edge)
METAL_0 = "rbxassetid://114363080604088"   # the island's flat no-metal map (build_world_v7_assets MATTE_METALNESS)
MODEL_NAME = "NestLandmark"
NAMES = {"Body": "Body", "Awning": "Awning", "Moon": "Moon", "BlanketDraped": "BlanketDraped",
         "BlanketSlipped": "BlanketSlipped", "BlanketFolded": "BlanketFolded"}
HIDDEN = ("BlanketDraped", "BlanketSlipped")
DOUBLE = ("BlanketDraped", "BlanketSlipped")
NO_SHADOW = ("Moon",)
MOON_TINT = (0xFF, 0xE9, 0xA6)
TURN = math.pi
BOX = 2          # CollisionFidelity.Box
SMOOTH_PLASTIC = 272
CYLINDER = 2     # PartType.Cylinder


class GateError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def record(argv):
    uploaded = None
    if "--uploaded" in argv:
        at = argv.index("--uploaded")
        uploaded = argv[at + 1]
        argv = argv[:at] + argv[at + 2:]
    if len(argv) != 4 or not uploaded:
        raise GateError("record ASSET_ID OPERATION_ID MODERATION PARTS_JSON --uploaded FBX_SHA256")
    asset, operation, moderation, parts = argv
    if sha256(FBX) != uploaded:
        raise GateError("nest-landmark.fbx changed since the upload; rebuild, upload and record again")
    text = Path(parts).read_text() if os.path.exists(parts) else parts
    data = {"assetId": asset, "operationId": operation, "moderation": moderation, "fbxSha256": sha256(FBX),
            "manifestSha256": sha256(MANIFEST), "parts": json.loads(text),
            "recorded": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    READBACK.write_text(json.dumps(data, indent=1), encoding="utf-8", newline="\n")
    print("recorded", len(data["parts"]), "parts for asset", asset)


def validate(manifest, readback, fbx_sha, manifest_sha):
    """{manifest part name: (mesh id digits, raw size)} or GateError. Pure."""
    for key in ("assetId", "operationId", "moderation", "fbxSha256", "manifestSha256", "parts"):
        if key not in readback:
            raise GateError("readback is missing " + key)
    if not str(readback["assetId"]).isdigit() or int(readback["assetId"]) <= 0:
        raise GateError("assetId is not a positive number")
    if readback["moderation"] != "Approved":
        raise GateError("the model is " + str(readback["moderation"]) + ", not Approved")
    if readback["fbxSha256"] != fbx_sha or readback["manifestSha256"] != manifest_sha:
        raise GateError("the built files are not the uploaded ones")
    for label, value in (("texture", TEXTURE), ("roughness", ROUGH), ("emissive mask", EMISSIVE)):
        if not ID.match(value):
            raise GateError("the " + label + " id is not set yet")
    want = {p["name"]: p for p in manifest["parts"]}
    if set(p["part"] for p in manifest["parts"]) != set(NAMES):
        raise GateError("manifest parts differ from the template's names")
    rows = readback["parts"]
    names = [r.get("name") for r in rows]
    if len(set(names)) != len(names) or set(names) != set(want):
        raise GateError("readback parts differ from the manifest")
    out, seen, scales = {}, set(), []
    for row in rows:
        m = ID.match(str(row.get("meshId", "")))
        if not m or m.group(1) in seen:
            raise GateError(row["name"] + ": bad or repeated meshId")
        seen.add(m.group(1))
        raw = row.get("meshSize")
        if not (isinstance(raw, list) and len(raw) == 3 and all(isinstance(v, (int, float)) and v > 0 for v in raw)):
            raise GateError(row["name"] + ": bad meshSize")
        for authored, got in zip(want[row["name"]]["size"], raw):
            if authored > .05:
                scales.append(got / authored)
        out[row["name"]] = (m.group(1), raw)
    if max(scales) / min(scales) > 1.002:
        raise GateError("sizes are not one uniform import scale")
    return out


def cf_xml(name, x, y, z, r):
    keys = ("R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")
    body = f"<X>{x!r}</X><Y>{y!r}</Y><Z>{z!r}</Z>" + "".join(f"<{k}>{v!r}</{k}>" for k, v in zip(keys, r))
    return f"<CoordinateFrame name=\"{name}\">{body}</CoordinateFrame>"


def turned():
    c, s = math.cos(TURN), math.sin(TURN)
    return (c, 0.0, s, 0.0, 1.0, 0.0, -s, 0.0, c)


def surface(i, kind):
    lines = [
        f"      <Item class=\"SurfaceAppearance\" referent=\"NLS{i}\">",
        "        <Properties>",
        "          <string name=\"Name\">Stoneware</string>" if kind == "Body" else f"          <string name=\"Name\">Matte</string>",
        "          <token name=\"AlphaMode\">0</token>",
        f"          <Content name=\"ColorMap\"><url>{TEXTURE}</url></Content>",
        f"          <Content name=\"MetalnessMap\"><url>{METAL_0}</url></Content>",
        f"          <Content name=\"RoughnessMap\"><url>{ROUGH}</url></Content>",
    ]
    if kind == "Moon":
        r, g, b = (c / 255 for c in MOON_TINT)
        lines += [
            f"          <Content name=\"EmissiveMaskContent\"><url>{EMISSIVE}</url></Content>",
            "          <float name=\"EmissiveStrength\">0</float>",
            f"          <Color3 name=\"EmissiveTint\"><R>{r!r}</R><G>{g!r}</G><B>{b!r}</B></Color3>",
        ]
    lines += ["        </Properties>", "      </Item>"]
    return lines


def xml_part(i, part, mesh_id, raw):
    kind = part["part"]
    x, y, z = part["center"]
    sx, sy, sz = part["size"]
    lines = [
        f"    <Item class=\"MeshPart\" referent=\"NL{i}\">",
        "      <Properties>",
        f"        <string name=\"Name\">{NAMES[kind]}</string>",
        f"        <Content name=\"MeshId\"><url>rbxassetid://{mesh_id}</url></Content>",
        "        <Content name=\"TextureID\"><url /></Content>",
        "        " + cf_xml("CFrame", x, y, z, turned()),
        f"        <Vector3 name=\"Size\"><X>{sx!r}</X><Y>{sy!r}</Y><Z>{sz!r}</Z></Vector3>",
        f"        <Vector3 name=\"InitialSize\"><X>{raw[0]!r}</X><Y>{raw[1]!r}</Y><Z>{raw[2]!r}</Z></Vector3>",
        "        <bool name=\"Anchored\">true</bool>",
        "        <bool name=\"CanCollide\">false</bool>",
        "        <bool name=\"CanQuery\">false</bool>",
        "        <bool name=\"CanTouch\">false</bool>",
        f"        <bool name=\"CastShadow\">{'false' if kind in NO_SHADOW else 'true'}</bool>",
        f"        <bool name=\"DoubleSided\">{'true' if kind in DOUBLE else 'false'}</bool>",
        f"        <token name=\"CollisionFidelity\">{BOX}</token>",
        f"        <token name=\"Material\">{SMOOTH_PLASTIC}</token>",
        f"        <float name=\"Transparency\">{1.0 if kind in HIDDEN else 0.0!r}</float>",
        f"        <Color3uint8 name=\"Color3uint8\">{(0xFF << 24) | 0xFFFFFF}</Color3uint8>",
        "      </Properties>",
    ]
    lines += surface(i, kind)
    lines.append("    </Item>")
    return "\n".join(lines) + "\n"


def collider(manifest):
    c = manifest["collider"]
    h, r = c["height"], c["radius"]
    cx, cy, cz = c["centre"]
    up = (0.0, -1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0)        # the cylinder's axis (local X) points up
    inv = (0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0)       # transpose
    ix = -(inv[0] * cx + inv[1] * cy + inv[2] * cz)
    iy = -(inv[3] * cx + inv[4] * cy + inv[5] * cz)
    iz = -(inv[6] * cx + inv[7] * cy + inv[8] * cz)
    return "\n".join([
        "    <Item class=\"Part\" referent=\"NLC\">",
        "      <Properties>",
        "        <string name=\"Name\">Collider</string>",
        f"        <token name=\"shape\">{CYLINDER}</token>",
        "        " + cf_xml("CFrame", cx, cy, cz, up),
        "        " + cf_xml("PivotOffset", ix, iy, iz, inv),     # so the Model's pivot (via PrimaryPart) is the origin
        f"        <Vector3 name=\"size\"><X>{h!r}</X><Y>{2 * r!r}</Y><Z>{2 * r!r}</Z></Vector3>",
        "        <bool name=\"Anchored\">true</bool>",
        "        <bool name=\"CanCollide\">true</bool>",
        "        <bool name=\"CanQuery\">true</bool>",          # Roblox ignores false while CanCollide is on (code review)
        "        <bool name=\"CanTouch\">false</bool>",
        "        <bool name=\"CastShadow\">false</bool>",
        "        <float name=\"Transparency\">1</float>",
        "      </Properties>",
        "    </Item>",
    ]) + "\n"


def rbxmx(manifest, bound):
    out = ["<roblox version=\"4\">\n",
           f"  <Item class=\"Model\" referent=\"NestLandmark\">\n    <Properties>\n      <string name=\"Name\">{MODEL_NAME}</string>\n"
           "      <Ref name=\"PrimaryPart\">NLC</Ref>\n    </Properties>\n"]
    for i, part in enumerate(manifest["parts"]):
        mesh_id, raw = bound[part["name"]]
        out.append(xml_part(i, part, mesh_id, raw))
    out.append(collider(manifest))
    out.append("    <Item class=\"IntValue\" referent=\"NLV\">\n      <Properties>\n"
               "        <string name=\"Name\">LandmarkVersion</string>\n"
               f"        <int64 name=\"Value\">{int(manifest['version'])}</int64>\n      </Properties>\n    </Item>\n")
    out.append("  </Item>\n</roblox>\n")
    return "".join(out)


def lua(manifest, readback):
    keep = ("front", "bounds", "pivots", "blanketFit", "moonLight", "moonTop", "egg", "dent", "bed", "rim", "sign", "mat",
            "bearSpot", "collider", "footprintRadius", "triangles", "version")
    data = {k: manifest[k] for k in keep}
    data.update({
        "assetId": str(readback["assetId"]),
        "model": MODEL_NAME,
        "names": NAMES,
        "hidden": list(HIDDEN),
        "parts": {p["part"]: {"center": p["center"], "size": p["size"]} for p in manifest["parts"]},
    })
    body = json.dumps(data, separators=(",", ":"), sort_keys=True)
    return ("-- Generated by scripts/nest_landmark_assets.py from assets/world/nest-landmark. Nest-local Roblox studs:\n"
            "-- origin on the ground at the bowl's centre, +X the plaza's west, front -Z. Do not edit by hand.\n"
            f"return game:GetService(\"HttpService\"):JSONDecode([=[{body}]=])\n")


def atomic_write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=path.parent, delete=False) as s:
        tmp = s.name
        s.write(text)
    os.replace(tmp, path)


def generate():
    if not READBACK.exists():
        raise GateError("no readback yet: upload nest-landmark.fbx and record it")
    manifest = json.loads(MANIFEST.read_text())
    readback = json.loads(READBACK.read_text())
    bound = validate(manifest, readback, sha256(FBX), sha256(MANIFEST))
    return rbxmx(manifest, bound), lua(manifest, readback)


def main(argv):
    if argv[:1] == ["record"]:
        record(argv[1:])
        return 0
    if "--confirm" in argv:
        xml, code = generate()
        atomic_write(XML_OUT, xml)
        atomic_write(LUA_OUT, code)
        print("wrote", XML_OUT.relative_to(ROOT), "and", LUA_OUT.relative_to(ROOT))
        return 0
    if "--check" in argv:
        xml, code = generate()
        stale = [p.name for p, t in ((XML_OUT, xml), (LUA_OUT, code)) if not p.exists() or p.read_text(encoding="utf-8") != t]
        print("STALE: " + ", ".join(stale) if stale else "nest landmark outputs match the confirmed readback")
        return 1 if stale else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except GateError as exc:
        print("GateError:", exc, file=sys.stderr)
        sys.exit(1)
