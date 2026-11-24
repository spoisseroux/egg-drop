"""The egg machine's proof gate (EGG-CORNER-LOOK section 2): binds the uploaded Model to the built files and writes the
template the client clones and its data module. Never touches the island, its manifest or the native checkpoint.

  python scripts/egg_machine_assets.py record ASSET_ID OPERATION_ID MODERATION PARTS_JSON --uploaded FBX_SHA256
      PARTS_JSON: what Studio Edit printed for InsertService:LoadAsset(ASSET_ID) ([{name, meshId, meshSize}]), a string
      or a path. Refuses when egg-machine.fbx changed since the upload (pass its digest from before the upload).
  python scripts/egg_machine_assets.py --confirm   writes assets/world/EggMachine.rbxmx and src/shared/EggMachineData.lua
  python scripts/egg_machine_assets.py --check     fails when either output is stale

Template (a Model, its parts as the egg-corner build plan names them; NAMES below):
  Body     textured (SurfaceAppearance: the 512 px map at roughness .6), anchored, collides, Box collision
  Globe    clear: SmoothPlastic, Transparency .62, vertex tint (streak, green rim), no collision, no shadow
  Dial     textured (TextureID on SmoothPlastic: the one satin part), no collision; pivot in the data module
  Sprout   vertex green, no collision, no shadow; pivot in the data module
  EggPile  vertex-coloured baked eggs, no collision
  Egg      one egg (white with a brighter zigzag band; Color sets the type), no collision: the loose eggs and the
           dropped egg are its clones
Every part is placed machine-local (its CFrame relative to the Model's pivot at the base's centre on the ground, front
+Z); the server places the Model with PivotTo (EGG-CORNER-BUILD-PLAN 6.1: one replicated copy, clients animate it).
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
DIR = ROOT / "assets" / "world" / "egg-machine"
FBX, MANIFEST, READBACK = DIR / "egg-machine.fbx", DIR / "egg-machine-manifest.json", DIR / "egg-machine-readback.json"
XML_OUT = ROOT / "assets" / "world" / "EggMachine.rbxmx"
LUA_OUT = ROOT / "src" / "shared" / "EggMachineData.lua"
ID = re.compile(r"^rbxassetid://([1-9][0-9]{0,19})$")
TEXTURE = "rbxassetid://119526952958289"   # egg-machine.png (Fable Studio R1)
ROUGH_60 = "rbxassetid://78518887759939"   # egg-machine-rough60.png (.6, collar .8)
METAL_0 = "rbxassetid://114363080604088"   # the island's flat no-metal map (build_world_v7_assets MATTE_METALNESS)
# Instance names: the egg-corner build plan's contract (EGG-CORNER-BUILD-PLAN.md) fills these.
MODEL_NAME = "EggMachine"
NAMES = {"Body": "Body", "Globe": "Globe", "Dial": "Dial", "Sprout": "Sprout", "EggPile": "EggPile", "Egg": "Egg"}
TURN = math.pi  # the Roblox import turns each mesh by pi about Y


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
        raise GateError("egg-machine.fbx changed since the upload; rebuild, upload and record again")
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
    if TEXTURE.endswith("://0") or ROUGH_60.endswith("://0"):
        raise GateError("the texture ids are not set yet")
    want = {p["name"]: p for p in manifest["parts"]}
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


def cframe(x, y, z):
    """Machine-local CFrame with the import's turn (pi about Y)."""
    c, s = math.cos(TURN), math.sin(TURN)
    return {"X": x, "Y": y, "Z": z, "R00": c, "R01": 0.0, "R02": s, "R10": 0.0, "R11": 1.0, "R12": 0.0,
            "R20": -s, "R21": 0.0, "R22": c}


def xml_part(i, part, mesh_id, raw, manifest):
    kind = part["part"]
    name = NAMES[kind]
    if "center" in part:
        at = part["center"]
    else:
        pivot = manifest["pivots"].get(kind, [0.0, 0.0, 0.0])
        at = [pivot[k] + part["pivotToCentre"][k] for k in range(3)]
    cf = cframe(*at)
    sx, sy, sz = part["size"]
    collide = kind == "Body"
    transparency = .62 if kind == "Globe" else 0.0   # Fable Studio R1: .78 made the glass nearly invisible
    texture = TEXTURE if kind == "Dial" else ""
    shadow = kind not in ("Globe", "Sprout")
    lines = [
        f"    <Item class=\"MeshPart\" referent=\"EM{i}\">",
        "      <Properties>",
        f"        <string name=\"Name\">{name}</string>",
        f"        <Content name=\"MeshId\"><url>rbxassetid://{mesh_id}</url></Content>",
        f"        <Content name=\"TextureID\">{f'<url>{texture}</url>' if texture else '<url />'}</Content>",
        "        <CoordinateFrame name=\"CFrame\">" + "".join(f"<{k}>{v!r}</{k}>" for k, v in cf.items()) + "</CoordinateFrame>",
        f"        <Vector3 name=\"Size\"><X>{sx!r}</X><Y>{sy!r}</Y><Z>{sz!r}</Z></Vector3>",
        f"        <Vector3 name=\"InitialSize\"><X>{raw[0]!r}</X><Y>{raw[1]!r}</Y><Z>{raw[2]!r}</Z></Vector3>",
        "        <bool name=\"Anchored\">true</bool>",
        f"        <bool name=\"CanCollide\">{'true' if collide else 'false'}</bool>",
        f"        <bool name=\"CanQuery\">{'true' if collide else 'false'}</bool>",
        "        <bool name=\"CanTouch\">false</bool>",
        f"        <bool name=\"CastShadow\">{'true' if shadow else 'false'}</bool>",
        f"        <bool name=\"DoubleSided\">{'true' if kind in ('Globe', 'Sprout') else 'false'}</bool>",
        f"        <token name=\"CollisionFidelity\">{1 if collide else 0}</token>",   # Box for the body
        "        <token name=\"Material\">272</token>",                                # SmoothPlastic
        f"        <float name=\"Transparency\">{transparency!r}</float>",
        f"        <Color3uint8 name=\"Color3uint8\">{(0xFF << 24) | 0xFFFFFF}</Color3uint8>",
        "      </Properties>",
    ]
    if kind == "Body":
        lines += [
            f"      <Item class=\"SurfaceAppearance\" referent=\"EMS{i}\">",
            "        <Properties>",
            "          <string name=\"Name\">Enamel</string>",
            "          <token name=\"AlphaMode\">0</token>",
            f"          <Content name=\"ColorMap\"><url>{TEXTURE}</url></Content>",
            f"          <Content name=\"MetalnessMap\"><url>{METAL_0}</url></Content>",
            f"          <Content name=\"RoughnessMap\"><url>{ROUGH_60}</url></Content>",
            "        </Properties>",
            "      </Item>",
        ]
    lines.append("    </Item>")
    return "\n".join(lines) + "\n"


def rbxmx(manifest, bound):
    out = ["<roblox version=\"4\">\n",
           f"  <Item class=\"Model\" referent=\"EggMachine\">\n    <Properties>\n      <string name=\"Name\">{MODEL_NAME}</string>\n"
           "    </Properties>\n"]  # no WorldPivotData: Rojo rejects a plain CFrame for that OptionalCFrame property
    for i, part in enumerate(manifest["parts"]):
        mesh_id, raw = bound[part["name"]]
        out.append(xml_part(i, part, mesh_id, raw, manifest))
    out.append("  </Item>\n</roblox>\n")
    return "".join(out)


def lua(manifest, readback):
    data = {
        "assetId": str(readback["assetId"]),
        "model": MODEL_NAME,
        "names": NAMES,
        "size": manifest["size"],
        "front": [0, 0, 1],
        "pivots": manifest["pivots"],
        "dialFace": manifest["dialFace"],
        "loose": manifest["loose"],
        "pileTypes": manifest["pileTypes"],
        "cup": manifest["cup"],
        "chute": manifest["chute"],
        "light": manifest["light"],
        "eggTypes": manifest["eggTypes"],
        "egg": next({"size": p["size"]} for p in manifest["parts"] if p["part"] == "Egg"),
        "triangles": manifest["triangles"],
        "dropScale": manifest["dropScale"],   # the dropped egg is the Egg mesh at this scale (EGG-CORNER-BUILD-PLAN 6.1)
    }
    body = json.dumps(data, separators=(",", ":"), sort_keys=True)
    return ("-- Generated by scripts/egg_machine_assets.py from assets/world/egg-machine. Machine-local Roblox studs:\n"
            "-- origin on the ground at the base's centre, +Z the front. Do not edit by hand.\n"
            f"return game:GetService(\"HttpService\"):JSONDecode([=[{body}]=])\n")


def atomic_write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=path.parent, delete=False) as s:
        tmp = s.name
        s.write(text)
    os.replace(tmp, path)


def generate():
    if not READBACK.exists():
        raise GateError("no readback yet: upload egg-machine.fbx and record it")
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
        print("STALE: " + ", ".join(stale) if stale else "egg machine outputs match the confirmed readback")
        return 1 if stale else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
