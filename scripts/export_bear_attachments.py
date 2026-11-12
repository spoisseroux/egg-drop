"""Add wing stages S1-S5 and the three-piece shirt to pet-bear-attachments.blend, then export the
attachment FBX set and manifest.

Run (background Blender only):
  blender -b assets/art-source/pets/pet-bear-attachments.blend --python scripts/export_bear_attachments.py

Convention matches assets/garden-babies/bear.fbx: axis_forward=-Z, axis_up=Y, meshes named Bear__<Role>,
world transform baked, pet root at the origin, 1 unit = 1 stud. Blender pet-local: front -Y, up +Z, L = -X.
Outputs go to assets/garden-babies/attachments/. Pass `-- --no-save` to leave the .blend untouched.

Shirts are always three meshes: Shirt_Torso (Body channel, Torso anchor) and Shirt_SleeveL/R (HandL/HandR
channels, origin on the shoulder anchor). The sleeves are rebuilt here from the arm meshes on every run;
check them with scripts/check_bear_shirt.py.
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


# ---------- shirt: torso shell on Body, one sleeve per arm on HandL/HandR ----------
# A sleeve is a shell of the arm mesh itself, so it wraps the arm at a fixed offset and turns with it about
# the shoulder anchor. The cuff is a slanted plane: short on the outside of the arm, long on the side that
# faces the body, because that side sweeps inside the torso shell when the arm folds +-35 degrees.
SLEEVE_OFFSET = 0.020        # sleeve surface above the arm surface
SLEEVE_AXIS = (-0.525, -0.277, -0.805)   # down the left arm from the shoulder (pet-local); x mirrors for R
SLEEVE_CUFF_T = 0.268        # where the cuff plane crosses the arm axis, measured from the shoulder anchor
SLEEVE_CUFF_LEAN = (0.90, 0.40, 0.0)     # the cuff gets longer in this direction (toward the body, a bit back)
SLEEVE_CUFF_SLOPE = 0.62     # extra sleeve length per unit of distance from the axis along the lean
SLEEVE_LIP = 0.030           # the cuff turns in this far, so it closes onto the arm

placeholders = bpy.data.collections["PetBear_AttachPlaceholders"]
torso = D.get("PetBear__Shirt_Torso") or D.get("PetBear__Shirt_Tee")
torso.name = torso.data.name = "PetBear__Shirt_Torso"
SHIRT_PROPS = dict(mock=True, slot="Shirt", placeholder=True, variant="tee")
for k, v in dict(SHIRT_PROPS, role="Shirt", channel="Body").items():
    torso[k] = v
for side, sx in (("L", 1.0), ("R", -1.0)):
    for old in (f"PetBear__Shirt_Tee_Sleeve{side}", f"PetBear__Shirt_Sleeve{side}"):
        if D.get(old):
            me = D[old].data
            bpy.data.objects.remove(D[old], do_unlink=True)
            if me.users == 0:
                bpy.data.meshes.remove(me)
    arm = D["PetBear__Hand" + side]
    name = f"PetBear__Shirt_Sleeve{side}"
    bm = bmesh.new()
    bm.from_mesh(arm.data)
    bm.normal_update()
    for v in bm.verts:  # push out so every face around the vertex ends up SLEEVE_OFFSET above the arm
        tight = min((v.normal.dot(f.normal) for f in v.link_faces), default=1.0)
        v.co += v.normal * (SLEEVE_OFFSET / max(tight, 0.45))
    axis = Vector((SLEEVE_AXIS[0] * sx, SLEEVE_AXIS[1], SLEEVE_AXIS[2])).normalized()
    lean = Vector((SLEEVE_CUFF_LEAN[0] * sx, SLEEVE_CUFF_LEAN[1], SLEEVE_CUFF_LEAN[2]))
    lean = (lean - axis * lean.dot(axis)).normalized()
    to_arm = arm.matrix_basis.inverted() @ arm.matrix_parent_inverse.inverted()  # anchor space -> mesh space
    plane_no = (to_arm.to_3x3() @ (axis - lean * SLEEVE_CUFF_SLOPE)).normalized()
    plane_co = to_arm @ (axis * SLEEVE_CUFF_T)
    cut = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=plane_co,
                                 plane_no=plane_no, clear_outer=True)["geom_cut"]
    rim = [e for e in cut if isinstance(e, bmesh.types.BMEdge)]
    for e in rim:
        e.smooth = False
    lip = [v for v in bmesh.ops.extrude_edge_only(bm, edges=rim)["geom"] if isinstance(v, bmesh.types.BMVert)]
    middle = sum((v.co for v in lip), Vector()) / len(lip)
    for v in lip:  # the lip stays in the cuff plane and ends just under the arm surface
        out = v.co - middle
        v.co = middle + out * max(0.0, 1.0 - SLEEVE_LIP / out.length)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.smooth = True
        f.material_index = 0
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(torso.data.materials[0])
    me.calc_loop_triangles()
    ob = bpy.data.objects.new(name, me)
    placeholders.objects.link(ob)
    ob.parent = arm.parent
    ob.matrix_parent_inverse = arm.matrix_parent_inverse.copy()
    ob.matrix_basis = arm.matrix_basis.copy()
    for k, v in dict(SHIRT_PROPS, role="Sleeve" + side, channel="Hand" + side, tris=len(me.loop_triangles),
                     shellOffset=SLEEVE_OFFSET).items():
        ob[k] = v

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
    "piercings": ["HelixL_Ring", "HelixR_Ring"],
    "wearables": ["Shirt_Torso", "Shirt_SleeveL", "Shirt_SleeveR", "Neck_Beads", "Hat_Beanie"],
    "face-alts": ["EyeL_AltRound", "EyeR_AltRound", "EyeL_AltSmallWide", "EyeR_AltSmallWide", "EyeL_AltButton",
                  "EyeR_AltButton", "Mouth_AltW", "Mouth_AltO"],
    "tails": ["Tail_AltArrow"],
}
SLOT_FIX = {"Horn": "Horns", "Wing": "Back", "Eye": "Eyes", "Mouth": "Mouth", "Tail": "Tail"}
SLOT_ANCHOR = {"EyeL": "EyeL", "EyeR": "EyeR", "Mouth": "Mouth"}
COLOR_ROLE = {"petBear__secondary": "secondary", "petBear__body": "body", "petBear__eye": "eyeTexture",
              "petBear__mouth": "mouthTexture", "petBear__nose": "face", "petBear__wing": "wingTexture",
              "attach__ink": "face", "attach__metal": "own:#FFC240", "attach__bead": "own:#F2EDD9",
              "attach__cloth": "own:#1A8C9E", "attach__knit": "own:#5440BF"}
BOOL_KEYS = ("alternate", "placeholder", "coversHorns", "hidesEars")
COPY_KEYS = ("feature", "stage", "stageName", "variant", "height", "baseRadius", "majorRadius", "minorRadius",
             "shellOffset", "spanScale", "heightScale") + BOOL_KEYS

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
            "role": role, "colorRole": COLOR_ROLE.get(mat, mat), "material": mat,
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

SHIRT_PIECES = [{"piece": m["role"].replace("Shirt", "Torso"), "mesh": m["name"], "channel": m["channel"],
                 "anchor": m["anchor"]} for m in meshes if m["slot"] == "Shirt"]
assert [p["channel"] for p in SHIRT_PIECES] == ["Body", "HandL", "HandR"], SHIRT_PIECES

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
            {"slot": "Eyes", "items": "default EyeL/R | AltRound | AltSmallWide | AltButton; a swap hides Bear__EyeL/R"},
            {"slot": "Mouth", "items": "default MouthSmile | AltW | AltO; the expression system still picks the frame"},
            {"slot": "Tail", "items": "species Tail | AltArrow; a swap hides Bear__Tail"},
            {"slot": "Horns", "items": "stages S1..S5, one visible"},
            {"slot": "Back (wings)", "items": "stages S1..S5, one visible"},
        ],
        "notes": [
            "Horn stage 4 or 5 lifts CharmFloat by 0.10 so a floating charm clears the tips.",
            "Hat_Beanie is a full hat: coversHorns = true, hidesEars = false.",
            "A shirt is three meshes: Shirt_Torso on Body, Shirt_SleeveL on HandL and Shirt_SleeveR on HandR. The sleeves pivot on the shoulder anchors with the arms and are shown and hidden with the torso.",
        ],
    },
    "placeholderNote": "Hat_Beanie, Shirt_Torso (+Shirt_SleeveL/R), Neck_Beads, the helix rings, AltButton eyes, AltO mouth and AltArrow tail are grey-box placeholders with the correct size, origin and slot. Horns and wings are review-ready first-pass art.",
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
