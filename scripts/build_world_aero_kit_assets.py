"""Turn the uploaded Aero world kit into its runtime template and data, behind a proof gate.

    python scripts/build_world_aero_kit_assets.py --confirm assets/world/aero-kit/aero-kit-readback.json
    python scripts/build_world_aero_kit_assets.py --check     (fail when the committed outputs differ)

Inputs (assets/world/aero-kit/, from scripts/build_world_aero_kit.py and the upload):
- aero-kit.fbx, aero-kit-manifest.json
- aero-kit-readback.json  the Open Cloud upload (assetId, operationId, moderation) and, per MeshPart, the MeshId and raw
                          MeshSize read back with InsertService:LoadAsset in Studio Edit, plus the SHA256 of the FBX and
                          manifest that were uploaded

The gate refuses (and writes nothing) unless: the readback names exactly the manifest's meshes, once each; every MeshId
is a positive rbxassetid, unique, and not one the island already uses (world-v7-studio-import.json, the ground collision
import, the dressing import); every raw size is finite, positive and the manifest size times ONE import scale (within
SCALE_TOLERANCE on every axis); the moderation state is not rejected; and the FBX and manifest on disk are the ones
uploaded. It never reads or writes the island's native collision checkpoint.

Outputs:
- assets/world/AeroKit.rbxmx    Folder AeroKit of MeshPart templates (mounted at ServerStorage.AeroKit; the server copies
                                it to ReplicatedStorage only where the Aero ceiling passes)
- src/shared/WorldAeroKit.lua   placements: crowns (pivot, yaw, scale), rocks, falls frames, what the kit hides
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / "assets" / "world"
KIT = WORLD / "aero-kit"
XML_OUT = WORLD / "AeroKit.rbxmx"
LUA_OUT = ROOT / "src" / "shared" / "WorldAeroKit.lua"
SCALE_TOLERANCE = 2e-3
ID = re.compile(r"^rbxassetid://([1-9][0-9]{0,19})$")

# The merged parts' looks (build_world_v7_assets.py), so a kit part shows as the part it replaces until Aero paints it.
MATTE_ROUGHNESS = "rbxassetid://132217078330162"
MATTE_METALNESS = "rbxassetid://114363080604088"
MATERIAL_TOKEN = {"SmoothPlastic": 272, "Plastic": 256}
# LOOK-R2 1: the lime crowns' own matte skin: the lime map (WorldAero.Crowns.lime.Texture) at roughness .92
# (assets/world/textures/aero/roughness-92.png), so the Aero lime is no longer a glossy SmoothPlastic part.
LIME_MAP = "rbxassetid://127425168647805"
# LOOK-R2 round 3: still neon at the map's mean #8FD63F; the skin's Color multiplies it to #86BE3C.
LIME_TINT = (0x86 / 0x8F, 0xBE / 0xD6, 0x3C / 0x3F)
ROUGH_92 = "rbxassetid://93359996848376"
# LOOK-R3 2: the reshaped crowns (a manifest mesh with "reshape") wear the drawn leaf-cluster tiles
# (scripts/draw_aero_r3_textures.py, 4 studs a tile) and their roughness map; the lime tile holds its final colours, so
# its skin stays white. The Hatch crown and the bushes keep the island map (their UVs are ~8 studs a tile).
# LOOK-R4 W2: denser tiles (512 px for 4 studs, sprigs in four layers; scripts/draw_aero_r4_textures.py).
LEAF_DARK = "rbxassetid://104251374979550"
LEAF_LIME = "rbxassetid://96924676602525"  # Fable R5: saturation -15, value -10
# LOOK-R4 W1: the falls atlas (streaks for the sheet faces, a white block for everything else).
FALLS_ATLAS = "rbxassetid://122555017086176"  # Fable R5: bands, body #BFD9EA, feathered sides
LEAF_ROUGH = "rbxassetid://125570475932961"  # LOOK-R3 round 6: flat 1.0


class GateError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def island_ids(world=WORLD):
    """Every mesh id the island already uses: a kit readback naming one of these is a stale or wrong readback."""
    ids = set()

    def take(value):
        if isinstance(value, list) and value and isinstance(value[0], str):
            ids.add(value[0].replace("rbxassetid://", ""))
        elif isinstance(value, str) and value.replace("rbxassetid://", "").isdigit():
            ids.add(value.replace("rbxassetid://", ""))
        elif isinstance(value, dict):
            for each in value.values():
                take(each)
    for name in ("world-v7-studio-import.json", "world-v7-collision-studio-import.json", "world-dressing-import.json"):
        path = world / name
        if not path.exists():  # a renamed import must not make this check pass by default
            raise GateError("island import missing: " + name)
        take(json.loads(path.read_text()))
    if len(ids) < 100:
        raise GateError("island imports hold too few mesh ids to check against")
    return ids


def validate(manifest, readback, fbx_sha, manifest_sha, used):
    """Returns {name: (mesh id digits, raw size)} or raises GateError. Pure: no file access."""
    if not isinstance(readback, dict):
        raise GateError("readback is not an object")
    for key in ("assetId", "operationId", "moderation", "fbxSha256", "manifestSha256", "parts"):
        if key not in readback:
            raise GateError("readback is missing " + key)
    if not str(readback["assetId"]).isdigit() or int(readback["assetId"]) <= 0:
        raise GateError("assetId is not a positive number")
    if str(readback["moderation"]) != "Approved":  # an allowlist: pending, rejected or anything else waits
        raise GateError("the kit model is " + str(readback["moderation"]) + ", not Approved")
    if readback["fbxSha256"] != fbx_sha:
        raise GateError("aero-kit.fbx is not the uploaded file")
    if readback["manifestSha256"] != manifest_sha:
        raise GateError("aero-kit-manifest.json is not the uploaded one")
    want = {m["name"]: m for m in manifest["meshes"]}
    parts = readback["parts"]
    if not isinstance(parts, list):
        raise GateError("parts is not a list")
    names = [p.get("name") for p in parts if isinstance(p, dict)]
    if len(names) != len(parts) or len(set(names)) != len(names):
        raise GateError("readback names a part twice or has a malformed row")
    if set(names) != set(want):
        raise GateError("readback parts differ: missing %s, extra %s" % (sorted(set(want) - set(names)), sorted(set(names) - set(want))))
    out, seen, scales = {}, set(), []
    for part in parts:
        match = ID.match(str(part.get("meshId", "")))
        if not match:
            raise GateError(part["name"] + ": meshId is not a positive rbxassetid")
        digits = match.group(1)
        if digits in seen:
            raise GateError(part["name"] + ": meshId used twice")
        if digits in used:
            raise GateError(part["name"] + ": meshId already belongs to the island")
        seen.add(digits)
        raw = part.get("meshSize")
        if not (isinstance(raw, list) and len(raw) == 3 and all(isinstance(v, (int, float)) and math.isfinite(v) and v > 0 for v in raw)):
            raise GateError(part["name"] + ": meshSize is not three finite positive numbers")
        for authored, got in zip(want[part["name"]]["size"], raw):
            scales.append((part["name"], got / max(authored, 1e-6)))
        out[part["name"]] = (digits, [float(v) for v in raw])
    base = scales[0][1]
    for name, scale in scales:
        if abs(scale - base) > SCALE_TOLERANCE * base:
            raise GateError("%s: raw size is not the manifest size times one import scale (%.5f vs %.5f)" % (name, scale, base))
    return out


# ------------------------------------------------------------------------------------------------------------ outputs
def textures():
    return json.loads((WORLD / "world-v7-uploads.json").read_text())["textures"]


def xml_part(index, mesh, mesh_id, raw):
    tex = textures()
    kind = mesh["kind"]
    sx, sy, sz = mesh["size"]
    matte = None
    texture = ""
    material = "SmoothPlastic"
    shadow = mesh["role"] == "rest"  # crowns move (no shadow); falls and rocks stay shadowless (+0 shadow draws)
    double = True
    rough = MATTE_ROUGHNESS
    tint = None
    glow = None
    if "reshape" in mesh and kind == "foliage":
        matte, rough = LEAF_DARK, LEAF_ROUGH
    elif "reshape" in mesh and kind == "foliage_blossom":
        matte, rough = LEAF_LIME, LEAF_ROUGH
    elif kind == "foliage":
        matte = tex["W1_foliage"]
    elif kind == "foliage_blossom":
        matte, rough, tint = LIME_MAP, ROUGH_92, LIME_TINT
    elif kind == "kitwater":
        texture, material = FALLS_ATLAS, "Plastic"
    elif kind == "kitfoam":
        # LOOK-R4 round 2: a matte skin on the atlas's white block; the client sets its emissive lift at build
        # (a SurfaceAppearance cannot be parented at runtime, its emissive properties can be written).
        matte, rough, material = FALLS_ATLAS, MATTE_ROUGHNESS, "Plastic"
        glow = FALLS_ATLAS  # its white block is the emissive mask (game scripts cannot write the mask; strength they can)
    elif kind == "kitstone":
        texture, material = tex["W1_marble"], "Plastic"  # LOOK-R2 3: the plaza marble under a weathered vertex tint
    else:
        material = "Plastic"
    lines = [
        f"    <Item class=\"MeshPart\" referent=\"AK{index}\">",
        "      <Properties>",
        f"        <string name=\"Name\">{mesh['name']}</string>",
        f"        <Content name=\"MeshId\"><url>rbxassetid://{mesh_id}</url></Content>",
        f"        <Content name=\"TextureID\">{f'<url>{texture}</url>' if texture else '<url />'}</Content>",
        f"        <Vector3 name=\"Size\"><X>{sx!r}</X><Y>{sy!r}</Y><Z>{sz!r}</Z></Vector3>",
        f"        <Vector3 name=\"InitialSize\"><X>{raw[0]!r}</X><Y>{raw[1]!r}</Y><Z>{raw[2]!r}</Z></Vector3>",
        "        <bool name=\"Anchored\">true</bool>",
        "        <bool name=\"CanCollide\">false</bool>",
        "        <bool name=\"CanQuery\">false</bool>",
        "        <bool name=\"CanTouch\">false</bool>",
        f"        <bool name=\"CastShadow\">{'true' if shadow else 'false'}</bool>",
        f"        <bool name=\"DoubleSided\">{'true' if double else 'false'}</bool>",
        "        <token name=\"CollisionFidelity\">2</token>",
        # round 6 (Spencer: "the water fall distance"): kit meshes keep full detail far off (not scriptable at runtime)
        "        <token name=\"RenderFidelity\">1</token>",
        f"        <token name=\"Material\">{MATERIAL_TOKEN[material]}</token>",
        f"        <Color3uint8 name=\"Color3uint8\">{(0xFF << 24) | 0xFFFFFF}</Color3uint8>",
        "        <float name=\"Reflectance\">0.0</float>",  # LOOK-R4: no Reflectance on the falls either
        "      </Properties>",
    ]
    if matte:
        lines += [
            f"      <Item class=\"SurfaceAppearance\" referent=\"AKS{index}\">",
            "        <Properties>",
            "          <string name=\"Name\">MatteFinish</string>",
            "          <token name=\"AlphaMode\">0</token>",
            f"          <Content name=\"ColorMap\"><url>{matte}</url></Content>",
            f"          <Content name=\"MetalnessMap\"><url>{MATTE_METALNESS}</url></Content>",
            f"          <Content name=\"RoughnessMap\"><url>{rough}</url></Content>",
        ] + ([f"          <Color3 name=\"Color\"><R>{tint[0]!r}</R><G>{tint[1]!r}</G><B>{tint[2]!r}</B></Color3>"]
             if tint else []) + ([
            f"          <Content name=\"EmissiveMaskContent\"><url>{glow}</url></Content>",
            "          <float name=\"EmissiveStrength\">0.3</float>",  # Fable R5: matte, lower
            "          <Color3 name=\"EmissiveTint\"><R>1</R><G>1</G><B>1</B></Color3>",
        ] if glow else []) + [
            "        </Properties>",
            "      </Item>",
        ]
    lines.append("    </Item>")
    return "".join(line + "\n" for line in lines)


def rbxmx(manifest, bound):
    out = ["<roblox version=\"4\">\n",
           "  <Item class=\"Folder\" referent=\"AeroKit\">\n    <Properties>\n      <string name=\"Name\">AeroKit</string>\n    </Properties>\n"]
    for i, mesh in enumerate(manifest["meshes"]):
        mesh_id, raw = bound[mesh["name"]]
        out.append(xml_part(i, mesh, mesh_id, raw))
    out.append("  </Item>\n</roblox>\n")
    return "".join(out)


def lua(manifest, readback):
    data = {
        "note": "Generated by scripts/build_world_aero_kit_assets.py from assets/world/aero-kit. Roblox studs.",
        "assetId": str(readback["assetId"]),
        "meshes": {m["name"]: {k: m[k] for k in ("role", "kind", "size", "pivotToCentre", "center", "tris") if k in m}
                   for m in manifest["meshes"]},
        "crowns": [{k: c[k] for k in ("tree", "mesh", "pivot", "yaw", "scale")} for c in manifest["crowns"]],
        "rocks": [{k: r[k] for k in ("kind", "center", "size", "radius")} for r in manifest["rocks"]],
        "falls": manifest["falls"],
        "fountain": manifest.get("fountain"),
        "hides": sorted(manifest["hides"]),
        "triangles": manifest["triangles"],
    }
    body = json.dumps(data, separators=(",", ":"), sort_keys=True)
    return ("-- Generated by scripts/build_world_aero_kit_assets.py. Do not edit by hand.\n"
            f"return game:GetService(\"HttpService\"):JSONDecode([=[{body}]=])\n")


def atomic_write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=path.parent, delete=False) as stream:
        temporary = stream.name
        stream.write(text)
    os.replace(temporary, path)


def generate(kit=KIT, world=WORLD):
    manifest_path = kit / "aero-kit-manifest.json"
    readback_path = kit / "aero-kit-readback.json"
    if not readback_path.exists():
        raise GateError("no readback yet: upload aero-kit.fbx and record aero-kit-readback.json")
    manifest = json.loads(manifest_path.read_text())
    readback = json.loads(readback_path.read_text())
    bound = validate(manifest, readback, sha256(kit / "aero-kit.fbx"), sha256(manifest_path), island_ids(world))
    return rbxmx(manifest, bound), lua(manifest, readback)


def main(argv):
    if "--confirm" in argv:
        index = argv.index("--confirm")
        given = Path(argv[index + 1]).resolve() if index + 1 < len(argv) else None
        if given != (KIT / "aero-kit-readback.json").resolve():
            raise GateError("--confirm takes assets/world/aero-kit/aero-kit-readback.json")
        xml, code = generate()
        atomic_write(XML_OUT, xml)
        atomic_write(LUA_OUT, code)
        print("wrote", XML_OUT.relative_to(ROOT), "and", LUA_OUT.relative_to(ROOT))
        return 0
    if "--check" in argv:
        xml, code = generate()
        stale = [p.name for p, text in ((XML_OUT, xml), (LUA_OUT, code)) if not p.exists() or p.read_text(encoding="utf-8") != text]
        if stale:
            print("STALE:", ", ".join(stale))
            return 1
        print("Aero kit outputs match the confirmed readback")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
