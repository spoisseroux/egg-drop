"""The world finish art's runtime pack and data (WORLD-FINISH-ART-BUILD.md), from the Blender manifests, the uploads and
the Studio readback.

  python scripts/build_world_finish_pack.py                  write both outputs (the pack only for slices with a readback)
  python scripts/build_world_finish_pack.py --check          fail when either committed output differs from a fresh build
  python scripts/build_world_finish_pack.py --readback den FILE
                                                             record a Studio readback (the JSON world_finish_readback.luau
                                                             prints) for a slice, then write

Inputs (assets/world/world-finish/): world-finish-<slice>.json (scripts/build_world_finish_art.py), the FBX each one was
exported with, world-finish-uploads.json (Open Cloud ids and the sha256 of every file as uploaded) and
world-finish-readback-<slice>.json (per MeshPart: name, meshId, meshSize, read in Studio Edit with InsertService:LoadAsset).

A slice goes into the pack only when everything binds: the FBX and manifest on disk are the bytes uploaded, every image
it uses is uploaded with the same bytes and not rejected, the readback names exactly the manifest's meshes with positive
unique ids, and every raw MeshSize is the manifest size times one import scale. Otherwise the slice is left out (its
templates absent, so WorldFinishMount leaves the beta as it is) and the reason printed.

Outputs:
  assets/world/WorldFinish.rbxmx    Folder WorldFinish: a Version StringValue and the MeshPart templates (SurfaceAppearance
                                    authored here: game scripts cannot parent one at runtime). Mounted at
                                    ServerStorage.WorldFinish by default.project.json only; live never has it.
  src/server/WorldFinishData.lua    what the mount does per slice: parts to hide, fixed parts (CFrame, Size), instances,
                                    extra collision boxes, the den's dress (lanterns, paw stones, apron). Server only.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "assets" / "world" / "world-finish"
XML_OUT = ROOT / "assets" / "world" / "WorldFinish.rbxmx"
LUA_OUT = ROOT / "src" / "server" / "WorldFinishData.lua"
SLICES = ("den", "path", "terrace")
SCALE_TOLERANCE = 3e-3
MATTE_ROUGHNESS = "rbxassetid://132217078330162"     # build_world_v7_assets.py: white roughness (1), black metalness
MATTE_METALNESS = "rbxassetid://114363080604088"
MATERIAL = {"SmoothPlastic": 272, "Plastic": 256, "Neon": 288, "Slate": 800, "Metal": 1088, "Fabric": 1312, "Wood": 512}
TURN = (-1, 0, 0, 0, 1, 0, 0, 0, -1)                   # Ry(pi): the Roblox FBX import turns each mesh (AeroKit.Turn)


def sha(path: Path) -> str:
    data = path.read_bytes()
    if path.suffix == ".json":                       # text: a CRLF checkout (core.autocrlf) must still bind
        data = data.replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()


def cliff_den_version() -> str:
    text = (ROOT / "src" / "shared" / "CliffDenData.lua").read_text(encoding="utf-8")
    return json.loads(re.search(r"\[=\[(.*)\]=\]", text, re.S).group(1))["version"]


def island_textures() -> dict:
    return json.loads((ROOT / "assets" / "world" / "world-v7-uploads.json").read_text(encoding="utf-8"))["textures"]


def island_look(beta_part: dict) -> dict:
    """The live island's look for a pack part (build_world_v7_assets.look and double_sided on its real material and
    region), so a re-cut copy matches it: texture, colour, material, shadow, double-sided (code review 2)."""
    sys.path.insert(0, str(ROOT / "scripts"))
    import importlib
    v7 = importlib.import_module("build_world_v7_assets")
    part = {"material": beta_part["material"], "region": beta_part["region"], "name": beta_part["name"]}
    lk = dict(v7.look(part))
    lk["doubleSided"] = v7.double_sided(part, lk)
    return lk


# ------------------------------------------------------------------------------------------------------- binding
def bind(slice_: str, manifest: dict, uploads: dict):
    """(readback rows by name, scale, problems) for a slice; problems empty when it binds."""
    problems = []
    up = uploads.get(slice_)
    rb_path = DIR / f"world-finish-readback-{slice_}.json"
    if not up:
        return None, None, [f"{slice_}: not uploaded"]
    fbx = DIR / up["model"]["file"]
    if sha(fbx) != up["model"]["sha256"]:
        problems.append(f"{slice_}: {fbx.name} differs from the upload")
    if sha(DIR / f"world-finish-{slice_}.json") != up["model"]["manifestSha256"]:
        problems.append(f"{slice_}: the manifest differs from the one uploaded with the FBX")
    if (up["model"].get("moderation") or "").lower() == "rejected" or not up["model"].get("assetId"):
        problems.append(f"{slice_}: the model is not uploaded or was rejected")
    for key, img in up.get("images", {}).items():
        if sha(DIR / img["file"]) != img["sha256"]:
            problems.append(f"{slice_}: {img['file']} differs from the upload")
        if (img.get("moderation") or "").lower() == "rejected":
            problems.append(f"{slice_}: image {key} was rejected")
    if not rb_path.is_file():
        return None, None, problems + [f"{slice_}: no Studio readback yet ({rb_path.name})"]
    rb = json.loads(rb_path.read_text(encoding="utf-8"))
    if str(rb.get("assetId")) != str(up["model"]["assetId"]):
        problems.append(f"{slice_}: the readback is of model {rb.get('assetId')}, not {up['model']['assetId']}")
    rows = {r["name"]: r for r in rb.get("parts", [])}
    names = {p["name"] for p in manifest["parts"]}
    if set(rows) != names:
        problems.append(f"{slice_}: readback names differ: missing {sorted(names - set(rows))}, extra {sorted(set(rows) - names)}")
    ids = [str(r.get("meshId", "")) for r in rows.values()]
    if any(not re.fullmatch(r"rbxassetid://[1-9][0-9]*", i) for i in ids) or len(set(ids)) != len(ids):
        problems.append(f"{slice_}: mesh ids must be positive and unique")
    scales = []
    for p in manifest["parts"]:
        r = rows.get(p["name"])
        if not r:
            continue
        for raw, size in zip(r["meshSize"], p["size"]):
            if size > .05:
                scales.append(raw / size)
    scale = sorted(scales)[len(scales) // 2] if scales else None
    if scale and any(abs(s / scale - 1) > SCALE_TOLERANCE * 10 for s in scales):
        problems.append(f"{slice_}: raw mesh sizes are not one import scale of the manifest sizes")
    return rows, scale, problems


# ----------------------------------------------------------------------------------------------------- the pack
def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def colour3(hexs: str) -> int:
    h = hexs.lstrip("#")
    return (0xFF << 24) | int(h, 16)


def xml_part(ref: str, part: dict, row: dict, images: dict) -> str:
    look = part["look"]
    texture, colour, material, transparency, sa = "", "#FFFFFF", "SmoothPlastic", 0.0, None
    shadow, double = bool(part.get("shadow")), bool(part.get("doubleSided"))
    kind = look["kind"]
    if kind in ("baked", "tile"):
        sa = {"ColorMap": images[look["color"]], "NormalMap": images[look["normal"]]}
    elif kind == "island":
        sa = {"ColorMap": island_textures()["W1_" + look["material"]]}
    elif kind == "copy":
        beta = json.loads((ROOT / "assets" / "world" / "world-v7-beta-manifest.json").read_text(encoding="utf-8"))
        lk = island_look(next(p for p in beta["parts"] if p["name"] == look["of"]))
        texture = lk["texture"]
        colour = "#%02X%02X%02X" % tuple(lk["color"])
        material, transparency = lk["material"], lk["transparency"]
        shadow, double = lk["shadow"], lk["doubleSided"]
        if lk.get("matte"):
            sa = {"ColorMap": lk["texture"]}
    elif kind == "flat":
        colour, material, transparency = look["color"], look["material"], look.get("transparency", 0.0)
    sx, sy, sz = (max(v, .001) for v in part["size"])
    raw = row["meshSize"]
    lines = [
        f'    <Item class="MeshPart" referent="{ref}">',
        "      <Properties>",
        f'        <string name="Name">{esc(part["name"])}</string>',
        f'        <Content name="MeshId"><url>{row["meshId"]}</url></Content>',
        f'        <Content name="TextureID">{f"<url>{texture}</url>" if texture else "<url />"}</Content>',
        f'        <Vector3 name="Size"><X>{sx!r}</X><Y>{sy!r}</Y><Z>{sz!r}</Z></Vector3>',
        f'        <Vector3 name="InitialSize"><X>{raw[0]!r}</X><Y>{raw[1]!r}</Y><Z>{raw[2]!r}</Z></Vector3>',
        '        <bool name="Anchored">true</bool>',
        '        <bool name="CanCollide">false</bool>',
        '        <bool name="CanQuery">false</bool>',
        '        <bool name="CanTouch">false</bool>',
        f'        <bool name="CastShadow">{"true" if shadow else "false"}</bool>',
        f'        <bool name="DoubleSided">{"true" if double else "false"}</bool>',
        '        <token name="CollisionFidelity">2</token>',
        f'        <token name="Material">{MATERIAL[material]}</token>',
        f'        <Color3uint8 name="Color3uint8">{colour3(colour)}</Color3uint8>',
        f'        <float name="Transparency">{float(transparency)!r}</float>',
        "      </Properties>",
    ]
    if sa:
        lines += [f'      <Item class="SurfaceAppearance" referent="{ref}S">', "        <Properties>",
                  '          <string name="Name">MatteFinish</string>', '          <token name="AlphaMode">0</token>',
                  f'          <Content name="ColorMap"><url>{sa["ColorMap"]}</url></Content>',
                  f'          <Content name="MetalnessMap"><url>{MATTE_METALNESS}</url></Content>',
                  f'          <Content name="RoughnessMap"><url>{MATTE_ROUGHNESS}</url></Content>']
        if "NormalMap" in sa:
            lines.append(f'          <Content name="NormalMap"><url>{sa["NormalMap"]}</url></Content>')
        if look.get("tint"):                     # SurfaceAppearance.Color multiplies the map (Fable world R1 3, 5)
            assert re.fullmatch(r"#[0-9A-Fa-f]{6}", look["tint"]), look["tint"]
            h = look["tint"].lstrip("#")
            r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
            lines.append(f'          <Color3 name="Color"><R>{r:.6f}</R><G>{g:.6f}</G><B>{b:.6f}</B></Color3>')
        lines += ["        </Properties>", "      </Item>"]
    lines.append("    </Item>")
    return "\n".join(lines) + "\n"


# ------------------------------------------------------------------------------------------------------ the data
def _mul(a, b):
    return [sum(a[3 * i + k] * b[3 * k + j] for k in range(3)) for i in range(3) for j in range(3)]


def _ry(t):
    c, s = math.cos(t), math.sin(t)
    return [c, 0, s, 0, 1, 0, -s, 0, c]


def _rz(t):
    c, s = math.cos(t), math.sin(t)
    return [c, -s, 0, s, c, 0, 0, 0, 1]


def cf(pos, yaw=0.0, offset=(0, 0, 0), tilt=0.0):
    """CFrame components (12 numbers) for CFrame.new(pos) * Ry(yaw) * Rz(tilt) * CFrame.new(offset) * Ry(pi)."""
    r = _mul(_ry(yaw), _rz(tilt))
    ox, oy, oz = offset
    p = [pos[i] + r[3 * i] * ox + r[3 * i + 1] * oy + r[3 * i + 2] * oz for i in range(3)]
    rot = _mul(r, _ry(math.pi))
    return [round(v, 5) for v in p + rot]


def rot_rows(yaw):
    """CliffDenSwap box rotation rows (CFrame.new's nine numbers) for Ry(yaw)."""
    return [round(v, 6) for v in _ry(yaw)]


def slice_data(manifest: dict, allparts: dict | None = None) -> dict:
    parts = {p["name"]: p for p in manifest["parts"]}
    place = manifest.get("place", {})
    out = {"hide": manifest.get("hide", []), "hideVisual": manifest.get("hideVisual", []), "fixed": [], "instances": [], "boxes": [], "tufts": [],
           "templates": sorted(n for n, p in parts.items()), "triangles": sum(p["triangles"] for p in parts.values())}
    for p in manifest["parts"]:
        if p["role"] != "fixed":
            continue
        row = {"name": p["name"], "cframe": cf(p["centre"]), "size": p["size"]}
        for k in ("replaces", "overlays"):
            if p.get(k):
                row[k] = p[k]
        out["fixed"].append(row)

    def inst(template, at, yaw, scale, tilt=0.0):
        t = (allparts or parts)[template]
        size = [round(a * b, 4) for a, b in zip(t["size"], scale)]
        off = [a * b for a, b in zip(t["centre"], scale)]
        return {"template": template, "cframe": cf(at, yaw, off, tilt), "size": size}

    for c in place.get("crystals", []):
        out["instances"].append(inst("W7_F_Den__crystal", c["at"], c["yaw"], (c["scale"],) * 3))
    for s in place.get("stones", []) + place.get("apronStones", []):
        out["instances"].append(inst("W7_F_Stone__flat", s["at"], s["yaw"], s["size"]))
    for lp in place.get("lips", []):
        out["instances"].append(inst(f"W7_F_Lip{lp['kit']}__boulder_rock", lp["at"], lp["yaw"], (1, 1, 1)))
    for b in place.get("boulders", []):
        out["instances"].append(inst(f"W7_F_Lip{b['kit']}__boulder_rock", b["at"], b["yaw"], b["scale"]))
    for row in place.get("logs", []) + place.get("trunks", []):
        out["instances"].append(inst(row["template"], row["at"], row["yaw"], (1, 1, 1)))
    if place.get("kitCrowns"):
        kit = open(ROOT / "assets" / "world" / "AeroKit.rbxmx", encoding="utf-8").read()
        out["kitCrowns"] = []
        for row in place["kitCrowns"]:
            m = re.search(r'<string name="Name">' + re.escape(row["template"]) + r'</string>.*?<Vector3 name="Size"><X>([^<]+)</X>'
                          r'<Y>([^<]+)</Y><Z>([^<]+)</Z>', kit, re.S)
            size = [round(float(v) * row["scale"], 4) for v in m.groups()]
            out["kitCrowns"].append({"template": row["template"], "cframe": cf(row["at"], row["yaw"]), "size": size})
    if place.get("dressTier"):
        out["dressTier"] = place["dressTier"]
    for s in place.get("stakes", []):
        out["instances"].append(inst("W7_F_Stake__wood", s["at"], s["yaw"], (1, 1, 1), s.get("lean", 0.0)))
    out["boxes"] = list(place.get("mouthBoxes", [])) + [
        {"kind": "lipstone", "c": lp["box"]["c"], "s": lp["box"]["s"], "r": rot_rows(lp["box"]["yaw"])}
        for lp in place.get("lips", []) if "box" in lp] + [
        {"kind": b["kind"], "c": b["c"], "s": b["s"], "r": rot_rows(b["yaw"])} for b in place.get("extraBoxes", [])]
    if place.get("requires"):
        out["requires"] = place["requires"]
    # templates borrowed from an earlier slice (the terrace's lip stones are the path's kit): the mount checks them too
    out["templates"] = sorted(set(out["templates"]) | {i["template"] for i in out["instances"]})
    out["tufts"] = place.get("tufts", [])
    if place.get("ropes"):
        out["ropes"], out["rope"] = place["ropes"], place["rope"]
    if place.get("hideBoxes"):
        out["hideBoxes"] = place["hideBoxes"]
    if "W7_F_Lantern__cage" in parts:
        lan = place.get("lanterns", {})
        out["dress"] = {
            "lantern": {name: {"offset": parts[name]["centre"], "size": parts[name]["size"]}
                        for name in ("W7_F_Lantern__cage", "W7_F_Lantern__pane")},
            "ledgeY": lan.get("ledgeY"),
            "paw": dict(place.get("paw", {}), offset=parts["W7_F_Stone__flat"]["centre"],
                        unit=parts["W7_F_Stone__flat"]["size"]),
        }
        for key in ("frame", "cloth"):
            if place.get(key):
                out["dress"][key] = place[key]
    # the path's lip-stone kit, so other builders can place it (round 5: the Top Lawn's rim boulders)
    kit = {n: {"size": p["size"], "centre": p["centre"]} for n, p in parts.items() if re.match(r"W7_F_Lip\d+__", n)}
    if kit and manifest.get("slice") == "path":
        out["kit"] = kit
    return out


def lua(data: dict) -> str:
    body = json.dumps(data, separators=(",", ":"), sort_keys=True)
    assert "]=]" not in body
    return ("-- Generated by scripts/build_world_finish_pack.py (WORLD-FINISH-ART-BUILD.md): what WorldFinishMount does per\n"
            "-- slice of the world finish art (beta only: the pack is mounted by default.project.json alone). Do not edit by\n"
            "-- hand. Server only.\n"
            f'return game:GetService("HttpService"):JSONDecode([=[{body}]=])\n')


def build():
    uploads = json.loads((DIR / "world-finish-uploads.json").read_text(encoding="utf-8"))
    manifests = {s: json.loads((DIR / f"world-finish-{s}.json").read_text(encoding="utf-8"))
                 for s in SLICES if (DIR / f"world-finish-{s}.json").is_file()}
    digest = hashlib.sha256()
    for s in sorted(manifests):
        digest.update((DIR / f"world-finish-{s}.json").read_bytes().replace(b"\r\n", b"\n"))
    version = digest.hexdigest()[:16]
    data = {"version": version, "cliffDen": cliff_den_version(), "slices": {}}
    items, notes = [], []
    for s, m in manifests.items():
        rows, scale, problems = bind(s, m, uploads)
        d = slice_data(m, {p["name"]: p for mm in manifests.values() for p in mm["parts"]})
        d["packed"] = not problems
        data["slices"][s] = d
        if problems:
            notes += problems
            continue
        images = {k: "rbxassetid://" + v["assetId"] for k, v in uploads[s].get("images", {}).items()}
        for k, p in enumerate(m["parts"]):
            items.append(xml_part(f"WF{s[0].upper()}{k}", p, rows[p["name"]], images))
    xml = ('<roblox version="4">\n  <Item class="Folder" referent="WorldFinish">\n    <Properties>\n'
           '      <string name="Name">WorldFinish</string>\n    </Properties>\n'
           '    <Item class="StringValue" referent="WorldFinishVersion">\n      <Properties>\n'
           '        <string name="Name">Version</string>\n'
           f'        <string name="Value">{version}</string>\n      </Properties>\n    </Item>\n'
           + "".join(items) + "  </Item>\n</roblox>\n")
    return xml, lua(data), notes


def main(argv) -> int:
    if "--readback" in argv:
        at = argv.index("--readback")
        slice_, src = argv[at + 1], Path(argv[at + 2])
        rb = json.loads(src.read_text(encoding="utf-8"))
        (DIR / f"world-finish-readback-{slice_}.json").write_text(json.dumps(rb, indent=1) + "\n", encoding="utf-8")
    xml, text, notes = build()
    if "--check" in argv:
        stale = [p.name for p, want in ((XML_OUT, xml), (LUA_OUT, text))
                 if not p.is_file() or p.read_text(encoding="utf-8") != want]
        beta = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8-sig"))["tree"]["ServerStorage"]
        if beta.get("WorldFinish") != {"$path": "assets/world/WorldFinish.rbxmx"}:
            stale.append("default.project.json must mount ServerStorage.WorldFinish from the pack")
        if "WorldFinish" in (ROOT / "launch.project.json").read_text(encoding="utf-8-sig"):
            stale.append("launch.project.json (live) must never mount the WorldFinish pack")
        if stale:
            print("WorldFinish STALE:", ", ".join(stale))
            return 1
        print("WorldFinish PASS", "(" + "; ".join(notes) + ")" if notes else "")
        return 0
    XML_OUT.write_text(xml, encoding="utf-8", newline="\n")
    LUA_OUT.write_text(text, encoding="utf-8", newline="\n")
    print("WorldFinish written", "(" + "; ".join(notes) + ")" if notes else "")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
