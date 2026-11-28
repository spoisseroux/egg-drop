"""Turn the uploaded Hidden Grove pack into its runtime templates and data, behind a proof gate (the Aero kit's pattern).

    python scripts/build_world_grove_assets.py --confirm assets/world/grove/grove-readback.json
    python scripts/build_world_grove_assets.py --placeholder   (no upload yet: the safe outputs, nothing is built)
    python scripts/build_world_grove_assets.py --check         (fail when the committed outputs differ)

Inputs (assets/world/grove/, from scripts/build_world_grove.py and the upload; byte-exact, -text in .gitattributes):
- grove.fbx, grove-manifest.json, tex/*.png
- grove-readback.json  the Open Cloud upload (assetId, operationId, moderation), per MeshPart the MeshId and raw MeshSize
                       read back in Studio Edit, the image id of every texture ({key: {image | color}}), and the SHA256
                       of the FBX and manifest that were uploaded (the bytes as on disk)

The manifest is read as build_world_grove.py writes it (meshes keyed by name, coordinateRule, falls per gorge and tier
with one width, bubbles with radius and seconds, totals.triangles and groups) and normalised into the runtime contract
in src/shared/Grove.lua (the fixture's simpler forms are accepted too).

The gate (GateError, nothing written) refuses unless: the manifest keeps that contract (every field, GV_ names, no
shadows) and its budgets (45k tris counting instances, 10k a mesh, 40 draw groups counting every instance, 2k a far
mesh) and clearances (moat surfaceY <= -25, mid and far bands >= 45 past the rim, the sun gate's direction equal to the
manifest's sun); the readback names exactly the manifest's meshes, once each, with positive rbxassetids no island,
Aero kit or trunk pack mesh uses, raw sizes of one import scale (a flat axis, under FLAT studs, is exempt), an Approved
model, and the FBX and manifest on disk are the uploaded ones; and every texture a mesh names has an image id.

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
from build_world_aero_kit_assets import GateError, ID, atomic_write, island_ids, kit_ids, sha256  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / "assets" / "world"
GROVE = WORLD / "grove"
XML_OUT = WORLD / "GroveKit.rbxmx"
LUA_OUT = ROOT / "src" / "shared" / "WorldGrove.lua"
PREFIX = "GV_"
VERSION = 1
BANDS = {"near", "mid", "giant", "dressing", "far"}
BUDGET = {"tris": 45000, "perMesh": 10000, "groups": 40, "farMesh": 2000}
MOAT_TOP = -25
RIM = 45  # mid and far bands
MAX_RAYS = 9
MAX_BUBBLES = 5
SCALE_TOLERANCE = 2e-3
FLAT = .01       # an authored axis thinner than this (the moat's surface) is exempt from the scale check
MIN_SIZE = .05   # and stands this thick as a part (a MeshPart axis cannot be 0)
SUN_TOLERANCE = .01
MESH_KEYS = ("role", "band", "kind", "tris", "size", "center", "pivotToCentre", "texture", "shadow", "maxLevel", "minRimDist")
# The pool's look for the moat (WorldAero.Surfaces.water_pool: the teal tile at 14 studs; the moat's UVs are 16 a tile).
POOL_TEXTURE = "rbxassetid://135229051638910"
POOL_REFLECTANCE = .22


def finite(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def vec3(v):
    return isinstance(v, list) and len(v) == 3 and all(finite(x) for x in v)


def normalise(manifest):
    """The art lane's manifest as the runtime contract's shape (meshes a list sorted by name). Raises GateError."""
    if not isinstance(manifest, dict):
        raise GateError("manifest is not an object")
    out = dict(manifest)
    meshes = manifest.get("meshes")
    if isinstance(meshes, dict):
        rows = []
        for name, mesh in meshes.items():
            if not isinstance(mesh, dict) or mesh.get("name", name) != name:
                raise GateError("mesh %r: its name differs from its key" % name)
            rows.append(dict(mesh, name=name))
        meshes = rows
    if not isinstance(meshes, list):
        raise GateError("no meshes")
    out["meshes"] = sorted(meshes, key=lambda m: str(m.get("name")))
    out["coordinates"] = manifest.get("coordinates", manifest.get("coordinateRule"))
    falls = []
    for i, fall in enumerate(manifest.get("falls") or []):
        if not isinstance(fall, dict):
            raise GateError("fall %d" % (i + 1))
        row = dict(fall)
        if "width" in fall and "width0" not in fall:
            row["width0"] = row["width1"] = fall["width"]
        if "name" not in fall:
            row["name"] = "GV_Fall_%s_%s" % (fall.get("gorge", i + 1), fall.get("tier", 1))
        if "normal" not in fall and vec3(fall.get("top")) and vec3(fall.get("bottom")):
            # The sheet faces the way it falls out (toward the island): its drop, flattened.
            dx, dz = fall["bottom"][0] - fall["top"][0], fall["bottom"][2] - fall["top"][2]
            length = math.hypot(dx, dz)
            if length < 1e-6:
                raise GateError("fall %d drops straight down: no facing" % (i + 1))
            row["normal"] = [round(dx / length, 5), 0, round(dz / length, 5)]
        falls.append(row)
    out["falls"] = falls
    bubbles = []
    for i, bubble in enumerate(manifest.get("bubbles") or []):
        if not isinstance(bubble, dict):
            raise GateError("bubble %d" % (i + 1))
        row = dict(bubble)
        if "period" not in row and "seconds" in row:
            row["period"] = row["seconds"]
        if "size" not in row and finite(row.get("radius")):
            row["size"] = row["radius"] * 2
        bubbles.append(row)
    out["bubbles"] = bubbles
    rays = []
    for ray in manifest.get("rays") or []:
        row = dict(ray) if isinstance(ray, dict) else ray
        if isinstance(row, dict) and "phone" not in row:
            row["phone"] = True
        rays.append(row)
    out["rays"] = rays
    totals = manifest.get("totals")
    if isinstance(totals, dict):
        out["totals"] = {"tris": totals.get("tris", totals.get("triangles")), "meshes": totals.get("meshes"),
                         "groups": totals.get("groups")}
    return out


def contract(manifest):
    """The manifest side of Grove.validate, plus budgets and the clearances that need no Lua data. Takes the normalised
    manifest; returns {name: mesh}. Raises GateError."""
    for key in ("version", "coordinates", "turnApplied", "meshes", "instances", "textures", "rays", "sunGate", "moat",
                "canopyBottomY", "hides", "lanterns", "falls", "bubbles", "totals"):
        if manifest.get(key) is None:
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
        if not isinstance(tex, dict) or not finite(tex.get("studsPerTile")) or tex["studsPerTile"] <= 0:
            raise GateError("texture %s: needs a positive studsPerTile" % key)
    meshes = manifest["meshes"]
    if not meshes:
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
        if not vec3(m.get("size")) or min(m["size"]) < 0 or max(m["size"]) <= 0:
            raise GateError(name + ": size")
        if ("center" in m) == ("pivotToCentre" in m):
            raise GateError(name + ": needs exactly one of center and pivotToCentre")
        if not vec3(m.get("center", m.get("pivotToCentre"))):
            raise GateError(name + ": center or pivotToCentre")
        if m.get("texture") != "" and m.get("texture") not in textures:
            raise GateError(name + ": texture %r" % m.get("texture"))
        if m.get("shadow") is not False:
            raise GateError(name + ": shadow must be false (the ring casts none, ARCH-REVIEW-GROVE 6)")
        if m.get("maxLevel") not in (0, 1, 2) or isinstance(m.get("maxLevel"), bool):
            raise GateError(name + ": maxLevel")
        if not finite(m.get("minRimDist")):
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
    if len(rays) > MAX_RAYS:
        raise GateError("rays (at most %d)" % MAX_RAYS)
    for i, ray in enumerate(rays):
        if not (isinstance(ray, dict) and vec3(ray.get("from")) and vec3(ray.get("to")) and finite(ray.get("w0"))
                and finite(ray.get("w1")) and ray["w0"] > 0 and ray["w1"] > 0 and ray["from"][1] > ray["to"][1]
                and isinstance(ray.get("phone"), bool)):
            raise GateError("ray %d" % (i + 1))
    gate = manifest["sunGate"]
    if not (isinstance(gate, dict) and finite(gate.get("az")) and finite(gate.get("el")) and 0 <= gate["az"] < 360
            and 10 <= gate["el"] <= 90):
        raise GateError("sunGate is not {az 0-360, el 10-90} in degrees")
    sun = manifest.get("sun")
    if isinstance(sun, dict) and vec3(sun.get("dir")):
        az, el = math.radians(gate["az"]), math.radians(gate["el"])
        want = (math.cos(el) * math.cos(az), math.sin(el), math.cos(el) * math.sin(az))  # az from +X toward +Z
        if max(abs(a - b) for a, b in zip(want, sun["dir"])) > SUN_TOLERANCE:
            raise GateError("sunGate %r is not the sun's direction %r (az runs from +X toward +Z)" % (gate, sun["dir"]))
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
        if not (isinstance(fall.get("name"), str) and all(vec3(fall.get(k)) for k in ("top", "bottom", "normal"))
                and finite(fall.get("width0")) and finite(fall.get("width1")) and fall["width0"] > 0 and fall["width1"] > 0):
            raise GateError("fall %d" % (i + 1))
    bubbles = manifest["bubbles"]
    if len(bubbles) > MAX_BUBBLES:
        raise GateError("bubbles (at most %d)" % MAX_BUBBLES)
    for i, bubble in enumerate(bubbles):
        if not (isinstance(bubble.get("path"), list) and len(bubble["path"]) >= 2 and all(vec3(p) for p in bubble["path"])
                and finite(bubble.get("period")) and bubble["period"] > 0 and finite(bubble.get("size")) and bubble["size"] > 0):
            raise GateError("bubble %d" % (i + 1))
    # Budgets (every instance counted, a draw group a placed mesh or an instance) and the totals the art lane wrote.
    count = {}
    for row in manifest["instances"]:
        count[row["mesh"]] = count.get(row["mesh"], 0) + 1
    tris = sum(m["tris"] * (count.get(name, 0) if "pivotToCentre" in m else 1) for name, m in by.items())
    groups = sum(1 for m in by.values() if "center" in m) + len(manifest["instances"])
    problems = []
    for name, m in sorted(by.items()):
        if m["tris"] > BUDGET["perMesh"]:
            problems.append("%s: %d tris (over %d)" % (name, m["tris"], BUDGET["perMesh"]))
        if m["band"] == "far" and m["tris"] > BUDGET["farMesh"]:
            problems.append("%s: far band %d tris (over %d)" % (name, m["tris"], BUDGET["farMesh"]))
        if m["band"] in ("mid", "far") and m["minRimDist"] < RIM:
            problems.append("%s: %g past the rim (%s band needs %d)" % (name, m["minRimDist"], m["band"], RIM))
    if tris > BUDGET["tris"]:
        problems.append("ring %d tris (over %d)" % (tris, BUDGET["tris"]))
    if groups > BUDGET["groups"]:
        problems.append("%d draw groups (over %d)" % (groups, BUDGET["groups"]))
    if moat["surfaceY"] > MOAT_TOP:
        problems.append("moat surfaceY %g is over %d" % (moat["surfaceY"], MOAT_TOP))
    totals = manifest["totals"]
    if totals.get("tris") != tris or totals.get("meshes") != len(by) or totals.get("groups") != groups:
        problems.append("totals %r are not the ring's {tris %d, meshes %d, groups %d}" % (totals, tris, len(by), groups))
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
    """({name: (mesh id digits, raw size)}, {key: {color, studsPerTile}}) or GateError. Pure: no file access. The Aero
    kit gate's rules, with a flat axis (the moat's surface) exempt from the one-import-scale check."""
    if not isinstance(readback, dict):
        raise GateError("readback is not an object")
    for key in ("assetId", "operationId", "moderation", "fbxSha256", "manifestSha256", "parts", "textures"):
        if key not in readback:
            raise GateError("readback is missing " + key)
    if not str(readback["assetId"]).isdigit() or int(readback["assetId"]) <= 0:
        raise GateError("assetId is not a positive number")
    if str(readback["moderation"]) != "Approved":
        raise GateError("the grove model is " + str(readback["moderation"]) + ", not Approved")
    if readback["fbxSha256"] != fbx_sha:
        raise GateError("grove.fbx is not the uploaded file")
    if readback["manifestSha256"] != manifest_sha:
        raise GateError("grove-manifest.json is not the uploaded one")
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
            raise GateError(part["name"] + ": meshId already belongs to the island or an Aero pack")
        seen.add(digits)
        raw = part.get("meshSize")
        if not (isinstance(raw, list) and len(raw) == 3 and all(finite(v) and v >= 0 for v in raw)):
            raise GateError(part["name"] + ": meshSize is not three finite numbers")
        for authored, got in zip(want[part["name"]]["size"], raw):
            if authored < FLAT:
                continue
            if got <= 0:
                raise GateError(part["name"] + ": a raw size of 0 on an axis that is not flat")
            scales.append((part["name"], got / authored))
        out[part["name"]] = (digits, [float(v) for v in raw])
    if scales:
        base = scales[0][1]
        for name, scale in scales:
            if abs(scale - base) > SCALE_TOLERANCE * base:
                raise GateError("%s: raw size is not the manifest size times one import scale (%.5f vs %.5f)" % (name, scale, base))
        if finite(readback.get("importScale")) and abs(readback["importScale"] - base) > 1e-2 * base:
            raise GateError("the raw sizes' import scale %.4f is not the readback's %.4f" % (base, readback["importScale"]))
    images = readback["textures"]
    if not isinstance(images, dict):
        raise GateError("readback textures is not an object")
    needed = {m["texture"] for m in manifest["meshes"] if m["texture"]}
    textures = {}
    for key, tex in manifest["textures"].items():
        got = images.get(key)
        image = got.get("image", got.get("color")) if isinstance(got, dict) else None
        if not ID.match(str(image or "")):
            if key in needed:
                raise GateError("texture %s: no uploaded image id" % key)
            continue
        textures[key] = {"color": image, "studsPerTile": tex["studsPerTile"]}
    return out, textures


# ------------------------------------------------------------------------------------------------------------ outputs
def part_size(size):
    return [max(float(v), MIN_SIZE) for v in size]


def xml_part(index, mesh, mesh_id, raw, textures):
    sx, sy, sz = part_size(mesh["size"])
    initial = [v if v > 0 else 1e-3 for v in raw]
    kind = mesh.get("kind")
    texture = textures[mesh["texture"]]["color"] if mesh["texture"] else ""
    material, reflectance = 256, 0.0  # Plastic: matte surroundings (vertex colours show on the untextured ones)
    if kind == "water":
        texture, reflectance = POOL_TEXTURE, POOL_REFLECTANCE  # the pool's look
    elif mesh["role"] in ("lantern", "lanterns") or kind == "glow":
        material = 272  # SmoothPlastic by day; GroveLight turns it Neon at night
    far = mesh["band"] == "far"
    lines = [
        f"    <Item class=\"MeshPart\" referent=\"GV{index}\">",
        "      <Properties>",
        f"        <string name=\"Name\">{mesh['name']}</string>",
        f"        <Content name=\"MeshId\"><url>rbxassetid://{mesh_id}</url></Content>",
        # Colour only (ARCH-REVIEW-GROVE 6): a normal map would need a template-authored SurfaceAppearance.
        f"        <Content name=\"TextureID\">{f'<url>{texture}</url>' if texture else '<url />'}</Content>",
        f"        <Vector3 name=\"Size\"><X>{sx!r}</X><Y>{sy!r}</Y><Z>{sz!r}</Z></Vector3>",
        f"        <Vector3 name=\"InitialSize\"><X>{initial[0]!r}</X><Y>{initial[1]!r}</Y><Z>{initial[2]!r}</Z></Vector3>",
        "        <bool name=\"Anchored\">true</bool>",
        "        <bool name=\"CanCollide\">false</bool>",
        "        <bool name=\"CanQuery\">false</bool>",
        "        <bool name=\"CanTouch\">false</bool>",
        "        <bool name=\"CastShadow\">false</bool>",
        f"        <bool name=\"DoubleSided\">{'true' if mesh.get('doubleSided') else 'false'}</bool>",
        "        <token name=\"CollisionFidelity\">2</token>",  # Box
        # Enum.RenderFidelity: Automatic 0, Precise 1, Performance 2 (not scriptable at runtime). The far band Automatic
        # (the engine's distance LODs; Performance held its lowest LOD even up close); the rest keep full detail (Precise).
        f"        <token name=\"RenderFidelity\">{0 if far else 1}</token>",
        f"        <token name=\"Material\">{material}</token>",
        f"        <Color3uint8 name=\"Color3uint8\">{(0xFF << 24) | 0xFFFFFF}</Color3uint8>",
        f"        <float name=\"Reflectance\">{reflectance!r}</float>",
        "      </Properties>",
        "    </Item>",
    ]
    return "".join(line + "\n" for line in lines)


def rbxmx(manifest=None, bound=None, textures=None):
    out = ["<roblox version=\"4\">\n",
           "  <Item class=\"Folder\" referent=\"GroveKit\">\n    <Properties>\n      <string name=\"Name\">GroveKit</string>\n    </Properties>\n"]
    for i, mesh in enumerate(manifest["meshes"] if bound else []):
        mesh_id, raw = bound[mesh["name"]]
        out.append(xml_part(i, mesh, mesh_id, raw, textures))
    out.append("  </Item>\n</roblox>\n")
    return "".join(out)


def lua(manifest=None, readback=None, textures=None):
    if readback is None:
        data = {"note": "Generated by scripts/build_world_grove_assets.py --placeholder. PLACEHOLDER: no grove upload "
                        "confirmed, so assetId is empty and GroveWorld builds nothing (the floating-island backdrop stays).",
                "assetId": ""}
        head = "--placeholder"
    else:
        meshes = {}
        for m in manifest["meshes"]:
            row = {k: m[k] for k in MESH_KEYS if k in m}
            row["size"] = part_size(m["size"])
            meshes[m["name"]] = row
        data = {
            "note": "Generated by scripts/build_world_grove_assets.py from assets/world/grove. Roblox studs.",
            "version": manifest["version"],
            "coordinates": manifest["coordinates"],
            "turnApplied": manifest["turnApplied"],
            "assetId": str(readback["assetId"]),
            "meshes": meshes,
            "instances": [{k: r[k] for k in ("mesh", "pivot", "yaw", "scale")} for r in manifest["instances"]],
            "textures": textures,
            "rays": [{k: r[k] for k in ("from", "to", "w0", "w1", "phone")} for r in manifest["rays"]],
            "sunGate": {k: manifest["sunGate"][k] for k in ("az", "el")},
            "moat": {k: manifest["moat"][k] for k in ("surfaceY", "bedOpaque")},
            "canopyBottomY": manifest["canopyBottomY"],
            "hides": sorted(manifest["hides"]),
            "lanterns": [{k: r[k] for k in ("pos", "kind")} for r in manifest["lanterns"]],
            "falls": [{k: r[k] for k in ("name", "top", "bottom", "width0", "width1", "normal")} for r in manifest["falls"]],
            "bubbles": [{k: r[k] for k in ("path", "period", "size")} for r in manifest["bubbles"]],
            "totals": {k: manifest["totals"][k] for k in ("tris", "meshes", "groups")},
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
    manifest = normalise(json.loads(manifest_path.read_text(encoding="utf-8")))
    contract(manifest)
    readback = json.loads(readback_path.read_text(encoding="utf-8"))
    bound, textures = bind(manifest, readback, sha256(grove / "grove.fbx"), sha256(manifest_path), used_ids(world))
    return rbxmx(manifest, bound, textures), lua(manifest, readback, textures)


def fixture_lua(folder):
    """The runtime data a fixture manifest and readback make (scripts/fixtures/grove-fixture-*.json): normalised, the
    contract and the binding exactly as generate() runs them, the file hashes taken from the readback (there is no
    fixture FBX). The offline spec runner bundles the result as client/WorldGroveFixture."""
    manifest = normalise(json.loads((folder / "grove-fixture-manifest.json").read_text(encoding="utf-8")))
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
