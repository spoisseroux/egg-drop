"""Add wing stages S1-S5 and the launch wearables to pet-bear-attachments.blend, then export the
attachment FBX set and manifest.

Run (background Blender only):
  blender -b assets/art-source/pets/pet-bear-attachments.blend --python scripts/export_bear_attachments.py

Convention matches assets/garden-babies/bear.fbx: axis_forward=-Z, axis_up=Y, meshes named Bear__<Role>,
world transform baked, pet root at the origin, 1 unit = 1 stud. Blender pet-local: front -Y, up +Z, L = -X.
Outputs go to assets/garden-babies/attachments/. Pass `-- --no-save` to leave the .blend untouched.

The wearables (hats, shirts, necklaces, helix piercings, alternate eyes, mouth and tail) are rebuilt on
every run by scripts/build_bear_wearables.py, which also holds the item list (ids, display names, Star
price tiers). An item is one or more meshes sharing an item id; the manifest lists them under `items`.
Shirts are always Torso (Body channel) + SleeveL/R (HandL/HandR channels, origin on the shoulder anchor),
plus trim pieces; check them with scripts/check_bear_shirt.py.
"""
import bpy, bmesh, json, math, sys
from pathlib import Path
from mathutils import Vector

REPO = Path(bpy.data.filepath).resolve().parents[3]
OUT = REPO / "assets" / "garden-babies" / "attachments"
OUT.mkdir(parents=True, exist_ok=True)
D = bpy.data.objects
root = D["PetBear"]

# ---------- wing stages: S5 is the Bear's existing wing, smaller stages scale toward the anchor ----------
WING_STAGES = {1: ("Bud", 0.38), 2: ("Flutter", 0.52), 3: ("Wing", 0.68), 4: ("Glide", 0.84), 5: ("Crown", 1.00)}
col = bpy.data.collections.get("PetBear_FeatureWings")
if col is None:
    col = bpy.data.collections.new("PetBear_FeatureWings")
    bpy.context.scene.collection.children.link(col)
for side in "LR":
    src = D["PetBear__Wing" + side]
    for stage, (label, s) in WING_STAGES.items():
        name = f"PetBear__Wing{side}_S{stage}"
        old = D.get(name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        me = src.data.copy()
        me.name = name
        zs = s ** 0.8  # small stages stay a little taller than wide, so they read as stubby baby wings
        for v in me.vertices:
            v.co = Vector((v.co.x * s, v.co.y * s, v.co.z * zs))
        ob = bpy.data.objects.new(name, me)
        col.objects.link(ob)
        ob.parent = src.parent
        ob.matrix_parent_inverse = src.matrix_parent_inverse.copy()
        ob.matrix_basis = src.matrix_basis.copy()
        for k, v in dict(role="Wing" + side, channel="Body", slot="Back", feature="wings", stage=stage,
                         stageName=label, optional=True, spanScale=s, heightScale=round(zs, 4)).items():
            ob[k] = v
        ob.hide_render = True
        ob.hide_set(True)


# ---------- wearables: final art, rebuilt from code ----------
_builder = Path(__file__).with_name("build_bear_wearables.py")
_ns = {"__name__": "build_bear_wearables"}
exec(compile(_builder.read_text(encoding="utf-8"), str(_builder), "exec"), _ns)
ITEMS, TIERS = _ns["ITEMS"], _ns["TIERS"]
WEARABLES = [o.name.split("__", 1)[1] for o in bpy.data.collections["PetBear_Wearables"].objects]
bpy.context.view_layer.update()


# ---------- helpers ----------
def world(o):
    """Explicit parent chain, so hidden objects (not evaluated) are right too."""
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()


ROOT_INV = world(root).inverted()


def local(o):
    return ROOT_INV @ world(o)


def r(v, n=5):
    return [round(float(x), n) + 0.0 for x in v]


KIND = {}
for n in "HatCrown HornL HornR HelixL HelixR LobeL LobeR WristL WristR ClawL ClawR ToeL ToeR".split():
    KIND[n] = "surface"
for n in "EyeL EyeR FaceBridge EyeLine Forehead CheekL CheekR Nose Mouth Chest Back".split():
    KIND[n] = "face"
CHANNEL_OLD = {"Body": "Body", "Head": "Head", "EyeLine": "Head", "HandCatch": "Root", "HandL": "HandL", "HandR": "HandR",
               "FootL": "FootL", "FootR": "FootR", "Tail": "Body", "EarL": "Head", "EarR": "Head", "WingL": "Body",
               "WingR": "Body", "CharmFloat": "Root", "CharmLeft": "Root", "CharmRight": "Root", "CharmCenter": "Root",
               "CharmAnchor": "Root"}
SLOT_OLD = {"Tail": "Tail", "WingL": "Back", "WingR": "Back", "CharmFloat": "Charm", "CharmLeft": "Charm",
            "CharmRight": "Charm", "CharmCenter": "Charm", "CharmAnchor": "Charm", "HandL": "Sleeve", "HandR": "Sleeve"}

anchors = []
for o in sorted(D, key=lambda o: o.name):
    if o.type != "EMPTY" or "__Anchor_" not in o.name:
        continue
    name = o.name.split("__Anchor_")[1]
    m = local(o)
    rot = m.to_3x3().normalized()
    e = rot.to_euler("XYZ")
    p = m.to_translation()
    anchors.append({
        "name": name, "blenderName": o.name,
        "channel": o.get("channel") or CHANNEL_OLD.get(name, "Root"),
        "slot": o.get("slot") or SLOT_OLD.get(name),
        "kind": KIND.get(name, "swap"),
        "isNew": bool(o.get("mock")),
        "positionBlender": r(p),
        "eulerXYZDegBlender": r([math.degrees(a) for a in e], 3),
        "axesBlender": {"x": r(rot.col[0]), "y": r(rot.col[1]), "z": r(rot.col[2])},
        "positionRuntime": r((p.x, p.z, -p.y)),
        "note": o.get("note", ""),
    })

GROUPS = {
    "horns": [f"Horn{s}_S{i}" for i in range(1, 6) for s in "LR"],
    "wings": [f"Wing{s}_S{i}" for i in range(1, 6) for s in "LR"],
    "piercings": [n for n in WEARABLES if n.startswith("Helix")],
    "wearables": [n for n in WEARABLES if n.split("_")[0] in ("Shirt", "Neck", "Hat")],
    "face-alts": ["EyeL_AltRound", "EyeR_AltRound", "EyeL_AltSmallWide", "EyeR_AltSmallWide", "Mouth_AltW"]
                 + [n for n in WEARABLES if n.startswith(("Eye", "Mouth"))],
    "tails": [n for n in WEARABLES if n.startswith("Tail")],
}
SLOT_FIX = {"Horn": "Horns", "Wing": "Back", "Eye": "Eyes", "Mouth": "Mouth", "Tail": "Tail"}
SLOT_ANCHOR = {"EyeL": "EyeL", "EyeR": "EyeR", "Mouth": "Mouth"}
COLOR_ROLE = {"petBear__secondary": "secondary", "petBear__body": "body", "petBear__eye": "eyeTexture",
              "petBear__mouth": "mouthTexture", "petBear__nose": "face", "petBear__wing": "wingTexture",
              "attach__ink": "face", "attach__metal": "own:#FFC240", "attach__bead": "own:#F2EDD9",
              "attach__cloth": "own:#1A8C9E", "attach__knit": "own:#5440BF"}
BOOL_KEYS = ("alternate", "placeholder", "coversHorns", "hidesEars", "openCrown", "lowBrim", "printedChest",
             "noEyewear", "neutralOnly", "tintBySecondary", "shell")
COPY_KEYS = ("feature", "stage", "stageName", "variant", "item", "piece", "displayName", "tier", "price", "height",
             "baseRadius", "majorRadius", "minorRadius", "shellOffset", "spanScale", "heightScale") + BOOL_KEYS

export_scene = bpy.data.scenes.new("AttachmentExport")
made, meshes = {}, []
for group, names in GROUPS.items():
    for short in names:
        src = D["PetBear__" + short]
        me = src.data.copy()
        me.transform(local(src))
        me.update()
        ob = bpy.data.objects.new("Bear__" + short, me)
        export_scene.collection.objects.link(ob)
        made[short] = ob
        me.calc_loop_triangles()
        lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
        hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
        c, s = (lo + hi) / 2, hi - lo
        anchor = src.parent.name.split("__Anchor_")[1]
        role = src.get("role", short)
        slot = src.get("slot") or next(v for k, v in SLOT_FIX.items() if short.startswith(k))
        slot_anchor = SLOT_ANCHOR.get(role, anchor) if slot in ("Eyes", "Mouth") else anchor
        mat = src.data.materials[0].name if src.data.materials else ""
        channel = src.get("channel")
        entry = {
            "name": ob.name, "source": src.name, "fbx": f"bear-attachments-{group}.fbx", "group": group,
            "slot": slot, "anchor": slot_anchor, "parentAnchor": anchor,
            "channel": "Root" if channel == "CharmAnchor" else channel,
            "role": role, "colorRole": src.get("colorRole") or COLOR_ROLE.get(mat, mat), "material": mat,
            "originBlender": r(local(src).to_translation()),
            "centerBlender": r(c), "sizeBlender": r(s),
            "centerRuntime": r((c.x, c.z, -c.y)), "sizeRuntime": r((s.x, s.z, s.y)),
            "triangles": len(me.loop_triangles), "hasUV": bool(me.uv_layers),
            "defaultVisible": False,
        }
        for k in COPY_KEYS:
            if k in src.keys():
                v = src[k]
                entry[k] = bool(v) if k in BOOL_KEYS else (round(v, 4) if isinstance(v, float) else v)
        meshes.append(entry)


def export(path, objs):
    for o in export_scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False,
                             object_types={"MESH"}, add_leaf_bones=False, bake_anim=False, path_mode="AUTO",
                             mesh_smooth_type="FACE")


bpy.context.window.scene = export_scene
export(OUT / "bear-attachments.fbx", list(made.values()))
for group, names in GROUPS.items():
    export(OUT / f"bear-attachments-{group}.fbx", [made[n] for n in names])

# Every shirt has these three pieces (plus any trim on the Body channel).
SHIRT_PIECES = [{"piece": "Torso", "mesh": "Bear__Shirt_<Variant>_Torso", "channel": "Body", "anchor": "Torso"},
                {"piece": "SleeveL", "mesh": "Bear__Shirt_<Variant>_SleeveL", "channel": "HandL", "anchor": "HandL"},
                {"piece": "SleeveR", "mesh": "Bear__Shirt_<Variant>_SleeveR", "channel": "HandR", "anchor": "HandR"}]

items = []
for item_id, info in ITEMS.items():
    parts = [m for m in meshes if m.get("item") == item_id]
    assert parts, item_id
    row = {"id": item_id, "slot": info["slot"], "displayName": info["name"], "tier": info["tier"],
           "price": TIERS[info["tier"]], "triangles": sum(m["triangles"] for m in parts),
           "tintBySecondary": any(m.get("tintBySecondary") for m in parts),
           "primaryColor": parts[0]["colorRole"],
           "flags": dict(info["flags"]),
           "pieces": [{"piece": m["piece"], "mesh": m["name"], "channel": m["channel"], "anchor": m["parentAnchor"],
                       "colorRole": m["colorRole"], "tintBySecondary": bool(m.get("tintBySecondary")),
                       "triangles": m["triangles"]} for m in parts]}
    if info["slot"] == "Shirt":
        need = {("Torso", "Body"), ("SleeveL", "HandL"), ("SleeveR", "HandR")}
        assert need <= {(p["piece"], p["channel"]) for p in row["pieces"]}, row
    if info["slot"] == "EarPiercing":
        row["perSide"] = True
    assert row["triangles"] <= 600, row
    items.append(row)

HORN_NAMES = {1: "Bud", 2: "Nub", 3: "Horn", 4: "Curl", 5: "Crown"}
for m in meshes:
    if m.get("feature") == "horns":
        m["stageName"] = HORN_NAMES[m["stage"]]

manifest = {
    "schema": 1, "asset": "bear-attachments",
    "sourceBlend": "assets/art-source/pets/pet-bear-attachments.blend",
    "builtBy": "scripts/export_bear_attachments.py",
    "axes": "FBX axis_forward=-Z axis_up=Y, same as bear.fbx. Blender pet-local: front -Y, up +Z, L = -X, paws at z = 0, 1 unit = 1 stud.",
    "conversions": {
        "blenderToRuntime": "(x, y, z) -> (x, z, -y)  [runtime: front +Z, up +Y]",
        "blenderToStudioTemplate": "(x, y, z) -> (-x, z, y)  [import template: front -Z]",
        "note": "Same mapping scripts/build_bear_assets.py uses. Meshes are exported with the world transform baked and the pet root at the origin, so each imports at its pet-local position. Studio default FBX units give a uniform 100x MeshSize; Size = MeshSize/100, as for the Bear.",
    },
    "anchorKinds": {"surface": "local +Z leaves the surface; local Y stays close to pet +Y",
                    "face": "identity rotation; part modelled pushed out along -Y",
                    "swap": "identity rotation; origin at the joint"},
    "files": {"all": "bear-attachments.fbx", **{g: f"bear-attachments-{g}.fbx" for g in GROUPS}},
    "anchors": anchors,
    "meshes": meshes,
    "priceTiers": TIERS,
    "items": items,
    "features": {
        "horns": {"slot": "Horns", "anchors": ["HornL", "HornR"], "stages": 5, "colorRole": "secondary",
                  "meshPattern": "Bear__Horn{L|R}_S{1..5}",
                  "show": "exactly one stage per side; L and R always share the stage"},
        "wings": {"slot": "Back", "anchors": ["WingL", "WingR"], "stages": 5,
                  "colorRole": "wingTexture (the Bear's wing map, tinted secondary)",
                  "meshPattern": "Bear__Wing{L|R}_S{1..5}",
                  "show": "exactly one stage per side; S5 is identical to the Bear's existing Bear__WingL/R",
                  "stageScale": {str(k): {"name": v[0], "span": v[1], "height": round(v[1] ** 0.8, 4)}
                                 for k, v in WING_STAGES.items()}},
    },
    "slots": {
        "Hat": {"max": 1}, "Horns": {"max": 1, "staged": True}, "EarPiercing": {"max": 1, "perSide": True},
        "Earring": {"max": 1, "perSide": True}, "Eyes": {"max": 1, "swap": True}, "Eyewear": {"max": 1},
        "Mouth": {"max": 1, "swap": True}, "Nose": {"max": 1, "swap": True}, "Forehead": {"max": 1},
        "Cheek": {"max": 1}, "Neck": {"max": 1},
        "Shirt": {"max": 1, "pieces": SHIRT_PIECES}, "Chest": {"max": 1}, "Back": {"max": 1},
        "Tail": {"max": 1, "swap": True}, "Claws": {"max": 1, "staged": True}, "Wrist": {"max": 1, "perSide": True},
        "Ankle": {"max": 1, "perSide": True}, "Charm": {"max": 1}, "Aura": {"max": 1},
    },
    "exclusions": {
        "rule": "Hide, never unequip. A blocked item stays owned and selected and returns when the blocker comes off.",
        "hides": [
            {"blocker": "Hat", "unlessFlag": "openCrown", "hides": ["Horns", "Charm@CharmCenter"]},
            {"blocker": "Hat", "whenFlag": "hidesEars", "hides": ["EarPiercing", "Earring"]},
            {"blocker": "Hat", "whenFlag": "lowBrim", "hides": ["Forehead"]},
            {"blocker": "Shirt", "whenFlag": "printedChest", "hides": ["Chest"]},
            {"blocker": "Eyes", "whenFlag": "noEyewear", "hides": ["Eyewear"]},
            {"blocker": "Mittens (future hand item)", "hides": ["Claws@ClawL", "Claws@ClawR"]},
        ],
        "oneOf": [
            {"slot": "Back", "items": "wings (any stage) | backpack | cape"},
            {"slot": "Neck", "items": "necklace | scarf | collar; draws over a Shirt"},
            {"slot": "Eyes", "items": "default EyeL/R | AltRound | AltSmallWide | sparkle | sleepy; a swap hides Bear__EyeL/R"},
            {"slot": "Mouth", "items": "default MouthSmile | AltW | blep (neutralOnly: replaces the neutral frame only); the expression system still picks the frame"},
            {"slot": "Tail", "items": "species Tail | heart; a swap hides Bear__Tail"},
            {"slot": "Horns", "items": "stages S1..S5, one visible"},
            {"slot": "Back (wings)", "items": "stages S1..S5, one visible"},
        ],
        "notes": [
            "Horn stage 4 or 5 lifts CharmFloat by 0.10 so a floating charm clears the tips.",
            "beanie and sunhat are full hats (coversHorns). flowercrown is a wreath round the head under the ears: openCrown (horns and the centre charm stay) and lowBrim (it covers the Forehead slot).",
            "An item is every mesh that shares its item id (`item`, also `variant`); all its pieces are shown and hidden together. Pieces exist because a mesh has one colour: `tintBySecondary` pieces take the pet's secondary colour, `face` pieces the face ink, `own:#hex` pieces keep their colour.",
            "A shirt is Shirt_<Variant>_Torso on Body plus Shirt_<Variant>_SleeveL on HandL and Shirt_<Variant>_SleeveR on HandR, and any trim (stripes, hem, star, hood) on Body. The sleeves pivot on the shoulder anchors with the arms.",
            "Helix piercings are sold as a pair (one item id, a mesh per ear) but the two ears stay independent slots.",
        ],
    },
    "wearablesNote": "The 13 launch wearables are final art built by scripts/build_bear_wearables.py. The grey-box placeholders (Shirt_Torso/SleeveL/SleeveR, AltButton eyes, AltO mouth, AltArrow tail) are gone; Hat_Beanie, Neck_Beads and HelixL/R_Ring keep their names with final meshes. Studio must re-import the FBX set before scripts/build_bear_attachments.py will run.",
}
(OUT / "attachments-manifest.json").write_text(json.dumps(manifest, indent=1), newline="\n")

bpy.context.window.scene = bpy.data.scenes[0]
for o in list(export_scene.objects):
    me = o.data
    bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.meshes.remove(me)
bpy.data.scenes.remove(export_scene)
if "--no-save" not in sys.argv:
    bpy.ops.wm.save_mainfile()
print("EXPORTED", len(meshes), "meshes,", len(anchors), "anchors ->", OUT)
