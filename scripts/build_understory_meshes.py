"""The garden understory's meshes, P1 (GARDEN-B38-BRIEF 4b, Fable 2026-11-27): a round bush (leaf-cluster shells, one
mesh for both sizes), the same bush on the blossom part of the atlas (the flowering bush), and a clump of reeds with two
cattail heads. Original art: every shape is built here from code (icospheres pushed by seeded noise, triangle blades).
No AI mesh, no downloads, no samples.

Run in BACKGROUND Blender from an empty scene (draw the atlas first: python scripts/draw_understory_atlas.py):
  blender.exe -b --factory-startup --python scripts/build_understory_meshes.py -- [--render]

Mesh-local Roblox axes: origin on the ground at the plant's foot, y up. Blender (x, y, z) = Roblox (x, -z, y). FBX:
forward -Z, up Y (as the nest landmark), so Roblox imports each mesh turned by pi about Y (UnderstoryClient's Turn) with
its origin at its bounds centre; the manifest records each mesh's bounds centre from the foot and its size, so the
client seats it: CFrame.new(foot) * yaw * CFrame.new(centre * scale) * Turn, Size = size * scale.

Budget (Fable review round 2): a bush at most 320 triangles, reeds at most 38. Reed blades and stems are cards: each
face is doubled back to back with its own vertices (Roblox culls back faces; a merged pair would smooth its normal to
nothing). The bush's normals are custom split normals out from one point (one soft mass); they reach the FBX (checked
by re-importing it: every bush corner normal is the custom one, none flat). Its shade is a subtle vertex colour (.7 at
the foot to 1.0 at the top, a little darker where lobes tuck together), which a MeshPart's TextureID multiplies
(memory: roblox-surfaceappearance-runtime; the Aero falls kit ships vertex colour the same way).

Writes assets/world/understory/understory.fbx and understory-manifest.json (names unique to this slice: memory note
world-finish-template-names); with --render, renders the three meshes beside a player-height post (4.2) and a pet-size
ball (.9 x 1.1) to artifacts/qa-2026-11-27-beta37/understory/.
"""
from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "world" / "understory"
RENDERS = ROOT / "artifacts" / "qa-2026-11-27-beta37" / "understory"
ATLAS = OUT / "understory-atlas.png"
ATLAS_PX = 512.0
# Atlas regions, x0 y0 x1 y1 in pixels, image y down (scripts/draw_understory_atlas.py).
REGION = {"bush": (0, 0, 256, 256), "flower": (256, 0, 512, 256), "blades": (0, 256, 192, 512),
          "stem": (192, 256, 208, 512), "head": (208, 256, 256, 512)}
INSET = 4.0                                   # pixels kept off each region's edge (mip bleed)
NAMES = {"bush": "Understory_B38_Bush", "flower": "Understory_B38_BushFlower", "reeds": "Understory_B38_Reeds"}
TRIS_CAP = {"bush": 320, "flower": 320, "reeds": 38}
BUSH_ACROSS, BUSH_TALL = 3.0, 2.0             # design size; the client scales each bush to 2.5 / 4 across
GROUND = -.15                                 # Roblox-local y the bush's skirt sinks to (it sits, never perches)
NORMAL_FROM = (0, .4, 0)                      # Roblox-local: every bush normal points out from here (one soft mass)
SEED = 20261127


def bl(p):
    return Vector((p[0], -p[2], p[1]))


def rb(v):
    return (v[0], v[2], -v[1])


def region_uv(name, u, v):
    """u, v in 0..1 inside a region (v = 0 at the region's TOP row) to Blender UV (v up), inset off the edges."""
    x0, y0, x1, y1 = REGION[name]
    x0, y0, x1, y1 = x0 + INSET, y0 + INSET, x1 - INSET, y1 - INSET
    u = min(max(u, 0.0), 1.0)
    v = min(max(v, 0.0), 1.0)
    return ((x0 + (x1 - x0) * u) / ATLAS_PX, 1 - (y0 + (y1 - y0) * v) / ATLAS_PX)


# ----------------------------------------------------------------------------------------------------------- bush
# Fable review rounds 1 and 2: five lobes, every one an icosphere at subdivisions 2 (bmesh: 80 faces) pushed by seeded
# noise (.3); under each lobe's centre the shape stops tapering, keeps its radius (flare x 1.1) and drops into the lawn,
# and the faces left wholly under the lawn or buried in another lobe are deleted, so it sits, never perches. Two small
# round puffs on the upper outline soften the silhouette (Fable asked for two or three; two fit the 320 cap). Round 2:
# the softness is geometry, not cards (the leaf-spray cards read as thorns and are gone).
# Normals are custom split normals out from one point, so it shades as one soft mass; one continuous dome unwrap round
# the bush's axis (its top at the region's centre); a subtle vertex shade, .7 at the foot to 1.0 at the top, a little
# darker where one lobe tucks into another.
LOBES = (  # Roblox-local centre, radius, vertical squash, icosphere subdivisions, skirt to the ground
    ((0, 1.0, 0), 1.18, .82, 2, True),
    ((.92, .6, .32), .74, .86, 2, True), ((-.3, .58, .9), .72, .84, 2, True),
    ((-.94, .62, -.2), .76, .86, 2, True), ((.2, .56, -.92), .72, .84, 2, True),
    # the puffs: small, high, no skirt (they sit in the outline, not on the lawn)
    ((.62, 1.42, .34), .42, .9, 1, False), ((-.58, 1.38, -.3), .4, .9, 1, False),
)
SHADE = (.7, 1.0)          # vertex shade at the foot and the top
TUCK = .86                 # the shade where one lobe tucks deepest into another


def lump(bm, centre, radius, squash, subdiv, seed, skirt=True):
    made = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    off = Vector((seed * 3.7, seed * 1.3, seed * 2.1))
    c = bl(centre)
    amp = .3 if skirt else .18
    for vert in made["verts"]:
        d = vert.co.normalized()
        bump = noise.noise(d * 1.4 + off) * amp + noise.noise(d * 3.2 + off * 2) * .08
        r = radius * (1 + bump)
        if d.z >= 0 or not skirt:
            vert.co = Vector((d.x * r, d.y * r, d.z * r * squash)) + c
        else:
            # below the centre: no taper, the full radius flared x 1.1, straight down into the lawn
            h = math.hypot(d.x, d.y)
            if h < 1e-6:
                vert.co = Vector((c.x, c.y, GROUND))
            else:
                vert.co = Vector((c.x + d.x / h * r * 1.1, c.y + d.y / h * r * 1.1, GROUND))
    return made["verts"]


def dome_uv(region, p, centre, theta_max):
    """The dome unwrap: angle from the bush's axis above `centre` maps to the radius, azimuth to the angle round."""
    d = p - centre
    theta = math.atan2(math.hypot(d.x, d.y), d.z)
    phi = math.atan2(d.y, d.x)
    r = .5 * min(1.0, theta / theta_max)
    return region_uv(region, .5 + r * math.cos(phi), .5 - r * math.sin(phi))


def build_bush(name, region):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    owner = {}
    for k, (centre, radius, squash, subdiv, skirt) in enumerate(LOBES):
        for v in lump(bm, centre, radius, squash, subdiv, k + 1, skirt):
            owner[v] = k
    bmesh.ops.triangulate(bm, faces=bm.faces)
    under = [f for f in bm.faces if all(v.co.z <= GROUND + 1e-4 for v in f.verts)]
    bmesh.ops.delete(bm, geom=under, context="FACES")

    # faces buried inside another lobe are never seen: dropped (inside = under .62 of that lobe's radius, in its own
    # squashed frame, the most its noise can pull a surface in)
    def buried(co, k):
        for j, (centre, radius, squash, _, _) in enumerate(LOBES):
            if j == k:
                continue
            d = co - bl(centre)
            if math.sqrt(d.x * d.x + d.y * d.y + (d.z / squash) ** 2) < radius * .62:
                return True
        return False
    hidden = [f for f in bm.faces if all(buried(v.co, owner.get(v)) for v in f.verts)]
    bmesh.ops.delete(bm, geom=hidden, context="FACES")
    # where one lobe tucks into another: a little darker (a factor per vertex, applied with the height shade below)
    tuck = {}
    for v in bm.verts:
        k = owner.get(v)
        f = 1.0
        for j, (centre, radius, _, _, _) in enumerate(LOBES):
            if j == k:
                continue
            dist = (v.co - bl(centre)).length / radius
            if dist < 1.15:
                f = min(f, TUCK + (1 - TUCK) * max(0.0, (dist - .6) / .55))
        tuck[v] = f
    axis = bl(NORMAL_FROM)
    # scale to the design size: 3 across; 2 tall from the sunk skirt (GROUND stays GROUND)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    sx = BUSH_ACROSS / max(max(xs) - min(xs), max(ys) - min(ys))
    sz = BUSH_TALL / (max(zs) - GROUND)
    for v in bm.verts:
        v.co = Vector(((v.co.x - cx) * sx, (v.co.y - cy) * sx, (v.co.z - GROUND) * sz + GROUND))
    top = max(v.co.z for v in bm.verts)
    theta_max = max(math.atan2(math.hypot(v.co.x, v.co.y), v.co.z - axis.z) for v in bm.verts)
    for f in bm.faces:
        f.smooth = True
        for loop in f.loops:
            p = loop.vert.co
            loop[uv].uv = dome_uv(region, p, axis, theta_max)
            h = max(0.0, min(1.0, (p.z - GROUND) / (top - GROUND)))
            k = (SHADE[0] + (SHADE[1] - SHADE[0]) * h) * tuck.get(loop.vert, 1.0)
            loop[col] = (k, k, k, 1.0)
    return finish(bm, name, normals_from=axis)


# ---------------------------------------------------------------------------------------------------------- reeds
def card(bm, uv, col, pts, uvs, shades, smooth=False):
    """A triangle or quad as two back to back faces, each with its own vertices (flat, so each side lights as itself)."""
    n = len(pts)
    for order in (tuple(range(n)), (0,) + tuple(range(n - 1, 0, -1))):
        vs = [bm.verts.new(bl(pts[i])) for i in order]
        f = bm.faces.new(vs)
        f.smooth = smooth
        for loop, i in zip(f.loops, order):
            loop[uv].uv = uvs[i]
            k = shades[i]
            loop[col] = (k, k, k, 1.0)


def build_reeds(name):
    """Nine blades (2 triangles each), two stems as constant-width quads (4 each), two spindle heads (6 each): 38."""
    rnd = random.Random(SEED)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    blades = 9
    for k in range(blades):
        a = k / blades * math.tau + rnd.uniform(-.25, .25)
        r = .08 + rnd.random() * .3
        foot = (math.cos(a) * r, -.05, math.sin(a) * r)
        tall = 2.3 + rnd.random() * .9
        lean = math.radians(6 + rnd.random() * 14)            # outward from the clump's middle
        tip = (foot[0] + math.cos(a) * math.sin(lean) * tall, tall * math.cos(lean), foot[2] + math.sin(a) * math.sin(lean) * tall)
        side = a + math.pi / 2 + rnd.uniform(-.5, .5)          # the blade's flat face turns round the clump
        w = .07 + rnd.random() * .04
        left = (foot[0] - math.cos(side) * w, foot[1], foot[2] - math.sin(side) * w)
        right = (foot[0] + math.cos(side) * w, foot[1], foot[2] + math.sin(side) * w)
        strip = k % 8                                           # eight 24 px strips across the blade region
        u0, u1 = strip / 8 + .01, (strip + 1) / 8 - .01
        card(bm, uv, col, [left, right, tip],
             [region_uv("blades", u0, 1), region_uv("blades", u1, 1), region_uv("blades", (u0 + u1) / 2, 0)],
             [.7, .7, 1.0])
    for k in range(2):
        a = k * math.pi + .6
        foot = Vector((math.cos(a) * .12, -.05, math.sin(a) * .12))
        tall = 2.75 + k * .35
        lean = math.radians(5 + k * 4)
        axis = Vector((math.cos(a) * math.sin(lean), math.cos(lean), math.sin(a) * math.sin(lean)))
        top = foot + axis * tall
        head_low = top - axis * .62                             # the spindle: .55 long, .07 of bare stem tip above it
        head_top = top - axis * .07
        stem_top = head_low + axis * .1                         # the stem runs into the head
        side = Vector((math.cos(a + math.pi / 2), 0, math.sin(a + math.pi / 2)))
        w = .03
        card(bm, uv, col,
             [tuple(foot - side * w), tuple(foot + side * w), tuple(stem_top + side * w), tuple(stem_top - side * w)],
             [region_uv("stem", 0, 1), region_uv("stem", 1, 1), region_uv("stem", 1, 0), region_uv("stem", 0, 0)],
             [.7, .7, .95, .95])
        # the head: a three-sided spindle pointed at both ends, radius .055 at its middle (6 triangles)
        ref = Vector((0, 1, 0)) if abs(axis.y) < .9 else Vector((1, 0, 0))
        e1 = axis.cross(ref).normalized()
        e2 = axis.cross(e1).normalized()
        mid = (head_low + head_top) / 2
        ring = [mid + (math.cos(s / 3 * math.tau) * e1 + math.sin(s / 3 * math.tau) * e2) * .055 for s in range(3)]
        for s in range(3):
            q0, q1 = ring[s], ring[(s + 1) % 3]
            for tip_pt, along in ((head_top, 1.0), (head_low, 0.0)):
                tri = [(q0, s / 3, .5), (q1, (s + 1) / 3, .5), (tip_pt, (s + .5) / 3, along)]
                p0, p1, p2 = (bl(tuple(q[0])) for q in tri)
                outward = bl(tuple((q0 + q1) / 2 - mid))
                if (p1 - p0).cross(p2 - p0).dot(outward) < 0:
                    tri.reverse()
                f = bm.faces.new([bm.verts.new(bl(tuple(q[0]))) for q in tri])
                f.smooth = True
                for loop, (_, around, al) in zip(f.loops, tri):
                    loop[uv].uv = region_uv("head", around, 1 - al)
                    kk = .75 + .25 * al
                    loop[col] = (kk, kk, kk, 1.0)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return finish(bm, name)


# --------------------------------------------------------------------------------------------------------- common
def finish(bm, name, normals_from=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if normals_from is not None:
        # custom split normals, every one out from a single point: the bush shades as one soft mass
        me.normals_split_custom_set_from_vertices([tuple((v.co - normals_from).normalized()) for v in me.vertices])
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds(obj):
    pts = [rb(v.co) for v in obj.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return [round((lo[i] + hi[i]) / 2, 4) for i in range(3)], [round(hi[i] - lo[i], 4) for i in range(3)]


def digest(obj):
    h = hashlib.sha256()
    for v in obj.data.vertices:
        h.update(("%.4f,%.4f,%.4f;" % tuple(v.co)).encode())
    for loop in obj.data.uv_layers[0].data:
        h.update(("%.4f,%.4f;" % tuple(loop.uv)).encode())
    return h.hexdigest()[:16]


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    OUT.mkdir(parents=True, exist_ok=True)
    objs = {"bush": build_bush(NAMES["bush"], "bush"), "flower": build_bush(NAMES["flower"], "flower"),
            "reeds": build_reeds(NAMES["reeds"])}
    meshes = {}
    for key, obj in objs.items():
        n = tris(obj)
        assert n <= TRIS_CAP[key], (key, n, TRIS_CAP[key])
        centre, size = bounds(obj)
        meshes[key] = {"name": obj.name, "tris": n, "centre": centre, "size": size, "hash": digest(obj)}
    assert meshes["bush"]["hash"] != meshes["flower"]["hash"], "the flowering bush must sit on its own atlas region"
    manifest = {
        "note": "Generated by scripts/build_understory_meshes.py. Mesh-local Roblox studs: origin on the ground at the "
                "plant's foot, y up. Roblox imports each mesh turned by pi about Y, its origin at its bounds centre "
                "(`centre`, from the foot). Size = `size` x the instance scale.",
        "atlas": "assets/world/understory/understory-atlas.png",
        "blob": "assets/world/understory/understory-blob.png",
        "meshes": meshes,
        "triangles": {k: v["tris"] for k, v in meshes.items()},
    }
    # Origins at the bounds centres (Roblox puts the part there anyway; this keeps Blender and Studio the same).
    for key, obj in objs.items():
        c = bl(meshes[key]["centre"])
        obj.data.transform(Matrix.Translation(-c))
        obj.location = c
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs.values():
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(OUT / "understory.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE",
                             colors_type="SRGB")
    (OUT / "understory-manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8", newline="\n")
    print("UNDERSTORY", {k: (v["tris"], v["size"], v["centre"]) for k, v in meshes.items()})
    if "--render" in sys.argv:
        render(objs, meshes)


# --------------------------------------------------------------------------------------------------------- render
def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)


def material(name, image=None, colour=None, rough=.95, vcol=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    if image:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.interpolation = "Linear"
        out = tex.outputs["Color"]
        if vcol:   # the vertex shade multiplies the texture, as a MeshPart's TextureID does
            attr = nt.nodes.new("ShaderNodeAttribute")
            attr.attribute_name = "Col"
            mul = nt.nodes.new("ShaderNodeVectorMath")
            mul.operation = "MULTIPLY"
            nt.links.new(out, mul.inputs[0])
            nt.links.new(attr.outputs["Color"], mul.inputs[1])
            out = mul.outputs[0]
        nt.links.new(out, bsdf.inputs["Base Color"])
    elif colour:
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = rough
    # as Roblox draws a mesh: back faces culled (the doubled cards' far halves would z-fight their near halves)
    mat.use_backface_culling = True
    for key in ("Specular IOR Level", "Specular"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = .15
            break
    return mat


def place(src, name, foot, scale, yaw):
    obj = bpy.data.objects.new(name, src.data)
    bpy.context.scene.collection.objects.link(obj)
    centre = Vector(src.location)                       # Blender coords of the bounds centre from the foot
    obj.scale = (scale[0], scale[0], scale[1])
    obj.rotation_euler = (0, 0, yaw)
    off =Matrix.Rotation(yaw, 4, "Z") @ Vector((centre.x * scale[0], centre.y * scale[0], centre.z * scale[1]))
    obj.location = bl(foot) + off
    return obj


def render(objs, meshes):
    RENDERS.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.load(str(ATLAS))
    tex = material("Understory", image, vcol=True)
    for obj in objs.values():
        obj.data.materials.append(tex)
        obj.hide_render = True
    scene = bpy.context.scene
    # a lineup at the brief's sizes: big bush 4 x 2.4, small bush 2.5 x 1.6, flowering 3 x 2, two reed clumps, then a
    # cluster of three as the garden places them, a player post and a pet ball for scale
    b = meshes["bush"]["size"]
    lineup = [
        (objs["bush"], "big", (-7.5, 0, 0), (4 / b[0], 2.4 / b[1]), .3),
        (objs["bush"], "small", (-3.8, 0, .6), (2.5 / b[0], 1.6 / b[1]), 1.4),
        (objs["flower"], "flowering", (-.4, 0, 0), (3 / b[0], 2 / b[1]), 2.2),
        (objs["reeds"], "reedsA", (3.0, 0, .2), (1, 1), .4),
        (objs["reeds"], "reedsB", (4.3, 0, -.5), (.85, .9), 2.6),
        (objs["bush"], "c1", (-4, 0, 9), (4 / b[0], 2.3 / b[1]), 4.0),
        (objs["bush"], "c2", (-1.2, 0, 10.6), (2.6 / b[0], 1.7 / b[1]), .9),
        (objs["bush"], "c3", (-6.4, 0, 11.4), (2.5 / b[0], 1.5 / b[1]), 5.1),
        (objs["flower"], "f2", (3.5, 0, 9.5), (2.6 / b[0], 1.8 / b[1]), 3.3),
    ]
    for src, name, foot, scale, yaw in lineup:
        place(src, name, foot, scale, yaw)
    bpy.ops.mesh.primitive_plane_add(size=240, location=(0, 0, 0))
    ground = bpy.context.object
    ground.data.materials.append(material("Lawn", colour=lin("#56A54B"), rough=1))
    bpy.ops.mesh.primitive_cylinder_add(radius=.6, depth=4.2, location=bl((8, 2.1, 0)))
    bpy.context.object.data.materials.append(material("Player", colour=lin("#B8B8C8"), rough=.8))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=.5, location=bl((6.6, .55, 1.2)))
    pet = bpy.context.object
    pet.scale = (.9, .9, 1.1)
    pet.data.materials.append(material("Pet", colour=lin("#F4E8CF"), rough=.6))
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scene.collection.objects.link(so)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (.55, .75, 1.0, 1)
    bg.inputs[1].default_value = 1.0   # the Aero day ambient is bright: nearer the game than a dim sky
    scene.world = world
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    scene.render.resolution_x, scene.render.resolution_y = 1400, 800
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 42
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = (("lineup", (-1, 4.2, -13), (-1, 1.3, 3)), ("player-eye", (-2, 5.2, -6), (-1, 1.0, 9)),
             ("close", (-3.5, 2.6, -5.2), (-3.5, 1.0, 1)), ("reeds", (4.5, 2.2, -4.5), (3.6, 1.6, 0)),
             # Fable: a player's eye (.8 scale, eyes about 3.6 up) 6 studs from the cluster, the lawn behind it
             ("lawn-behind", (-4, 3.6, 3.6), (-4, .9, 9.6)))
    for label, eye, target in views:
        e, t = bl(eye), bl(target)
        cam.location = e
        cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(RENDERS / f"understory-{label}.png")
        bpy.ops.render.render(write_still=True)
    print("UNDERSTORY renders in", RENDERS)


main()
