"""Build the 3D egg set and the Star token, export the FBX files and write the manifest.

Run (background Blender only; it starts from an empty scene and writes its own .blend):
  blender -b --factory-startup --python scripts/build_egg_models.py

Outputs
  assets/art-source/eggs/eggs.blend     source scene (Egg__TopShell, Egg__BottomShell, Egg__Core, StarToken)
  assets/eggs/eggs.fbx                  the three egg meshes
  assets/eggs/star.fbx                  the Star token
  assets/eggs/eggs-manifest.json        names, sizes, pivots, textures, glow and particle colours

Convention is the one the Bear uses (scripts/export_bear_attachments.py): FBX axis_forward=-Z, axis_up=Y,
1 Blender unit = 1 stud, transforms applied. Blender: up +Z, front -Y. The egg stands on the origin.
Textures come from scripts/build_egg_textures.py; shared numbers live in scripts/egg_types.py.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import egg_types as E  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
SRC = REPO / "assets" / "art-source" / "eggs"
OUT = REPO / "assets" / "eggs"
SRC.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
N = E.SEGMENTS


# ---------- egg shells ----------
def outer_point(j, t):
    r, z = E.profile(t)
    dx, dy = E.direction(j / N)
    nr, nz = E.profile_normal(t)
    return Vector((r * dx, r * dy, z)), Vector((nr * dx, nr * dy, nz))


def seam_t(j):
    return E.SEAM_T + (E.SEAM_AMP_T if j % 2 == 0 else -E.SEAM_AMP_T)


def build_shell(name, rows, inner_rows, pole_t):
    """One half of the egg: outer skin, cut rim, inner skin. Normals are analytic so the two halves
    shade as one surface when closed."""
    verts, normals, faces, uvs = [], [], [], []

    def add(p, n):
        verts.append(p)
        normals.append(n)
        return len(verts) - 1

    def v_outer(t):
        return E.UV_OUTER_V0 + t * (1 - E.UV_OUTER_V0)

    def v_inner(t):
        f = abs(t - pole_t) / abs(E.SEAM_T - pole_t)
        return E.UV_INNER_V[0] + min(f, 1.0) * (E.UV_INNER_V[1] - E.UV_INNER_V[0])

    def face(idx, uv, flip):
        if flip:
            idx, uv = idx[::-1], uv[::-1]
        faces.append(idx)
        uvs.append(uv)

    top = pole_t > 0.5
    # --- outer skin: seam ring, plain rings, pole ---
    ring_ts = [[seam_t(j) for j in range(N)]] + [[t] * N for t in rows]
    rings = [[add(*outer_point(j, ts[j])) for j in range(N)] for ts in ring_ts]
    pole = add(Vector((0, 0, E.profile(pole_t)[1])), Vector((0, 0, 1 if top else -1)))
    for a in range(len(rings) - 1):
        for j in range(N):
            k = (j + 1) % N
            ta0, ta1 = ring_ts[a][j], ring_ts[a][k]
            tb0, tb1 = ring_ts[a + 1][j], ring_ts[a + 1][k]
            u0, u1 = j / N, (j + 1) / N
            q = [rings[a][j], rings[a][k], rings[a + 1][k], rings[a + 1][j]]
            quv = [(u0, v_outer(ta0)), (u1, v_outer(ta1)), (u1, v_outer(tb1)), (u0, v_outer(tb0))]
            # split along the shorter diagonal so the zig-zag band stays convex
            if (verts[q[0]] - verts[q[2]]).length <= (verts[q[1]] - verts[q[3]]).length:
                tris = [(0, 1, 2), (0, 2, 3)]
            else:
                tris = [(0, 1, 3), (1, 2, 3)]
            for tri in tris:
                face([q[i] for i in tri], [quv[i] for i in tri], not top)
    last, last_t = rings[-1], ring_ts[-1][0]
    for j in range(N):
        k = (j + 1) % N
        face([last[j], last[k], pole],
             [(j / N, v_outer(last_t)), ((j + 1) / N, v_outer(last_t)), ((j + 0.5) / N, v_outer(pole_t))], not top)

    # --- rim: its own verts so the edge is crisp ---
    rim_n = Vector((0, 0, -1 if top else 1))
    rim_o, rim_i, in_seam = [], [], []
    for j in range(N):
        p, n = outer_point(j, seam_t(j))
        pi = p - n * E.SHELL_THICKNESS
        rim_o.append(add(p, rim_n))
        rim_i.append(add(pi, rim_n))
        in_seam.append(add(pi, -n))
    for j in range(N):
        k = (j + 1) % N
        u0, u1 = j / N, (j + 1) / N
        rv = E.UV_RIM_V
        face([rim_o[j], rim_i[j], rim_i[k]], [(u0, rv), (u0, rv), (u1, rv)], not top)
        face([rim_o[j], rim_i[k], rim_o[k]], [(u0, rv), (u1, rv), (u1, rv)], not top)

    # --- inner skin (faces point inward) ---
    in_rings, in_ts = [in_seam], [[seam_t(j) for j in range(N)]]
    for t in inner_rows:
        ring = []
        for j in range(N):
            p, n = outer_point(j, t)
            ring.append(add(p - n * E.SHELL_THICKNESS, -n))
        in_rings.append(ring)
        in_ts.append([t] * N)
    pz = E.profile(pole_t)[1] + (-E.SHELL_THICKNESS if top else E.SHELL_THICKNESS)
    in_pole = add(Vector((0, 0, pz)), Vector((0, 0, -1 if top else 1)))
    for a in range(len(in_rings) - 1):
        for j in range(N):
            k = (j + 1) % N
            u0, u1 = j / N, (j + 1) / N
            q = [in_rings[a][j], in_rings[a][k], in_rings[a + 1][k], in_rings[a + 1][j]]
            quv = [(u0, v_inner(in_ts[a][j])), (u1, v_inner(in_ts[a][k])),
                   (u1, v_inner(in_ts[a + 1][k])), (u0, v_inner(in_ts[a + 1][j]))]
            if (verts[q[0]] - verts[q[2]]).length <= (verts[q[1]] - verts[q[3]]).length:
                tris = [(0, 1, 2), (0, 2, 3)]
            else:
                tris = [(0, 1, 3), (1, 2, 3)]
            for tri in tris:
                face([q[i] for i in tri], [quv[i] for i in tri], top)
    last, lt = in_rings[-1], in_ts[-1][0]
    for j in range(N):
        k = (j + 1) % N
        face([last[j], last[k], in_pole],
             [(j / N, v_inner(lt)), ((j + 1) / N, v_inner(lt)), ((j + 0.5) / N, v_inner(pole_t))], top)

    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    uv = me.uv_layers.new(name="UVMap")
    li = 0
    for f_uv in uvs:
        for c in f_uv:
            uv.data[li].uv = c
            li += 1
    for p in me.polygons:
        p.use_smooth = True
    me.normals_split_custom_set_from_vertices([tuple(n.normalized()) for n in normals])
    me.update()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


def check_winding(ob):
    """Every face normal must agree with its vertex normals (catches a flipped triangle)."""
    me = ob.data
    bad = 0
    for p in me.polygons:
        n = Vector((0, 0, 0))
        for li in p.loop_indices:
            n += me.corner_normals[li].vector
        if n.dot(p.normal) <= 0:
            bad += 1
    assert bad == 0, (ob.name, bad, "faces wound the wrong way")


top = build_shell("Egg__TopShell", E.TOP_ROWS, E.TOP_INNER_ROWS, 1.0)
bottom = build_shell("Egg__BottomShell", E.BOTTOM_ROWS, E.BOTTOM_INNER_ROWS, 0.0)

# ---------- glow core ----------
bm = bmesh.new()
bmesh.ops.create_icosphere(bm, subdivisions=3, radius=E.CORE_RADIUS, calc_uvs=True)
core_me = bpy.data.meshes.new("Egg__Core")
bm.to_mesh(core_me)
bm.free()
for p in core_me.polygons:
    p.use_smooth = True
core_me.transform(__import__("mathutils").Matrix.Translation((0, 0, E.CORE_CENTER_Z)))
core = bpy.data.objects.new("Egg__Core", core_me)
scene.collection.objects.link(core)
# the core must sit inside the inner skin everywhere
for i in range(1, 200):
    t = i / 200
    r, z = E.profile(t)
    nr, nz = E.profile_normal(t)
    ri, zi = r - nr * E.SHELL_THICKNESS, z - nz * E.SHELL_THICKNESS
    gap = math.hypot(ri, zi - E.CORE_CENTER_Z) - E.CORE_RADIUS
    assert gap > 0.02, ("core touches the shell", t, gap)


# ---------- Star token ----------
def fillet_polygon(points, radii, segs):
    out = []
    n = len(points)
    for i in range(n):
        p, a, b = Vector(points[i]), Vector(points[i - 1]), Vector(points[(i + 1) % n])
        da, db = (a - p).normalized(), (b - p).normalized()
        half = da.angle(db) / 2
        d = radii[i] / math.tan(half)
        c = p + (da + db).normalized() * (radii[i] / math.sin(half))
        s, e = p + da * d, p + db * d
        a0 = math.atan2(s.y - c.y, s.x - c.x)
        a1 = math.atan2(e.y - c.y, e.x - c.x)
        da_ = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
        for k in range(segs[i] + 1):
            ang = a0 + da_ * k / segs[i]
            out.append(Vector((c.x + radii[i] * math.cos(ang), c.y + radii[i] * math.sin(ang))))
    return out


def build_star():
    S = E.STAR
    pts, radii, segs = [], [], []
    for i in range(10):                      # clockwise from the top tip, in the XZ plane
        ang = math.radians(90 - i * 36)
        rr = S["outerRadius"] if i % 2 == 0 else S["innerRadius"]
        pts.append((rr * math.cos(ang), rr * math.sin(ang)))
        radii.append(S["tipFillet"] if i % 2 == 0 else S["valleyFillet"])
        segs.append(4 if i % 2 == 0 else 2)
    outline = fillet_polygon(pts, radii, segs)
    m = len(outline)
    verts, faces = [], []
    # ring order front to back: front rings (inner to outer), back rings (outer to inner)
    rings_spec = [(s, -d) for s, d in reversed(S["rings"])] + [(s, d) for s, d in S["rings"]]
    front_apex = len(verts)
    verts.append((0, -S["apexDepth"], 0))
    ring_idx = []
    for s, y in rings_spec:
        ring_idx.append(list(range(len(verts), len(verts) + m)))
        verts += [(p.x * s, y, p.y * s) for p in outline]
    back_apex = len(verts)
    verts.append((0, S["apexDepth"], 0))
    for j in range(m):
        k = (j + 1) % m
        faces.append((front_apex, ring_idx[0][j], ring_idx[0][k]))
        faces.append((back_apex, ring_idx[-1][k], ring_idx[-1][j]))
        for a in range(len(ring_idx) - 1):
            q = (ring_idx[a][j], ring_idx[a + 1][j], ring_idx[a + 1][k], ring_idx[a][k])
            faces.append((q[0], q[1], q[2]))
            faces.append((q[0], q[2], q[3]))
    me = bpy.data.meshes.new("StarToken")
    me.from_pydata(verts, [], faces)
    bmx = bmesh.new()
    bmx.from_mesh(me)
    bmesh.ops.recalc_face_normals(bmx, faces=bmx.faces)
    bmx.to_mesh(me)
    bmx.free()
    uv = me.uv_layers.new(name="UVMap")
    span = S["uvSpan"]
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        # planar from the front; the back mirrors in x so the art reads the same on both faces
        x = co.x if co.y <= 0 else -co.x
        uv.data[loop.index].uv = (0.5 + x / span, 0.5 + co.z / span)
    for p in me.polygons:
        p.use_smooth = True
    me.update()
    ob = bpy.data.objects.new("StarToken", me)
    scene.collection.objects.link(ob)
    return ob


star = build_star()


# ---------- preview materials (Roblox uses SurfaceAppearance; these are for the .blend and renders) ----------
def image_material(name, image_path, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.name = "ColorMap"
    if Path(image_path).exists():
        tex.image = bpy.data.images.load(str(image_path))
        tex.image.filepath = "//" + str(Path("..") / ".." / "eggs" / "textures" / Path(image_path).name).replace("\\", "/")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    for key, val in (("Coat Weight", 0.35), ("Coat Roughness", 0.08)):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = val
    return mat


shell_mat = image_material("egg__shell", OUT / "textures" / "egg-toy-color.png", 0.27)
star_mat = image_material("star__gold", OUT / "textures" / "star-color.png", E.STAR["roughness"])
core_mat = bpy.data.materials.new("egg__core")
core_mat.use_nodes = True
cb = next(n for n in core_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
cb.inputs["Base Color"].default_value = (1, 0.7, 0.25, 1)
cb.inputs["Emission Color"].default_value = (1, 0.7, 0.25, 1)
cb.inputs["Emission Strength"].default_value = 6.0
top.data.materials.append(shell_mat)
bottom.data.materials.append(shell_mat)
core.data.materials.append(core_mat)
star.data.materials.append(star_mat)
star.location = (2.0, 0, 0.75)      # parked beside the egg in the .blend; exported at the origin

for ob in (top, bottom):
    check_winding(ob)


# ---------- export ----------
def tri_count(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def bounds(ob):
    cos = [v.co for v in ob.data.vertices]
    lo = Vector([min(c[i] for c in cos) for i in range(3)])
    hi = Vector([max(c[i] for c in cos) for i in range(3)])
    return lo, hi


def r(v, n=4):
    return [round(float(x), n) + 0.0 for x in v]


def rt(v):
    """Blender (x, y, z) -> Roblox runtime (x, z, -y): up +Y, front +Z. Same mapping as the Bear."""
    return Vector((v.x, v.z, -v.y))


def rt_size(v):
    return Vector((v.x, v.z, v.y))


def export(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False,
                             object_types={"MESH"}, add_leaf_bones=False, bake_anim=False, path_mode="AUTO",
                             mesh_smooth_type="OFF")


bpy.context.view_layer.update()
export(OUT / "eggs.fbx", [top, bottom, core])
saved_loc = star.location.copy()
star.location = (0, 0, 0)
bpy.context.view_layer.update()
export(OUT / "star.fbx", [star])
star.location = saved_loc

seam_z = E.profile(E.SEAM_T)[1]
amp_z = E.profile(E.SEAM_T + E.SEAM_AMP_T)[1] - seam_z


def mesh_entry(ob, fbx, role, extra=None):
    lo, hi = bounds(ob)
    c, s = (lo + hi) / 2, hi - lo
    e = {"name": ob.name, "fbx": fbx, "role": role, "triangles": tri_count(ob), "hasUV": bool(ob.data.uv_layers),
         "sizeStuds": r(rt_size(s)), "centerFromEggBase": r(rt(c)),
         "sizeBlender": r(s), "centerBlender": r(c)}
    e.update(extra or {})
    return e


meshes = [
    mesh_entry(top, "eggs.fbx", "top shell: pops up on Hatch",
               {"material": "SurfaceAppearance (ColorMap = the type's texture, RoughnessMap = egg-roughness.png)",
                "liftAxis": "+Y", "doubleSided": False,
                "note": "Has an inner skin and a cut rim, so it is solid from below when it lifts."}),
    mesh_entry(bottom, "eggs.fbx", "bottom shell: the cup that stays",
               {"material": "SurfaceAppearance (same maps as the top shell)", "doubleSided": False}),
    mesh_entry(core, "eggs.fbx", "inner glow core",
               {"material": "Neon, no texture; Color = types[id].core", "castShadow": False,
                "note": "Sits behind the seam. Lifting the top shell 0.04 studs shows it through the crack."}),
]
star_lo, star_hi = bounds(star)
manifest = {
    "schema": 1, "asset": "eggs",
    "builtBy": ["scripts/build_egg_models.py", "scripts/build_egg_textures.py", "scripts/egg_types.py"],
    "sourceBlend": "assets/art-source/eggs/eggs.blend",
    "axes": "FBX axis_forward=-Z axis_up=Y, same as bear.fbx. Blender: up +Z, front -Y, 1 unit = 1 stud. "
            "The egg stands on the origin (base centre at 0,0,0), its long axis is +Y in Roblox.",
    "conversions": {
        "blenderToRuntime": "(x, y, z) -> (x, z, -y)  [runtime: front +Z, up +Y]",
        "scaleNote": "As for the Bear: Studio's default FBX units import these at 100x. Set Size = MeshSize/100 "
                     "(or use sizeStuds below). centerFromEggBase is where each MeshPart's centre goes, "
                     "relative to the egg's base centre, at 1x.",
    },
    "files": {"eggs": "eggs.fbx", "star": "star.fbx", "fx": "EGG-PREVIEW-FX.md", "textures": "textures/"},
    "egg": {
        "sizeStuds": [E.WIDTH, E.HEIGHT, E.WIDTH],
        "pivotFromEggBase": [0, 0, 0],
        "spinPivotFromEggBase": [0, round(E.HEIGHT * 0.42, 4), 0],
        "seam": {"heightFromBase": round(seam_z, 4), "zigZagHalfHeight": round(amp_z, 4), "teeth": E.TEETH,
                 "radiusAtSeam": round(E.profile(E.SEAM_T)[0], 4)},
        "shellThickness": E.SHELL_THICKNESS,
        "triangles": sum(m["triangles"] for m in meshes),
        "meshes": meshes,
        "uv": {"outer": "u round the egg (u = 0.5 is the front), v 0.08..1 from bottom pole to top pole",
               "inner": "v 0.02..0.05 (inside of the shell)", "rim": "v 0.062 (cut edge)",
               "note": "Both shells and every type share this layout, so a type swap is one ColorMap swap."},
        "roughnessMap": "textures/egg-roughness.png",
        "roughnessPlan": "Glossy toy plastic: roughness 0.27 outside, 0.78 inside the shell. No MetalnessMap, "
                         "no NormalMap. If SurfaceAppearance is too costly in the ViewportFrame, use the ColorMap "
                         "as MeshPart.TextureID with Material SmoothPlastic and Reflectance 0.08.",
    },
    "order": E.ORDER,
    "types": {
        tid: {
            "name": t["name"], "look": t["look"],
            "colorMap": f"textures/egg-{tid}-color.png", "textureSize": 1024,
            "roughnessMap": "textures/egg-roughness.png", "roughness": t["roughness"],
            "base": t["base"], "deep": t["deep"], "light": t["light"], "accents": t["accents"],
            "core": t["core"], "bloom": t["bloom"], "crackLight": t["light"],
            "particles": t["particles"],
        } for tid, t in E.TYPES.items()
    },
    "star": {
        **mesh_entry(star, "star.fbx", "results-screen Star token",
                     {"material": "SurfaceAppearance (ColorMap star-color.png, RoughnessMap star-roughness.png)"}),
        "colorMap": "textures/star-color.png", "textureSize": 512,
        "roughnessMap": "textures/star-roughness.png", "roughness": E.STAR["roughness"],
        "pivot": "mesh centre; the star faces the camera along -Z in the FBX (front +Z at runtime)",
        "uv": "planar from the front, mirrored on the back, so both faces show the same facets",
        "colors": {k: E.STAR[k] for k in ("light", "gold", "mid", "deep", "edge")},
        "missedRound": "same mesh, Transparency 0.6, Color #DDE7EE, no ColorMap tint change needed (spec 2.4)",
        "particles": ["#FFFFFF", "#FFE9A0", "#FFD069"],
    },
}
(OUT / "eggs-manifest.json").write_text(json.dumps(manifest, indent=1), newline="\n")

bpy.ops.wm.save_as_mainfile(filepath=str(SRC / "eggs.blend"))
for m in meshes:
    print("MESH", m["name"], m["triangles"], "tris, size", m["sizeStuds"], "centre", m["centerFromEggBase"])
print("MESH StarToken", tri_count(star), "tris, size", manifest["star"]["sizeStuds"])
print("EGG TOTAL", manifest["egg"]["triangles"])
