"""Turn the uploaded Hidden Grove pack into its runtime templates and data, behind a proof gate (the Aero kit's pattern).

    python scripts/build_world_grove_assets.py --confirm assets/world/grove/grove-readback.json
    python scripts/build_world_grove_assets.py --placeholder   (no upload yet: the safe outputs, nothing is built)
    python scripts/build_world_grove_assets.py --check         (fail when the committed outputs differ)

Inputs (assets/world/grove/, from scripts/build_world_grove.py and the upload):
- grove.fbx, grove-manifest.json, tex/*.png
- grove-readback.json  the Open Cloud upload (assetId, operationId, moderation), per MeshPart the MeshId and raw MeshSize
                       read back in Studio Edit, the image id of every texture ({key: {color, normal?}}), and the SHA256
                       of the FBX and manifest that were uploaded

The gate (GateError, nothing written) refuses unless: the manifest keeps the contract in src/shared/Grove.lua (every
field, GV_ names, no shadows) and its budgets (45k tris counting instances, 10k a mesh, 40 meshes, 2k a far mesh) and
clearances (moat surfaceY <= -25, mid band >= 45 past the rim); the readback names exactly the manifest's meshes, once
each, with positive rbxassetids no island, Aero kit or trunk pack mesh uses, raw sizes of one import scale, an Approved
model, and the FBX and manifest on disk are the uploaded ones; and every texture has an image id.

Outputs:
- assets/world/GroveKit.rbxmx   Folder GroveKit of MeshPart templates (ServerStorage.GroveKit; AeroConfig.mountKit copies
                                it to ReplicatedStorage only where the Aero and grove ceilings pass)
- src/shared/WorldGrove.lua     the runtime data (Grove.lua's contract). The placeholder has assetId "": GroveWorld
                                then builds nothing and the floating-island backdrop stays.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_world_aero_kit_assets import (  # noqa: E402  (the kit's gate pieces, shared on purpose)
    GateError, ID, atomic_write, island_ids, kit_ids, sha256, validate as kit_validate)

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / "assets" / "world"
GROVE = WORLD / "grove"
XML_OUT = WORLD / "GroveKit.rbxmx"
LUA_OUT = ROOT / "src" / "shared" / "WorldGrove.lua"
PREFIX = "GV_"
VERSION = 1
BANDS = {"near", "mid", "giant", "far"}
BUDGET = {"tris": 45000, "perMesh": 10000, "groups": 40, "farMesh": 2000}
MOAT_TOP = -25
MID_RIM = 45
MAX_RAYS = 9
MAX_BUBBLES = 5
MESH_KEYS = ("role", "band", "tris", "size", "center", "pivotToCentre", "texture", "shadow", "maxLevel", "minRimDist")


def finite(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def vec3(v):
    return isinstance(v, list) and len(v) == 3 and all(finite(x) for x in v)


def contract(manifest):
    """The manifest side of Grove.validate, plus budgets and the clearances that need no Lua data. Raises GateError."""
    if not isinstance(manifest, dict):
        raise GateError("manifest is not an object")
    for key in ("version", "coordinates", "turnApplied", "meshes", "instances", "textures", "rays", "sunGate", "moat",
                "canopyBottomY", "hides", "lanterns", "falls", "bubbles", "totals"):
        if key not in manifest:
            raise GateError("manifest is missing " + key)
    if manifest["version"] != VERSION:
        raise GateError("manifest version is not %d" % VERSION)
    if not isinstance(manifest["coordinates"], str) or not manifest["coordinates"]:
        raise GateError("no coordinate rule")
    if not isinstance(manifest["turnApplied"], bool):
        raise GateError("turnApplied is not a boolean")
    textures = manifest["textures"]
    if not isinstance(textures, dict) or not textures:
        raise GateError("no textures")
    for key, tex in textures.items():
        if not isinstance(tex, dict) or not isinstance(tex.get("color"), str) or not finite(tex.get("studsPerTile")) \
                or tex["studsPerTile"] <= 0:
            raise GateError("texture %s: needs color and a positive studsPerTile" % key)
    meshes = manifest["meshes"]
    if not isinstance(meshes, list) or not meshes:
        raise GateError("no meshes")
    names = [m.get("name") for m in meshes if isinstance(m, dict)]
    if len(names) != len(meshes) or len(set(names)) != len(names):
        raise GateError("a mesh is named twice or malformed")
    by = {}
    for m in meshes:
        name = m["name"]
        if not isinstance(name, str) or not name.startswith(PREFIX):
            raise GateError("mesh %r is not named %s*" % (name, PREFIX))
        if not isinstance(m.get("role"), str) or not m["role"]:
            raise GateError(name + ": no role")
        if m.get("band") not in BANDS:
            raise GateError(name + ": band %r" % m.get("band"))
        if not isinstance(m.get("tris"), int) or isinstance(m.get("tris"), bool) or m["tris"] < 1:
            raise GateError(name + ": tris")
        if not vec3(m.get("size")) or min(m["size"]) <= 0:
            raise GateError(name + ": size")
        if ("center" in m) == ("pivotToCentre" in m):
            raise GateError(name + ": needs exactly one of center and pivotToCentre")
        if not vec3(m.get("center", m.get("pivotToCentre"))):
            raise GateError(name + ": center or pivotToCentre")
        if m.get("texture") not in textures:
            raise GateError(name + ": texture %r" % m.get("texture"))
        if m.get("shadow") is not False:
            raise GateError(name + ": shadow must be false (the ring casts none, ARCH-REVIEW-GROVE 6)")
        if m.get("maxLevel") not in (0, 1, 2) or isinstance(m.get("maxLevel"), bool):
            raise GateError(name + ": maxLevel")
        if not finite(m.get("minRimDist")) or m["minRimDist"] < 0:
            raise GateError(name + ": minRimDist")
        by[name] = m
    placed = set()
    for i, row in enumerate(manifest["instances"]):
        mesh = by.get(row.get("mesh")) if isinstance(row, dict) else None
        if not mesh or "pivotToCentre" not in mesh:
            raise GateError("instance %d: not an instanced mesh" % (i + 1))
        if not vec3(row.get("pivot")) or not finite(row.get("yaw")) or not finite(row.get("scale")) or row["scale"] <= 0:
            raise GateError("instance %d: pivot, yaw or scale" % (i + 1))
        placed.add(row["mesh"])
    for name, m in by.items():
        if "pivotToCentre" in m and name not in placed:
            raise GateError(name + ": instanced but never placed")
    rays = manifest["rays"]
    if not isinstance(rays, list) or len(rays) > MAX_RAYS:
        raise GateError("rays (at most %d)" % MAX_RAYS)
    for i, ray in enumerate(rays):
        if not (isinstance(ray, dict) and vec3(ray.get("from")) and vec3(ray.get("to")) and finite(ray.get("w0"))
                and finite(ray.get("w1")) and ray["w0"] > 0 and ray["w1"] > 0 and ray["from"][1] > ray["to"][1]):
            raise GateError("ray %d" % (i + 1))
    gate = manifest["sunGate"]
    if not (isinstance(gate, dict) and finite(gate.get("az")) and finite(gate.get("el")) and 0 <= gate["az"] < 360
            and 10 <= gate["el"] <= 90):
        raise GateError("sunGate is not {az 0-360, el 10-90} in degrees")
    moat = manifest["moat"]
    if not (isinstance(moat, dict) and finite(moat.get("surfaceY")) and isinstance(moat.get("bedOpaque"), bool)):
        raise GateError("moat")
    if not finite(manifest["canopyBottomY"]):
        raise GateError("canopyBottomY")
    hides = manifest["hides"]
    if not isinstance(hides, list) or not all(isinstance(h, str) and h and not h.startswith(PREFIX) for h in hides):
        raise GateError("hides must be island names")
    for i, lantern in enumerate(manifest["lanterns"]):
        if not (isinstance(lantern, dict) and vec3(lantern.get("pos")) and lantern.get("kind") in ("warm", "aqua")):
            raise GateError("lantern %d" % (i + 1))
    for i, fall in enumerate(manifest["falls"]):
        if not (isinstance(fall, dict) and isinstance(fall.get("name"), str) and all(vec3(fall.get(k)) for k in ("top", "bottom", "normal"))
                and finite(fall.get("width0")) and finite(fall.get("width1")) and fall["width0"] > 0 and fall["width1"] > 0):
            raise GateError("fall %d" % (i + 1))
    bubbles = manifest["bubbles"]
    if not isinstance(bubbles, list) or len(bubbles) > MAX_BUBBLES:
        raise GateError("bubbles (at most %d)" % MAX_BUBBLES)
    for i, bubble in enumerate(bubbles):
        if not (isinstance(bubble, dict) and isinstance(bubble.get("path"), list) and len(bubble["path"]) >= 2
                and all(vec3(p) for p in bubble["path"]) and finite(bubble.get("period")) and bubble["period"] > 0
                and finite(bubble.get("size")) and bubble["size"] > 0):
            raise GateError("bubble %d" % (i + 1))
    # Budgets (every instance counted) and the totals the art lane wrote.
    count = {}
    for row in manifest["instances"]:
        count[row["mesh"]] = count.get(row["mesh"], 0) + 1
    tris = sum(m["tris"] * (count.get(name, 0) if "pivotToCentre" in m else 1) for name, m in by.items())
    problems = []
    for name, m in sorted(by.items()):
        if m["tris"] > BUDGET["perMesh"]:
            problems.append("%s: %d tris (over %d)" % (name, m["tris"], BUDGET["perMesh"]))
        if m["band"] == "far" and m["tris"] > BUDGET["farMesh"]:
            problems.append("%s: far band %d tris (over %d)" % (name, m["tris"], BUDGET["farMesh"]))
        if m["band"] == "mid" and m["minRimDist"] < MID_RIM:
            problems.append("%s: %g past the rim (mid band needs %d)" % (name, m["minRimDist"], MID_RIM))
    if tris > BUDGET["tris"]:
        problems.append("ring %d tris (over %d)" % (tris, BUDGET["tris"]))
    if len(by) > BUDGET["groups"]:
        problems.append("%d meshes (over %d)" % (len(by), BUDGET["groups"]))
    if moat["surfaceY"] > MOAT_TOP:
        problems.append("moat surfaceY %g is over %d" % (moat["surfaceY"], MOAT_TOP))
    totals = manifest["totals"]
    if not isinstance(totals, dict) or totals.get("tris") != tris or totals.get("meshes") != len(by):
        problems.append("totals %r are not the ring's {tris %d, meshes %d}" % (totals, tris, len(by)))
    if problems:
        raise GateError("; ".join(problems))
    return by


def trunk_ids(world=WORLD):
    path = world / "aero-trunks" / "aero-trunks-readback.json"
    if not path.exists():
        return set()
    return {m.group(1) for p in json.loads(path.read_text()).get("parts", [])
            for m in [ID.match(str(p.get("meshId", "")))] if m}


def bind(manifest, readback, fbx_sha, manifest_sha, used):
    """{name: (mesh id digits, raw size)} and {key: {color, normal?}}, or GateError. Pure: no file access."""
    try:
        bound = kit_validate(manifest, readback, fbx_sha, manifest_sha, used)
    except GateError as problem:
        raise GateError("grove: " + str(problem).replace("aero-kit", "grove"))
    images = readback.get("textures")
    if not isinstance(images, dict):
        raise GateError("readback is missing textures")
    out = {}
    for key, tex in manifest["textures"].items():
        got = images.get(key)
        if not isinstance(got, dict) or not ID.match(str(got.get("color", ""))):
            raise GateError("texture %s: no uploaded color image id" % key)
        row = {"color": got["color"], "studsPerTile": tex["studsPerTile"]}
        if tex.get("normal") is not None:
            if not ID.match(str(got.get("normal", ""))):
                raise GateError("texture %s: no uploaded normal image id" % key)
            row["normal"] = got["normal"]
        out[key] = row
    return bound, out


# ------------------------------------------------------------------------------------------------------------ outputs
def xml_part(index, mesh, mesh_id, raw, texture):
    sx, sy, sz = mesh["size"]
    far = mesh["band"] == "far"
    lines = [
        f"    <Item class=\"MeshPart\" referent=\"GV{index}\">",
        "      <Properties>",
        f"        <string name=\"Name\">{mesh['name']}</string>",
        f"        <Content name=\"MeshId\"><url>rbxassetid://{mesh_id}</url></Content>",
        # Colour only (ARCH-REVIEW-GROVE 6): a normal map would need a template-authored SurfaceAppearance.
        f"        <Content name=\"TextureID\"><url>{texture['color']}</url></Content>",
        f"        <Vector3 name=\"Size\"><X>{sx!r}</X><Y>{sy!r}</Y><Z>{sz!r}</Z></Vector3>",
        f"        <Vector3 name=\"InitialSize\"><X>{raw[0]!r}</X><Y>{raw[1]!r}</Y><Z>{raw[2]!r}</Z></Vector3>",
        "        <bool name=\"Anchored\">true</bool>",
        "        <bool name=\"CanCollide\">false</bool>",
        "        <bool name=\"CanQuery\">false</bool>",
        "        <bool name=\"CanTouch\">false</bool>",
        "        <bool name=\"CastShadow\">false</bool>",
        "        <bool name=\"DoubleSided\">false</bool>",
        "        <token name=\"CollisionFidelity\">2</token>",  # Box
        # Far band Performance (beyond 150 studs, not scriptable at runtime); the rest keep full detail (Precise).
        f"        <token name=\"RenderFidelity\">{2 if far else 1}</token>",
        "        <token name=\"Material\">256</token>",  # Plastic: matte surroundings
        f"        <Color3uint8 name=\"Color3uint8\">{(0xFF << 24) | 0xFFFFFF}</Color3uint8>",
        "        <float name=\"Reflectance\">0.0</float>",
        "      </Properties>",
        "    </Item>",
    ]
    return "".join(line + "\n" for line in lines)


def rbxmx(manifest=None, bound=None, textures=None):
    out = ["<roblox version=\"4\">\n",
           "  <Item class=\"Folder\" referent=\"GroveKit\">\n    <Properties>\n      <string name=\"Name\">GroveKit</string>\n    </Properties>\n"]
    for i, mesh in enumerate(manifest["meshes"] if bound else []):
        mesh_id, raw = bound[mesh["name"]]
        out.append(xml_part(i, mesh, mesh_id, raw, textures[mesh["texture"]]))
    out.append("  </Item>\n</roblox>\n")
    return "".join(out)


def lua(manifest=None, readback=None, textures=None):
    if readback is None:
        data = {"note": "Generated by scripts/build_world_grove_assets.py --placeholder. PLACEHOLDER: no grove upload "
                        "confirmed, so assetId is empty and GroveWorld builds nothing (the floating-island backdrop stays).",
                "assetId": ""}
        head = "--placeholder"
    else:
        data = {
            "note": "Generated by scripts/build_world_grove_assets.py from assets/world/grove. Roblox studs.",
            "version": manifest["version"],
            "coordinates": manifest["coordinates"],
            "turnApplied": manifest["turnApplied"],
            "assetId": str(readback["assetId"]),
            "meshes": {m["name"]: {k: m[k] for k in MESH_KEYS if k in m} for m in manifest["meshes"]},
            "instances": [{k: r[k] for k in ("mesh", "pivot", "yaw", "scale")} for r in manifest["instances"]],
            "textures": textures,
            "rays": [{k: r[k] for k in ("from", "to", "w0", "w1")} for r in manifest["rays"]],
            "sunGate": {k: manifest["sunGate"][k] for k in ("az", "el")},
            "moat": {k: manifest["moat"][k] for k in ("surfaceY", "bedOpaque")},
            "canopyBottomY": manifest["canopyBottomY"],
            "hides": sorted(manifest["hides"]),
            "lanterns": [{k: r[k] for k in ("pos", "kind")} for r in manifest["lanterns"]],
            "falls": [{k: r[k] for k in ("name", "top", "bottom", "width0", "width1", "normal")} for r in manifest["falls"]],
            "bubbles": [{k: r[k] for k in ("path", "period", "size")} for r in manifest["bubbles"]],
            "totals": {k: manifest["totals"][k] for k in ("tris", "meshes")},
        }
        head = ""
    body = json.dumps(data, separators=(",", ":"), sort_keys=True)
    return (f"-- Generated by scripts/build_world_grove_assets.py{(' ' + head) if head else ''}. Do not edit by hand.\n"
            f"return game:GetService(\"HttpService\"):JSONDecode([=[{body}]=])\n")


def used_ids(world=WORLD):
    return island_ids(world) | kit_ids() | trunk_ids(world)


def generate(grove=GROVE, world=WORLD):
    manifest_path = grove / "grove-manifest.json"
    readback_path = grove / "grove-readback.json"
    if not readback_path.exists():
        raise GateError("no readback yet: upload grove.fbx and record grove-readback.json")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    contract(manifest)
    readback = json.loads(readback_path.read_text(encoding="utf-8"))
    bound, textures = bind(manifest, readback, sha256(grove / "grove.fbx"), sha256(manifest_path), used_ids(world))
    return rbxmx(manifest, bound, textures), lua(manifest, readback, textures)


def fixture_lua(folder):
    """The runtime data a fixture manifest and readback make (scripts/fixtures/grove-fixture-*.json): the contract and
    the binding exactly as generate() runs them, the file hashes taken from the readback (there is no fixture FBX). The
    offline spec runner bundles the result as client/WorldGroveFixture."""
    manifest = json.loads((folder / "grove-fixture-manifest.json").read_text(encoding="utf-8"))
    readback = json.loads((folder / "grove-fixture-readback.json").read_text(encoding="utf-8"))
    contract(manifest)
    bound, textures = bind(manifest, readback, readback["fbxSha256"], readback["manifestSha256"], set())
    return lua(manifest, readback, textures)


def main(argv):
    if "--confirm" in argv:
        index = argv.index("--confirm")
        given = Path(argv[index + 1]).resolve() if index + 1 < len(argv) else None
        if given != (GROVE / "grove-readback.json").resolve():
            raise GateError("--confirm takes assets/world/grove/grove-readback.json")
        xml, code = generate()
    elif "--placeholder" in argv:
        xml, code = rbxmx(), lua()
    elif "--check" in argv:
        confirmed = (GROVE / "grove-readback.json").exists()
        xml, code = generate() if confirmed else (rbxmx(), lua())
        stale = [p.name for p, text in ((XML_OUT, xml), (LUA_OUT, code))
                 if not p.exists() or p.read_text(encoding="utf-8") != text]
        if stale:
            print("STALE:", ", ".join(stale))
            return 1
        print("Grove outputs match", "the confirmed readback" if confirmed else "the placeholder")
        return 0
    else:
        print(__doc__)
        return 2
    atomic_write(XML_OUT, xml)
    atomic_write(LUA_OUT, code)
    print("wrote", XML_OUT.relative_to(ROOT), "and", LUA_OUT.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except GateError as problem:
        print("REFUSED:", problem)
        sys.exit(1)
