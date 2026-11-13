"""Build the World 1 v7 runtime template and data module from the merge manifest and the Studio import.

Inputs (assets/world/):
- world-v7-manifest.json       from scripts/build_world_v7_chunks.py (Roblox centre/size per merged mesh)
- world-v7-walk.json           perimeter wall, cave blocker, fall catch, wet boxes, ground heights
- world-v7-studio-import.json  mesh asset id and raw MeshSize per part, read back from the Open Cloud insert
- world-v7-uploads.json        texture and sky image ids

Outputs:
- assets/world/WorldAssets.rbxmx  Folder WorldAssets > Model WorldV7 of MeshParts, mounted at ServerStorage.WorldAssets.
  Size = authored size (the Open Cloud import scaled the whole model by 1.0823 so its largest part hit 2048, so the raw
  MeshSize is kept only as InitialSize). The import turns meshes by pi about Y, so each CFrame carries Ry(pi).
- src/shared/WorldV7Data.lua      generated data: part roles, collision boxes, wet boxes, sky ids, water beams.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / "assets" / "world"
MANIFEST = json.loads((WORLD / "world-v7-manifest.json").read_text())
WALK = json.loads((WORLD / "world-v7-walk.json").read_text())
IMPORT = json.loads((WORLD / "world-v7-studio-import.json").read_text())
UPLOADS = json.loads((WORLD / "world-v7-uploads.json").read_text())
# Invisible ground collision tiles (scripts/build_world_v7_collision.py): the visual ground stops colliding.
COLLISION = json.loads((WORLD / "world-v7-collision.json").read_text())
COLLISION_IMPORT = json.loads((WORLD / "world-v7-collision-studio-import.json").read_text())["parts"]
for _tile in COLLISION["parts"]:
    IMPORT[_tile["name"]] = COLLISION_IMPORT[_tile["name"]]
    MANIFEST["parts"].append({"name": _tile["name"], "group": "GroundCollision", "material": "W1_collision", "tris": _tile["tris"],
                              "collide": True, "anim": None, "region": "GroundCollision", "center": _tile["center"], "size": _tile["size"]})
for _part in MANIFEST["parts"]:
    if _part["region"] == "Ground":
        _part["collide"] = False
    # QA 2026-11-12: the hub-tree lantern rope stopped 4 studs under the canopy. Run it
    # from the glow (bottom 9.2) up into the foliage (16.5); the mesh is a thin cylinder.
    if _part["name"] == "W7_Lantern__bark":
        _part["center"] = [_part["center"][0], 12.85, _part["center"][2]]
        _part["size"] = [_part["size"][0], 7.3, _part["size"][2]]
LANTERN_PIVOT = next([p["center"][0], p["center"][1] + p["size"][1] / 2, p["center"][2]]
                     for p in MANIFEST["parts"] if p["name"] == "W7_Lantern__bark")

# Blender base colours (sRGB) for untextured, unpaletted materials.
FLAT = {
    "W1_glow_warm": (255, 216, 137), "W1_glow_aqua": (79, 230, 255), "W1_glow_pink": (255, 128, 207),
    "W1_cloud": (250, 252, 255), "W1_foam": (240, 250, 252), "W1_bubble": (216, 245, 255),
}
MATERIAL_TOKEN = {"SmoothPlastic": 272, "Plastic": 256, "Fabric": 1312, "Neon": 288, "Glass": 1568}
# Matte finish (polish 2026-11-12): SmoothPlastic read glossy on foliage, grass, ground and rock.
# Textured natural surfaces get a SurfaceAppearance with their own colour map, a uniformly white
# roughness map (roughness 1) and a black metalness map, so they lose the specular sheen without
# touching the global EnvironmentSpecularScale that pets and water rely on. The uniform maps are
# the place's existing pet-material uploads (assets/pet-materials/white-opaque.png, metalness-zero.png).
MATTE_ROUGHNESS = "rbxassetid://132217078330162"
MATTE_METALNESS = "rbxassetid://114363080604088"
MATTE = {"W1_grass", "W1_meadow", "W1_dirt_path", "W1_pebble_bed", "W1_foliage", "W1_foliage_blossom",
         "W1_bark", "W1_cliff_rock", "W1_boulder_rock", "W1_wood_plank"}
# W1_ground is a near-white detail texture tinted by mesh vertex colours, which a SurfaceAppearance
# drops (the slopes turn white), so it takes the rough Fabric material instead.
FABRIC = {"W1_ground"}
# Marble and the painted palette props keep a very slight sheen; gold trim and water stay glossy.
SOFT_SHEEN = {"W1_marble", "W1_marble_smooth", "W1_palette"}
FIDELITY = {"Default": 0, "Hull": 1, "Box": 2, "PreciseConvexDecomposition": 3}


def look(part):
    mat = part["material"]
    region = part["region"]
    tex = UPLOADS["textures"].get(mat, "")
    out = {"texture": tex, "color": (255, 255, 255), "material": "SmoothPlastic", "transparency": 0.0, "shadow": True}
    if mat in FLAT:
        out["color"] = FLAT[mat]
    if mat.startswith("W1_glow"):
        out["material"] = "Neon"
        out["shadow"] = False
    if mat == "W1_bubble":
        out.update(material="Glass", transparency=0.45, shadow=False)
    if mat in ("W1_water", "W1_water_pool", "W1_water_stream"):
        out.update(transparency=0.12, shadow=False)
    if mat.startswith("W1_waterfall"):
        out.update(transparency=0.08, shadow=False)
    if mat == "W1_foam":
        out.update(transparency=0.15, shadow=False)
    if mat == "W1_cloud":
        out.update(transparency=0.35 if region == "Water" else 0.0, shadow=False)
    if region == "GroundCollision":
        out.update(transparency=1.0, shadow=False)
    if region in ("Backdrop", "Underside", "IsletsA", "IsletsB", "DriftRocksA", "DriftRocksB", "Crystals"):
        out["shadow"] = False
    if region == "Vegetation" and mat == "W1_palette":
        out["shadow"] = False  # flowers
    if mat in MATTE and tex:
        out["matte"] = True
    elif mat in FABRIC:
        out["material"] = "Fabric"
    elif mat in SOFT_SHEEN:
        out["material"] = "Plastic"
    return out


def xml_matte(index, texture):
    lines = [
        f"        <Item class=\"SurfaceAppearance\" referent=\"W7S{index}\">",
        "          <Properties>",
        "            <string name=\"Name\">MatteFinish</string>",
        "            <token name=\"AlphaMode\">0</token>",
        f"            <Content name=\"ColorMap\"><url>{texture}</url></Content>",
        f"            <Content name=\"MetalnessMap\"><url>{MATTE_METALNESS}</url></Content>",
        f"            <Content name=\"RoughnessMap\"><url>{MATTE_ROUGHNESS}</url></Content>",
        "          </Properties>",
        "        </Item>",
    ]
    return "".join(line + "\n" for line in lines)


SINGLE_SIDED = ("water", "glow", "cloud", "bubble", "foam", "collision")


def double_sided(part, lk):
    """Opaque, visible scenery only: water, glows and see-through layers stay one-sided."""
    if part["region"] == "GroundCollision" or lk["transparency"] > 0:
        return False
    return not any(tag in part["material"] for tag in SINGLE_SIDED)


def xml_part(index, part):
    name = part["name"]
    mesh_id, *raw = IMPORT[name]
    cx, cy, cz = part["center"]
    sx, sy, sz = (max(v, 0.001) for v in part["size"])
    lk = look(part)
    r, g, b = lk["color"]
    color = (0xFF << 24) | (r << 16) | (g << 8) | b
    collide = part["collide"]
    texture = f"<url>{lk['texture']}</url>" if lk["texture"] else "<url />"
    return (
        f"      <Item class=\"MeshPart\" referent=\"W7P{index}\">\n        <Properties>\n"
        f"          <string name=\"Name\">{name}</string>\n"
        f"          <Content name=\"MeshId\"><url>rbxassetid://{mesh_id}</url></Content>\n"
        f"          <Content name=\"TextureID\">{texture}</Content>\n"
        f"          <Vector3 name=\"Size\"><X>{sx!r}</X><Y>{sy!r}</Y><Z>{sz!r}</Z></Vector3>\n"
        f"          <Vector3 name=\"InitialSize\"><X>{raw[0]!r}</X><Y>{raw[1]!r}</Y><Z>{raw[2]!r}</Z></Vector3>\n"
        "          <CoordinateFrame name=\"CFrame\">"
        f"<X>{cx!r}</X><Y>{cy!r}</Y><Z>{cz!r}</Z>"
        "<R00>-1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>-1</R22>"
        "</CoordinateFrame>\n"
        "          <bool name=\"Anchored\">true</bool>\n"
        f"          <bool name=\"CanCollide\">{'true' if collide else 'false'}</bool>\n"
        f"          <bool name=\"CanQuery\">{'true' if collide else 'false'}</bool>\n"
        "          <bool name=\"CanTouch\">false</bool>\n"
        f"          <bool name=\"CastShadow\">{'true' if lk['shadow'] else 'false'}</bool>\n"
        # QA 2026-11-12: some imported faces are wound inward (stair treads, column capitals,
        # tree crowns) and Roblox culled them. Opaque visible scenery renders both sides.
        f"          <bool name=\"DoubleSided\">{'true' if double_sided(part, lk) else 'false'}</bool>\n"
        f"          <token name=\"CollisionFidelity\">{FIDELITY['PreciseConvexDecomposition' if collide else 'Box']}</token>\n"
        f"          <token name=\"Material\">{MATERIAL_TOKEN[lk['material']]}</token>\n"
        f"          <Color3uint8 name=\"Color3uint8\">{color}</Color3uint8>\n"
        f"          <float name=\"Transparency\">{lk['transparency']!r}</float>\n"
        "        </Properties>\n"
        + (xml_matte(index, lk["texture"]) if lk.get("matte") else "")
        + "      </Item>\n")


def rbxmx():
    out = ["<roblox version=\"4\">\n",
           "  <Item class=\"Folder\" referent=\"WorldAssets\">\n    <Properties>\n      <string name=\"Name\">WorldAssets</string>\n    </Properties>\n",
           "    <Item class=\"Model\" referent=\"WorldV7\">\n      <Properties>\n        <string name=\"Name\">WorldV7</string>\n      </Properties>\n"]
    for i, part in enumerate(MANIFEST["parts"]):
        out.append(xml_part(i, part))
    out.append("    </Item>\n  </Item>\n</roblox>\n")
    return "".join(out)


ANIM = {
    # region -> motion; amplitude in studs or degrees, period in seconds
    "IsletsA": {"kind": "bob", "amp": 0.8, "period": 9.0, "phase": 0.0},
    "IsletsB": {"kind": "bob", "amp": 0.8, "period": 11.0, "phase": 0.5},
    "DriftRocksA": {"kind": "bob", "amp": 1.4, "period": 8.0, "phase": 0.2},
    "DriftRocksB": {"kind": "bob", "amp": 1.4, "period": 10.0, "phase": 0.7},
    "Bubbles": {"kind": "bob", "amp": 0.35, "period": 2.6, "phase": 0.1},
    "Lantern": {"kind": "sway", "amp": 4.0, "period": 4.2, "phase": 0.3},
    "CradleMobile": {"kind": "spin", "amp": 10.0, "period": 7.0, "phase": 0.0},
    "LampOrbs": {"kind": "pulse", "amp": 0.25, "period": 3.4, "phase": 0.0},
    "Crystals": {"kind": "pulse", "amp": 0.3, "period": 5.0, "phase": 0.4},
    "ArrivalGlow": {"kind": "pulse", "amp": 0.35, "period": 2.8, "phase": 0.0},
    "NestHalo": {"kind": "pulse", "amp": 0.3, "period": 2.4, "phase": 0.2},
}


def parts_data():
    out = {}
    for p in MANIFEST["parts"]:
        entry = {"region": p["region"], "collide": p["collide"], "center": p["center"], "size": p["size"]}
        motion = ANIM.get(p["region"])
        if p["region"].startswith("Chime_"):
            k = int(p["region"].split("_")[1])
            motion = {"kind": "sway", "amp": 7.0, "period": 2.6 + k * 0.23, "phase": k * 0.17}
        elif p["region"].startswith("Pennant_"):
            k = int(p["region"].split("_")[1])
            motion = {"kind": "sway", "amp": 9.0, "period": 1.7 + k * 0.3, "phase": k * 0.4}
        elif p["name"] == "W7_Water__foam":
            motion = {"kind": "bob", "amp": 0.12, "period": 0.8, "phase": 0.0}
        elif p["name"] == "W7_Water__cloud":
            motion = {"kind": "bob", "amp": 1.2, "period": 6.0, "phase": 0.0}
        if motion:
            entry["motion"] = motion
            if motion["kind"] in ("sway", "spin"):
                # The lantern's rope and glow swing together from the rope's top.
                entry["pivot"] = LANTERN_PIVOT if p["region"] == "Lantern" else [p["center"][0], p["center"][1] + p["size"][1] / 2, p["center"][2]]
        out[p["name"]] = entry
    return out


def beams():
    stream = [w for w in WALK["wet"] if w["name"] == "Water_Stream"]
    points = [[w["center"][0], 3.28, w["center"][2], round(min(w["size"][0], w["size"][2]) * 0.8, 2)] for w in stream]
    falls = []
    for name in ("W7_Water__waterfall_tumble", "W7_Water__waterfall_sky"):
        p = next(x for x in MANIFEST["parts"] if x["name"] == name)
        c, s = p["center"], p["size"]
        falls.append({"name": name, "top": [c[0], c[1] + s[1] / 2, c[2]], "bottom": [c[0], c[1] - s[1] / 2, c[2]],
                      "width": round(min(s[0], s[2]) * 0.6, 2)})
    return {"stream": points, "falls": falls}


def lua_data():
    data = {
        "note": "Generated by scripts/build_world_v7_assets.py. Roblox studs.",
        "parts": parts_data(),
        "perimeter": WALK["perimeter"], "caveBlocker": WALK["CaveBlocker"], "fallCatch": WALK["FallCatch"],
        "wet": WALK["wet"], "sky": UPLOADS["sky"], "waterTexture": UPLOADS["textures"]["W1_water"],
        "fallTexture": UPLOADS["textures"]["W1_waterfall_tumble"], "beams": beams(),
        "triangles": MANIFEST["triangles"], "meshParts": MANIFEST["count"], "collisionTiles": len(COLLISION["parts"]),
        "ground": {k: WALK["ground"][k] for k in ("x0", "z0", "step", "nx", "nz")} | {
            "h": [(-999 if v is None else v) for row in WALK["ground"]["heights"] for v in row]},
    }
    body = json.dumps(data, separators=(",", ":"))
    return ("-- Generated by scripts/build_world_v7_assets.py from assets/world/*.json. Do not edit by hand.\n"
            f"return game:GetService(\"HttpService\"):JSONDecode([=[{body}]=])\n")


def palette_png():
    """Swatch i at column i % side, row i // side from the BOTTOM, as in Blender UV space (checked in Studio)."""
    from PIL import Image
    pal = json.loads((WORLD / "world-v7-palette.json").read_text())
    side, px = pal["side"], pal["px"]
    img = Image.new("RGB", (side * px, side * px), (255, 0, 255))
    for i, name in enumerate(pal["order"]):
        c = tuple(round(v * 255) for v in pal["srgb"][name])
        sx, sy = i % side, side - 1 - i // side
        for y in range(sy * px, sy * px + px):
            for x in range(sx * px, sx * px + px):
                img.putpixel((x, y), c)
    (WORLD / "textures").mkdir(exist_ok=True)
    img.save(WORLD / "textures" / "palette-roblox.png")


def main():
    palette_png()
    (WORLD / "WorldAssets.rbxmx").write_text(rbxmx(), newline="\n")
    (ROOT / "src" / "shared" / "WorldV7Data.lua").write_text(lua_data(), newline="\n")
    print("wrote WorldAssets.rbxmx and WorldV7Data.lua", MANIFEST["count"], "parts")


if __name__ == "__main__":
    main()
